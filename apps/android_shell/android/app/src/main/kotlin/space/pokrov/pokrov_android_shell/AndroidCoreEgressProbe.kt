package space.pokrov.pokrov_android_shell

import org.json.JSONObject
import space.pokrov.core.libbox.CommandClientHandler
import space.pokrov.core.libbox.CommandClientOptions
import space.pokrov.core.libbox.ConnectionEvents
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.LogIterator
import space.pokrov.core.libbox.OutboundGroupIterator
import space.pokrov.core.libbox.RuntimeProbeCancellation
import space.pokrov.core.libbox.StatusMessage
import space.pokrov.core.libbox.StringIterator
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.lang.reflect.InvocationTargetException

internal enum class AndroidCoreEgressProbeResult {
    HEALTHY,
    FAILED,
    CONNECT_FAILED,
    TLS_FAILED,
    UNAVAILABLE,
    TIMED_OUT;

    val isCompletedFailure: Boolean
        get() = this == FAILED || this == CONNECT_FAILED || this == TLS_FAILED

    fun failureKind(periodic: Boolean = false): String = when (this) {
        FAILED -> "core_egress_probe_failed"
        CONNECT_FAILED -> "core_egress_connect_failed"
        TLS_FAILED -> "core_egress_tls_failed"
        TIMED_OUT -> if (periodic) "core_egress_timeout" else "core_egress_probe_unavailable"
        else -> "core_egress_probe_unavailable"
    }
}

/** One current probe; only its healthy result can schedule the next check. */
internal class AndroidCoreEgressMonitor(
    private val isCurrent: () -> Boolean,
    private val canRepeat: () -> Boolean,
    private val schedule: (Runnable, Long) -> Unit,
    private val remove: (Runnable) -> Unit,
    private val startProbe: (Long, Boolean) -> Unit,
    private val publish: (AndroidCoreEgressProbeResult, Boolean) -> Unit,
) {
    private var cancelled = false
    private var sequence = 0L
    private var inFlight: Long? = null
    private var periodic = false
    private val next = Runnable { start() }

    @Synchronized fun start() {
        if (cancelled || inFlight != null || !isCurrent() || (periodic && !canRepeat())) return
        val token = ++sequence
        inFlight = token
        startProbe(token, periodic)
    }

    @Synchronized fun owns(token: Long): Boolean =
        !cancelled && inFlight == token && isCurrent()

    @Synchronized fun complete(token: Long, result: AndroidCoreEgressProbeResult) {
        if (!owns(token)) return
        inFlight = null
        publish(result, periodic)
        if (result == AndroidCoreEgressProbeResult.HEALTHY && !cancelled && isCurrent() && canRepeat()) {
            periodic = true
            schedule(next, INTERVAL_MILLIS)
        }
    }

    @Synchronized fun cancel() {
        cancelled = true
        inFlight = null
        remove(next)
    }

    companion object { const val INTERVAL_MILLIS = 2_000L }
}

internal object AndroidCoreEgressRetryPolicy {
    fun shouldRetry(
        target: AndroidCoreEgressProbeTarget,
        result: AndroidCoreEgressProbeResult,
        completedAttempts: Int,
    ): Boolean =
        completedAttempts < maxAttempts(target) &&
            (
                result == AndroidCoreEgressProbeResult.UNAVAILABLE ||
                    (
                        target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT &&
                            result.isCompletedFailure
                        )
                )

    private fun maxAttempts(target: AndroidCoreEgressProbeTarget): Int =
        if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) 3 else 2
}

internal enum class AndroidCoreEgressProbeTargetKind {
    GROUP,
    ENDPOINT,
}

internal data class AndroidCoreEgressProbeTarget(
    val tag: String,
    val kind: AndroidCoreEgressProbeTargetKind,
    val keepRuntimeOnFailure: Boolean = false,
    val captureSafeFailureCategory: Boolean = false,
)

internal data class AndroidCoreEgressProbeSample(
    val time: Long,
    val delay: Int,
)

internal data class AndroidCoreEgressProbeGroupSnapshot(
    val selected: String,
    val items: Map<String, AndroidCoreEgressProbeSample?>,
)

internal data class AndroidCoreEgressProbeSelection(
    val groupTag: String,
    val outboundTag: String,
    val sample: AndroidCoreEgressProbeSample?,
)

/** Runs the core's own URL test for the profile's protected outbound. */
internal object AndroidCoreEgressProbe {
    fun finalTarget(configContent: String): AndroidCoreEgressProbeTarget? {
        return runCatching {
            val config = JSONObject(configContent)
            val tag = protectedTargetTag(config) ?: return@runCatching null
            val outbounds = config.optJSONArray("outbounds") ?: return@runCatching null
            val outboundTypes = mutableMapOf<String, String>()
            for (index in 0 until outbounds.length()) {
                val outbound = outbounds.optJSONObject(index) ?: continue
                val outboundTag = outbound.optString("tag").trim()
                if (outboundTag.isNotEmpty()) {
                    outboundTypes[outboundTag] = outbound.optString("type")
                }
            }
            val endpointTypes = mutableMapOf<String, String>()
            val endpoints = config.optJSONArray("endpoints")
            for (index in 0 until (endpoints?.length() ?: 0)) {
                val endpoint = endpoints?.optJSONObject(index) ?: continue
                val endpointTag = endpoint.optString("tag").trim()
                if (endpointTag.isNotEmpty()) {
                    endpointTypes[endpointTag] = endpoint.optString("type")
                }
            }
            resolveFinalTarget(
                finalTag = tag,
                outboundTypes = outboundTypes,
                endpointTypes = endpointTypes,
            )
        }.getOrNull()
    }

    internal fun protectedTargetTag(config: JSONObject): String? {
        val route = config.optJSONObject("route") ?: return null
        val finalTag = route.optString("final").trim()
        if (!isSafeTag(finalTag)) return null
        val outbounds = config.optJSONArray("outbounds") ?: return null
        val finalIsDirect = (0 until outbounds.length()).any { index ->
            val outbound = outbounds.optJSONObject(index) ?: return@any false
            outbound.optString("tag") == finalTag && outbound.optString("type") == "direct"
        }
        if (!finalIsDirect) return finalTag

        // Selective has a Direct default. Bind both startup and Core proof to
        // the exact owned HTTPS rule emitted by the catalog assembler, never
        // to an arbitrary unused VPN group. This survives _meta stripping.
        val rules = route.optJSONArray("rules") ?: return null
        val probeRules = (0 until rules.length()).mapNotNull { rules.optJSONObject(it) }
            .filter { rule ->
                rule.keys().asSequence().toSet() ==
                    setOf("domain", "network", "port", "action", "outbound") &&
                    isOwnedProbeDomain(rule) && rule.optString("network") == "tcp" &&
                    rule.optJSONArray("port")?.let { it.length() == 1 && it.opt(0) == 443 } == true &&
                    rule.optString("action") == "route"
            }
        val target = probeRules.singleOrNull()?.optString("outbound") ?: return null
        if (!isSafeTag(target) || target == finalTag) return null
        val dns = config.optJSONObject("dns") ?: return null
        val dnsRules = dns.optJSONArray("rules") ?: return null
        val probeDns = (0 until dnsRules.length()).mapNotNull { dnsRules.optJSONObject(it) }
            .filter { rule ->
                rule.keys().asSequence().toSet() ==
                    setOf("domain", "action", "server", "disable_cache", "rewrite_ttl") &&
                    isOwnedProbeDomain(rule) && rule.optString("action") == "route" &&
                    rule.opt("disable_cache") == true && rule.opt("rewrite_ttl") == 0
            }.singleOrNull() ?: return null
        val dnsTag = probeDns.optString("server")
        if (!isSafeTag(dnsTag)) return null
        val servers = dns.optJSONArray("servers") ?: return null
        val resolver = (0 until servers.length()).mapNotNull { servers.optJSONObject(it) }
            .filter { it.optString("tag") == dnsTag }.singleOrNull() ?: return null
        return target.takeIf { resolver.optString("detour") == target }
    }

    private fun isOwnedProbeDomain(rule: JSONObject): Boolean =
        rule.optJSONArray("domain")?.let {
            it.length() == 1 && it.opt(0) == "api.pokrov.space"
        } == true

    internal fun resolveFinalTarget(
        finalTag: String,
        outboundTypes: Map<String, String>,
        endpointTypes: Map<String, String>,
    ): AndroidCoreEgressProbeTarget? {
        if (!isSafeTag(finalTag)) {
            return null
        }
        val outboundType = outboundTypes[finalTag]
        if (outboundType != null) {
            return if (isSelectableGroupType(outboundType)) {
                AndroidCoreEgressProbeTarget(
                    tag = finalTag,
                    kind = AndroidCoreEgressProbeTargetKind.GROUP,
                )
            } else {
                null
            }
        }
        val endpointType = endpointTypes[finalTag] ?: return null
        return if (isProbeableEndpointType(endpointType)) {
            AndroidCoreEgressProbeTarget(
                tag = finalTag,
                kind = AndroidCoreEgressProbeTargetKind.ENDPOINT,
                // Closed owner labs retain the Android TUN long enough to
                // expose packet evidence. The TUN remains the fail-closed
                // boundary while the UI reports degraded egress.
                keepRuntimeOnFailure = endpointType.trim().equals("awg", ignoreCase = true),
                captureSafeFailureCategory = endpointType.trim().equals(
                    "awg",
                    ignoreCase = true,
                ),
            )
        } else {
            null
        }
    }

    fun finalGroupTag(configContent: String): String? =
        finalTarget(configContent)
            ?.takeIf { it.kind == AndroidCoreEgressProbeTargetKind.GROUP }
            ?.tag

    fun probe(
        target: AndroidCoreEgressProbeTarget,
        server: Any? = null,
        periodicCancellation: RuntimeProbeCancellation? = null,
        onFailure: ((String, String) -> Unit)? = null,
    ): AndroidCoreEgressProbeResult {
        if (!isSafeTag(target.tag)) {
            onFailure?.invoke("target_unavailable", "none")
            return AndroidCoreEgressProbeResult.UNAVAILABLE
        }
        // Periodic checks use one Core deadline, without startup readiness,
        // retry or diagnostic-log waits.
        if (periodicCancellation != null) return resultFromCore(server, target, periodicCancellation, onFailure)
        if (!target.captureSafeFailureCategory) return resultFromCore(server, target, onFailure = onFailure)

        // The command stream is diagnostic only. It cannot settle health.
        val handler = ProbeHandler()
        val options = CommandClientOptions().apply { addCommand(Libbox.CommandLog) }
        val client = Libbox.newCommandClient(handler, options)
        val captureReady = runCatching {
            client.connect()
            handler.awaitInitialLogBatch()
        }.getOrDefault(false)
        return try {
            handler.arm()
            val result = resultFromCore(server, target, onFailure = onFailure)
            if (captureReady && result.isCompletedFailure) {
                handler.awaitSafeFailureCategory()
            }
            result
        } finally {
            runCatching { client.disconnect() }
        }
    }

    internal fun resultFromCore(
        server: Any?,
        target: AndroidCoreEgressProbeTarget,
        periodicCancellation: RuntimeProbeCancellation? = null,
        onFailure: ((String, String) -> Unit)? = null,
    ): AndroidCoreEgressProbeResult {
        if (server == null || !isSafeTag(target.tag)) {
            onFailure?.invoke(if (server == null) "runtime_unavailable" else "target_unavailable", "none")
            return AndroidCoreEgressProbeResult.UNAVAILABLE
        }
        return try {
            val result = if (periodicCancellation != null) {
                server.javaClass.getMethod("probeRuntimeEgress", String::class.java,
                    Int::class.javaPrimitiveType, RuntimeProbeCancellation::class.java)
                    .invoke(server, target.tag, PERIODIC_TIMEOUT_MILLIS, periodicCancellation)
            } else {
                val methodName = if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) {
                    "probeEndpoint"
                } else {
                    "probeSelectedOutbound"
                }
                server.javaClass.getMethod(methodName, String::class.java).invoke(server, target.tag)
            }
            // Each synchronous result belongs to this captured server and call.
            // Old artifacts cannot prove health through an unrelated cache/event.
            when (result) {
                true -> AndroidCoreEgressProbeResult.HEALTHY
                false -> AndroidCoreEgressProbeResult.FAILED
                else -> {
                    onFailure?.invoke("other", "none")
                    AndroidCoreEgressProbeResult.UNAVAILABLE
                }
            }
        } catch (error: InvocationTargetException) {
            safeFailureDiagnostic(error).let { onFailure?.invoke(it.first, it.second) }
            // Core ProbeError.Error() exposes only these closed stage strings.
            // Never publish or infer a cause from arbitrary exception text.
            when (error.targetException?.message) {
                "context deadline exceeded" -> if (periodicCancellation != null) {
                    AndroidCoreEgressProbeResult.TIMED_OUT
                } else {
                    AndroidCoreEgressProbeResult.UNAVAILABLE
                }
                "URL probe connection failed" -> AndroidCoreEgressProbeResult.CONNECT_FAILED
                "URL probe TLS negotiation failed" -> AndroidCoreEgressProbeResult.TLS_FAILED
                "URL probe response failed", "URL probe failed" -> AndroidCoreEgressProbeResult.FAILED
                else -> AndroidCoreEgressProbeResult.UNAVAILABLE
            }
        } catch (error: Throwable) {
            safeFailureDiagnostic(error).let { onFailure?.invoke(it.first, it.second) }
            AndroidCoreEgressProbeResult.UNAVAILABLE
        }
    }

    /** Exact Core strings and standard class categories only; never raw error text. */
    internal fun safeFailureDiagnostic(error: Throwable): Pair<String, String> {
        val cause = if (error is InvocationTargetException) error.targetException ?: error else error
        val code = when (cause.message) {
            "context deadline exceeded" -> "deadline"
            "context canceled" -> "cancelled"
            "selected route probe unavailable", "runtime egress probe unavailable",
            "endpoint probe unavailable" -> "runtime_unavailable"
            "selected route probe target unavailable", "endpoint probe target unavailable",
            "endpoint probe target unsupported" -> "target_unavailable"
            "URL probe connection failed" -> "connect_failed"
            "URL probe TLS negotiation failed" -> "tls_failed"
            "URL probe response failed", "URL probe failed" -> "response_failed"
            else -> if (cause is ReflectiveOperationException || cause is LinkageError ||
                cause is SecurityException) "reflection_unavailable" else "other"
        }
        val errorType = when (cause) {
            is NoSuchMethodException -> "no_such_method"
            is IllegalAccessException -> "illegal_access"
            is SecurityException -> "security"
            is LinkageError -> "linkage"
            is IllegalStateException -> "illegal_state"
            is InterruptedException -> "interrupted"
            else -> if (cause.javaClass == Exception::class.java) "exception" else "other"
        }
        return code to errorType
    }

    /** Observe the existing group stream in parallel; health never waits for it. */
    fun observeSelection(scope: AndroidLifecycleTaskScope, configContent: String,
        target: AndroidCoreEgressProbeTarget, isCurrent: () -> Boolean,
        publish: (Boolean?, String) -> Unit,
    ): () -> Unit {
        val defaults = mutableMapOf<String, String>()
        val outbounds = JSONObject(configContent).optJSONArray("outbounds")
        for (index in 0 until (outbounds?.length() ?: 0)) {
            val outbound = outbounds?.optJSONObject(index) ?: continue
            if (outbound.optString("type") == "selector") {
                defaults[outbound.optString("tag")] = outbound.optString("default")
                    .ifBlank { outbound.optJSONArray("outbounds")?.optString(0).orEmpty() }
            }
        }
        if (target.tag !in defaults) return {}
        val stopped = AtomicBoolean(false)
        val connected = AtomicBoolean(false)
        var close: () -> Unit = {}
        val handler = ProbeHandler { iterator ->
            if (!stopped.get() && isCurrent()) {
                val selected = mutableMapOf<String, String>()
                val types = mutableMapOf<String, String>()
                while (iterator.hasNext()) {
                    val group = iterator.next()
                    selected[group.tag] = group.selected
                    val items = group.items
                    while (items.hasNext()) {
                        val item = items.next()
                        types[item.tag] = item.type
                    }
                }
                val receipt = selectionDiagnostic(target.tag, defaults, selected, types)
                if (receipt != null && stopped.compareAndSet(false, true)) {
                    try { if (isCurrent()) publish(receipt.first, receipt.second) } finally { close() }
                }
            }
        }
        val client = Libbox.newCommandClient(handler,
            CommandClientOptions().apply { addCommand(Libbox.CommandGroup) })
        close = { stopped.set(true); if (connected.get()) runCatching { client.disconnect() }; Unit }
        scope.onCancel(close)
        if (!scope.execute {
            try {
                if (!stopped.get() && isCurrent()) { client.connect(); connected.set(true) }
            }
            catch (_: Throwable) { close() }
            finally { if (stopped.get() || !isCurrent()) close() }
        }) close()
        return close
    }

    internal fun selectionDiagnostic(root: String, defaults: Map<String, String>,
        selected: Map<String, String>, types: Map<String, String>,
    ): Pair<Boolean?, String>? {
        if (root !in selected || root !in defaults) return null
        var tag = root
        var matches = true
        val visited = mutableSetOf<String>()
        while (tag in selected) {
            if (!visited.add(tag)) return null
            val next = selected.getValue(tag)
            defaults[tag]?.let { matches = matches && it == next }
            tag = next
        }
        if (types[tag] in setOf("selector", "urltest")) return null to "unknown"
        val protocol = types[tag]?.takeIf { it in setOf("vless", "hysteria2", "awg", "warp", "direct", "block", "dns") }
            ?: "unknown"
        return matches to protocol
    }

    internal fun isSafeTag(value: String): Boolean =
        value.isNotBlank() &&
            value.length <= MAX_TAG_LENGTH &&
            value.none { it.isISOControl() }

    internal fun isSelectableGroupType(value: String): Boolean =
        value.trim().lowercase() in SELECTABLE_TYPES

    internal fun isProbeableEndpointType(value: String): Boolean =
        value.trim().lowercase() in PROBEABLE_ENDPOINT_TYPES

    internal fun resolveSelectedOutbound(
        groups: Map<String, AndroidCoreEgressProbeGroupSnapshot>,
        rootGroupTag: String,
    ): AndroidCoreEgressProbeSelection? {
        var currentGroupTag = rootGroupTag
        val visited = mutableSetOf<String>()
        while (visited.add(currentGroupTag)) {
            val group = groups[currentGroupTag] ?: return null
            val selected = group.selected
            if (selected.isBlank() || !group.items.containsKey(selected)) {
                return null
            }
            if (groups.containsKey(selected)) {
                currentGroupTag = selected
                continue
            }
            return AndroidCoreEgressProbeSelection(
                groupTag = currentGroupTag,
                outboundTag = selected,
                sample = group.items[selected],
            )
        }
        return null
    }

    private class ProbeHandler(private val onGroups: ((OutboundGroupIterator) -> Unit)? = null) : CommandClientHandler {
        private val initialLogBatchLatch = CountDownLatch(1)
        private val safeFailureCategoryLatch = CountDownLatch(1)
        @Volatile private var armed = false

        fun awaitInitialLogBatch(): Boolean =
            initialLogBatchLatch.await(INITIAL_LOG_BATCH_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun arm() { armed = true }

        fun awaitSafeFailureCategory() {
            safeFailureCategoryLatch.await(SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)
        }

        override fun writeGroups(groups: OutboundGroupIterator) { onGroups?.invoke(groups) }
        override fun clearLogs() = Unit
        override fun connected() = Unit
        override fun disconnected(message: String) = Unit
        override fun initializeClashMode(modes: StringIterator, currentMode: String) = Unit
        override fun setDefaultLogLevel(level: Int) = Unit
        override fun updateClashMode(newMode: String) = Unit
        override fun writeConnectionEvents(events: ConnectionEvents) = Unit
        override fun writeStatus(status: StatusMessage) = Unit
        override fun writeLogs(logs: LogIterator) {
            val armedForCurrentProbe = armed
            while (logs.hasNext()) {
                val message = logs.next().message
                if (!armedForCurrentProbe) continue
                val diagnostic = AndroidRuntimeLogClassifier.parseAwgEgressProbeDiagnostic(message) ?: continue
                AndroidRuntimeState.recordAwgSafeDiagnostic(diagnostic)
                safeFailureCategoryLatch.countDown()
            }
            initialLogBatchLatch.countDown()
        }
    }

    internal fun isHealthySample(time: Long, delay: Int): Boolean =
        time > 0L && delay in 1 until URL_TEST_TIMEOUT_DELAY

    internal fun urlTestTimeMillis(unixSeconds: Long): Long =
        if (unixSeconds in 1..Long.MAX_VALUE / 1_000L) unixSeconds * 1_000L else 0L

    internal const val PERIODIC_TIMEOUT_MILLIS = 3_000
    private const val MAX_TAG_LENGTH = 128
    private const val URL_TEST_TIMEOUT_DELAY = 65_535
    private const val INITIAL_LOG_BATCH_TIMEOUT_MILLIS = 2_500L
    private const val SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS = 750L
    private val SELECTABLE_TYPES = setOf("selector", "urltest")
    private val PROBEABLE_ENDPOINT_TYPES = setOf("warp", "awg")
}
