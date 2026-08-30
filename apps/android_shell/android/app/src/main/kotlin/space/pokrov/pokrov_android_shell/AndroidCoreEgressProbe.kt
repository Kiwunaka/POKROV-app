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
import java.util.concurrent.atomic.AtomicReference

internal enum class AndroidCoreEgressProbeResult {
    HEALTHY,
    FAILED,
    UNAVAILABLE,
    TIMED_OUT,
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
                            result == AndroidCoreEgressProbeResult.FAILED
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

    fun probe(target: AndroidCoreEgressProbeTarget): AndroidCoreEgressProbeResult {
        if (!isSafeTag(target.tag)) {
            return AndroidCoreEgressProbeResult.UNAVAILABLE
        }
        val handler = ProbeHandler(target)
        val options = CommandClientOptions().apply {
            addCommand(Libbox.CommandGroup)
            if (target.captureSafeFailureCategory) {
                addCommand(Libbox.CommandLog)
            }
        }
        val client = Libbox.newCommandClient(handler, options)
        var endpointHandlerRegistered = false
        var safeFailureCaptureReady = false
        return try {
            client.connect()
            if (target.kind == AndroidCoreEgressProbeTargetKind.GROUP) {
                if (!handler.awaitInitial()) {
                    return AndroidCoreEgressProbeResult.UNAVAILABLE
                }
                val testGroupTag = handler.armGroup()
                    ?: return AndroidCoreEgressProbeResult.UNAVAILABLE
                client.urlTest(testGroupTag)
            } else {
                safeFailureCaptureReady =
                    target.captureSafeFailureCategory && handler.awaitInitialLogBatch()
                handler.armEndpoint(safeFailureCaptureReady)
                if (!activeEndpointHandler.compareAndSet(null, handler)) {
                    return AndroidCoreEgressProbeResult.UNAVAILABLE
                }
                endpointHandlerRegistered = true
                client.urlTest(target.tag)
            }
            val result = handler.awaitResult()
            if (
                result == AndroidCoreEgressProbeResult.FAILED &&
                safeFailureCaptureReady
            ) {
                handler.awaitSafeFailureCategory()
            }
            result
        } catch (_: Throwable) {
            AndroidCoreEgressProbeResult.UNAVAILABLE
        } finally {
            if (endpointHandlerRegistered) {
                activeEndpointHandler.compareAndSet(handler, null)
            }
            runCatching { client.disconnect() }
        }
    }

    fun writeCoreOperationalEvent(event: AndroidCoreOperationalEventRecord) {
        activeEndpointHandler.get()?.writeCoreOperationalEvent(event)
    }

    internal fun endpointResultFromOperationalEvent(
        name: String,
        outcome: String,
        errorCode: String?,
    ): AndroidCoreEgressProbeResult? = when {
        name != "core.egress.probe" -> null
        outcome == "succeeded" && errorCode == null -> AndroidCoreEgressProbeResult.HEALTHY
        outcome == "failed" && errorCode == "EGRESS-001" -> AndroidCoreEgressProbeResult.FAILED
        else -> null
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

    private class ProbeHandler(
        private val target: AndroidCoreEgressProbeTarget,
    ) : CommandClientHandler {
        private val lock = Any()
        private val initialLatch = CountDownLatch(1)
        private val initialLogBatchLatch = CountDownLatch(1)
        private val safeFailureCategoryLatch = CountDownLatch(1)
        private val resultLatch = CountDownLatch(1)
        private var currentSelection: AndroidCoreEgressProbeSelection? = null
        private var baseline: AndroidCoreEgressProbeSelection? = null
        private var armed = false
        private var safeFailureCaptureArmed = false
        private var result: AndroidCoreEgressProbeResult? = null

        fun awaitInitial(): Boolean =
            initialLatch.await(INITIAL_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun awaitInitialLogBatch(): Boolean =
            initialLogBatchLatch.await(INITIAL_LOG_BATCH_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun awaitSafeFailureCategory() {
            safeFailureCategoryLatch.await(SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)
        }

        fun armGroup(): String? =
            synchronized(lock) {
                val selection = currentSelection ?: return@synchronized null
                baseline = selection
                armed = true
                selection.groupTag
            }

        fun armEndpoint(captureSafeFailureCategory: Boolean) {
            synchronized(lock) {
                armed = true
                safeFailureCaptureArmed = captureSafeFailureCategory
            }
        }

        fun writeCoreOperationalEvent(event: AndroidCoreOperationalEventRecord) {
            synchronized(lock) {
                acceptEndpointResult(event)
            }
        }

        fun awaitResult(): AndroidCoreEgressProbeResult {
            val timeoutMillis = if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) {
                ENDPOINT_RESULT_TIMEOUT_MILLIS
            } else {
                RESULT_TIMEOUT_MILLIS
            }
            if (!resultLatch.await(timeoutMillis, TimeUnit.MILLISECONDS)) {
                return AndroidCoreEgressProbeResult.TIMED_OUT
            }
            return synchronized(lock) {
                result ?: AndroidCoreEgressProbeResult.UNAVAILABLE
            }
        }

        override fun writeGroups(groups: OutboundGroupIterator) {
            val snapshots = mutableMapOf<String, AndroidCoreEgressProbeGroupSnapshot>()
            while (groups.hasNext()) {
                val group = groups.next()
                val items = group.items
                val itemSamples = mutableMapOf<String, AndroidCoreEgressProbeSample?>()
                while (items.hasNext()) {
                    val item = items.next()
                    itemSamples[item.tag] = if (item.urlTestTime > 0L) {
                        AndroidCoreEgressProbeSample(
                            urlTestTimeMillis(item.urlTestTime),
                            item.urlTestDelay,
                        )
                    } else {
                        null
                    }
                }
                snapshots[group.tag] = AndroidCoreEgressProbeGroupSnapshot(
                    selected = group.selected,
                    items = itemSamples,
                )
            }
            if (target.kind != AndroidCoreEgressProbeTargetKind.GROUP) {
                return
            }
            val selection = resolveSelectedOutbound(snapshots, target.tag) ?: return
            synchronized(lock) {
                currentSelection = selection
                initialLatch.countDown()
                if (armed && resultLatch.count > 0L && selection != baseline) {
                    val sample = selection.sample
                    result = if (sample != null && isHealthySample(sample.time, sample.delay)) {
                        AndroidCoreEgressProbeResult.HEALTHY
                    } else {
                        AndroidCoreEgressProbeResult.FAILED
                    }
                    resultLatch.countDown()
                }
            }
        }

        override fun clearLogs() = Unit
        override fun connected() = Unit
        override fun disconnected(message: String) = Unit
        override fun initializeClashMode(modes: StringIterator, currentMode: String) = Unit
        override fun setDefaultLogLevel(level: Int) = Unit
        override fun updateClashMode(newMode: String) = Unit
        override fun writeConnectionEvents(events: ConnectionEvents) = Unit
        override fun writeLogs(logs: LogIterator) {
            if (!target.captureSafeFailureCategory) {
                return
            }
            val armedForCurrentProbe = synchronized(lock) { safeFailureCaptureArmed }
            while (logs.hasNext()) {
                val message = logs.next().message
                if (!armedForCurrentProbe) {
                    continue
                }
                val diagnostic = AndroidRuntimeLogClassifier.parseAwgEgressProbeDiagnostic(
                    message,
                ) ?: continue
                AndroidRuntimeState.recordAwgSafeDiagnostic(diagnostic)
                safeFailureCategoryLatch.countDown()
            }
            initialLogBatchLatch.countDown()
        }
        override fun writeStatus(status: StatusMessage) = Unit

        private fun acceptEndpointResult(event: AndroidCoreOperationalEventRecord) {
            if (
                target.kind != AndroidCoreEgressProbeTargetKind.ENDPOINT ||
                !armed ||
                resultLatch.count == 0L
            ) {
                return
            }
            val terminalResult = endpointResultFromOperationalEvent(
                event.name,
                event.outcome,
                event.errorCode,
            ) ?: return
            result = terminalResult
            resultLatch.countDown()
        }
    }

    internal fun isHealthySample(time: Long, delay: Int): Boolean =
        time > 0L && delay in 1 until URL_TEST_TIMEOUT_DELAY

    internal fun urlTestTimeMillis(unixSeconds: Long): Long =
        if (unixSeconds in 1..Long.MAX_VALUE / 1_000L) unixSeconds * 1_000L else 0L

    private const val MAX_TAG_LENGTH = 128
    // POKROV Core stores failed URL tests with sing-box's uint16 max sentinel.
    private const val URL_TEST_TIMEOUT_DELAY = 65_535
    private const val INITIAL_TIMEOUT_MILLIS = 2_500L
    private const val INITIAL_LOG_BATCH_TIMEOUT_MILLIS = 2_500L
    private const val SAFE_FAILURE_CATEGORY_TIMEOUT_MILLIS = 750L
    // POKROV Core's HTTP URL-test timeout is 15 seconds. The host must wait
    // through that terminal sample instead of misclassifying a slow failure as
    // an early command-channel failure.
    private const val RESULT_TIMEOUT_MILLIS = 16_500L
    // A first client-local WARP start may need to register and persist its
    // endpoint before the 15-second traffic probe can begin.
    private const val ENDPOINT_RESULT_TIMEOUT_MILLIS = 48_000L
    private val activeEndpointHandler = AtomicReference<ProbeHandler?>()
    private val SELECTABLE_TYPES = setOf("selector", "urltest")
    private val PROBEABLE_ENDPOINT_TYPES = setOf("warp", "awg")
}
