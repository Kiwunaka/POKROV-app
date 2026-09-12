package space.pokrov.pokrov_android_shell

import org.json.JSONObject
import space.pokrov.core.libbox.CommandClientHandler
import space.pokrov.core.libbox.CommandClientOptions
import space.pokrov.core.libbox.ConnectionEvents
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.LogIterator
import space.pokrov.core.libbox.OutboundGroupIterator
import space.pokrov.core.libbox.StatusMessage
import space.pokrov.core.libbox.StringIterator
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
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

    fun failureKind(): String = when (this) {
        FAILED -> "core_egress_probe_failed"
        CONNECT_FAILED -> "core_egress_connect_failed"
        TLS_FAILED -> "core_egress_tls_failed"
        else -> "core_egress_probe_unavailable"
    }
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

/** Runs the core's own URL test for the outbound selected by route.final. */
internal object AndroidCoreEgressProbe {
    fun finalTarget(configContent: String): AndroidCoreEgressProbeTarget? {
        return runCatching {
            val config = JSONObject(configContent)
            val tag = config.optJSONObject("route")?.optString("final")?.trim().orEmpty()
            if (!isSafeTag(tag)) {
                return@runCatching null
            }
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

    fun probe(target: AndroidCoreEgressProbeTarget, server: Any? = null): AndroidCoreEgressProbeResult {
        if (!isSafeTag(target.tag)) return AndroidCoreEgressProbeResult.UNAVAILABLE
        if (!target.captureSafeFailureCategory) return resultFromCore(server, target)

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
            val result = resultFromCore(server, target)
            if (captureReady && result.isCompletedFailure) {
                handler.awaitSafeFailureCategory()
            }
            result
        } finally {
            runCatching { client.disconnect() }
        }
    }

    internal fun resultFromCore(server: Any?, target: AndroidCoreEgressProbeTarget): AndroidCoreEgressProbeResult {
        if (server == null || !isSafeTag(target.tag)) return AndroidCoreEgressProbeResult.UNAVAILABLE
        return try {
            val methodName = if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) {
                "probeEndpoint"
            } else {
                "probeSelectedOutbound"
            }
            // Each synchronous result belongs to this captured server and call.
            // Old artifacts cannot prove health through an unrelated cache/event.
            val method = server.javaClass.getMethod(methodName, String::class.java)
            when (method.invoke(server, target.tag)) {
                true -> AndroidCoreEgressProbeResult.HEALTHY
                false -> AndroidCoreEgressProbeResult.FAILED
                else -> AndroidCoreEgressProbeResult.UNAVAILABLE
            }
        } catch (error: InvocationTargetException) {
            // Core ProbeError.Error() exposes only these closed stage strings.
            // Never publish or infer a cause from arbitrary exception text.
            when (error.targetException?.message) {
                "URL probe connection failed" -> AndroidCoreEgressProbeResult.CONNECT_FAILED
                "URL probe TLS negotiation failed" -> AndroidCoreEgressProbeResult.TLS_FAILED
                "URL probe response failed", "URL probe failed" -> AndroidCoreEgressProbeResult.FAILED
                else -> AndroidCoreEgressProbeResult.UNAVAILABLE
            }
        } catch (_: Throwable) {
            AndroidCoreEgressProbeResult.UNAVAILABLE
        }
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

    private class ProbeHandler : CommandClientHandler {
        private val initialLogBatchLatch = CountDownLatch(1)
        private val safeFailureCategoryLatch = CountDownLatch(1)
        @Volatile private var armed = false

        fun awaitInitialLogBatch(): Boolean =
            initialLogBatchLatch.await(INITIAL_LOG_BATCH_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun arm() { armed = true }

        fun awaitSafeFailureCategory() {
            safeFailureCategoryLatch.await(SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)
        }

        override fun writeGroups(groups: OutboundGroupIterator) = Unit
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

    private const val MAX_TAG_LENGTH = 128
    private const val URL_TEST_TIMEOUT_DELAY = 65_535
    private const val INITIAL_LOG_BATCH_TIMEOUT_MILLIS = 2_500L
    private const val SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS = 750L
    private val SELECTABLE_TYPES = setOf("selector", "urltest")
    private val PROBEABLE_ENDPOINT_TYPES = setOf("warp", "awg")
}
