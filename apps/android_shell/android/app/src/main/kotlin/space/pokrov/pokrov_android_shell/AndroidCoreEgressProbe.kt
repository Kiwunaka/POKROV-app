package space.pokrov.pokrov_android_shell

import android.util.Log
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
            addCommand(Libbox.CommandLog)
        }
        val client = Libbox.newCommandClient(handler, options)
        var endpointHandlerRegistered = false
        return try {
            client.connect()
            client.clearLogs()
            handler.resetLogs()
            if (target.kind == AndroidCoreEgressProbeTargetKind.GROUP) {
                if (!handler.awaitInitial()) {
                    return AndroidCoreEgressProbeResult.UNAVAILABLE
                }
                val testGroupTag = handler.armGroup()
                    ?: return AndroidCoreEgressProbeResult.UNAVAILABLE
                client.urlTest(testGroupTag)
            } else {
                handler.armEndpoint()
                if (!activeEndpointHandler.compareAndSet(null, handler)) {
                    return AndroidCoreEgressProbeResult.UNAVAILABLE
                }
                endpointHandlerRegistered = true
                client.urlTest(target.tag)
            }
            handler.awaitResult()
        } catch (_: Throwable) {
            AndroidCoreEgressProbeResult.UNAVAILABLE
        } finally {
            if (endpointHandlerRegistered) {
                activeEndpointHandler.compareAndSet(handler, null)
            }
            runCatching { client.disconnect() }
        }
    }

    fun writeCoreDebugMessage(message: String) {
        activeEndpointHandler.get()?.writeCoreDebugMessage(message)
    }

    internal fun endpointResultFromMessage(message: String): AndroidCoreEgressProbeResult? =
        when {
            message.contains(ENDPOINT_SUCCESS_MARKER) ||
                message == ENDPOINT_DEBUG_SUCCESS_MARKER -> AndroidCoreEgressProbeResult.HEALTHY
            message.contains(ENDPOINT_FAILURE_MARKER) ||
                (
                    message.startsWith(ENDPOINT_DEBUG_PREFIX) &&
                        message != ENDPOINT_DEBUG_SUCCESS_MARKER
                    ) -> AndroidCoreEgressProbeResult.FAILED
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
        private val resultLatch = CountDownLatch(1)
        private var currentSelection: AndroidCoreEgressProbeSelection? = null
        private var baseline: AndroidCoreEgressProbeSelection? = null
        private var armed = false
        private var result: AndroidCoreEgressProbeResult? = null
        private val coreLogMessages = mutableListOf<String>()
        private var postArmUpdates = 0
        private var latestGroupItemCount = 0
        private var latestHealthyItemCount = 0
        private var latestSelectedHasSample = false

        fun awaitInitial(): Boolean =
            initialLatch.await(INITIAL_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun armGroup(): String? =
            synchronized(lock) {
                val selection = currentSelection ?: return@synchronized null
                baseline = selection
                armed = true
                selection.groupTag
            }

        fun armEndpoint() {
            synchronized(lock) {
                armed = true
            }
        }

        fun resetLogs() {
            synchronized(lock) {
                coreLogMessages.clear()
            }
        }

        fun writeCoreDebugMessage(message: String) {
            synchronized(lock) {
                if (coreLogMessages.size < MAX_LOG_MESSAGES) {
                    coreLogMessages += message
                }
                acceptEndpointResult(message)
            }
        }

        fun awaitResult(): AndroidCoreEgressProbeResult {
            val timeoutMillis = if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) {
                ENDPOINT_RESULT_TIMEOUT_MILLIS
            } else {
                RESULT_TIMEOUT_MILLIS
            }
            if (!resultLatch.await(timeoutMillis, TimeUnit.MILLISECONDS)) {
                val summary = synchronized(lock) {
                    "coreCategories=" + coreFailureCategories() +
                        " coreHints=" + AndroidRuntimeSafety.safeCoreFailureHints(coreLogMessages.joinToString(" ")) +
                        " updates=$postArmUpdates" +
                        " groupItems=$latestGroupItemCount" +
                        " healthyItems=$latestHealthyItemCount" +
                        " selectedSample=$latestSelectedHasSample"
                }
                Log.e(LOG_TAG, "Android egress probe timeout $summary")
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
                if (armed) {
                    val rootGroup = snapshots[target.tag]
                    postArmUpdates += 1
                    latestGroupItemCount = rootGroup?.items?.size ?: 0
                    latestHealthyItemCount = rootGroup?.items?.values?.count { sample ->
                        sample != null && isHealthySample(sample.time, sample.delay)
                    } ?: 0
                    latestSelectedHasSample = selection.sample != null
                }
                if (armed && resultLatch.count > 0L && selection != baseline) {
                    val sample = selection.sample
                    result = if (sample != null && isHealthySample(sample.time, sample.delay)) {
                        AndroidCoreEgressProbeResult.HEALTHY
                    } else {
                        AndroidCoreEgressProbeResult.FAILED
                    }
                    Log.e(
                        LOG_TAG,
                        "Android egress probe terminal result=" + result?.name?.lowercase() +
                            " coreCategories=" + coreFailureCategories() +
                            " coreHints=" + AndroidRuntimeSafety.safeCoreFailureHints(
                                coreLogMessages.joinToString(" "),
                            ) +
                            " updates=$postArmUpdates" +
                            " groupItems=$latestGroupItemCount" +
                            " healthyItems=$latestHealthyItemCount" +
                            " selectedSample=$latestSelectedHasSample",
                    )
                    resultLatch.countDown()
                }
            }
        }

        override fun clearLogs() = resetLogs()
        override fun connected() = Unit
        override fun disconnected(message: String) = Unit
        override fun initializeClashMode(modes: StringIterator, currentMode: String) = Unit
        override fun setDefaultLogLevel(level: Int) = Unit
        override fun updateClashMode(newMode: String) = Unit
        override fun writeConnectionEvents(events: ConnectionEvents) = Unit
        override fun writeLogs(logs: LogIterator) {
            synchronized(lock) {
                while (logs.hasNext() && coreLogMessages.size < MAX_LOG_MESSAGES) {
                    val message = logs.next().message
                    coreLogMessages += message
                    acceptEndpointResult(message)
                }
            }
        }
        override fun writeStatus(status: StatusMessage) = Unit

        private fun coreFailureCategories(): String = coreLogMessages
            .mapNotNull { message ->
                CORE_FAILURE_CATEGORY.find(message)?.groupValues?.getOrNull(1)
            }
            .distinct()
            .take(MAX_CORE_FAILURE_CATEGORIES)
            .joinToString(",")
            .ifEmpty { "none" }

        private fun acceptEndpointResult(message: String) {
            if (
                target.kind != AndroidCoreEgressProbeTargetKind.ENDPOINT ||
                !armed ||
                resultLatch.count == 0L
            ) {
                return
            }
            val terminalResult = endpointResultFromMessage(message) ?: return
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
    // POKROV Core's HTTP URL-test timeout is 15 seconds. The host must wait
    // through that terminal sample instead of misclassifying a slow failure as
    // an early command-channel failure.
    private const val RESULT_TIMEOUT_MILLIS = 16_500L
    // A first client-local WARP start may need to register and persist its
    // endpoint before the 15-second traffic probe can begin.
    private const val ENDPOINT_RESULT_TIMEOUT_MILLIS = 48_000L
    private const val MAX_LOG_MESSAGES = 128
    private const val MAX_CORE_FAILURE_CATEGORIES = 4
    private const val LOG_TAG = "PokrovEgressProbe"
    private const val ENDPOINT_SUCCESS_MARKER = "selected endpoint URL test succeeded"
    private const val ENDPOINT_FAILURE_MARKER = "selected endpoint URL test failed category="
    private const val ENDPOINT_DEBUG_PREFIX = "selected_endpoint_url_test:"
    private const val ENDPOINT_DEBUG_SUCCESS_MARKER = "${ENDPOINT_DEBUG_PREFIX}healthy"
    private val activeEndpointHandler = AtomicReference<ProbeHandler?>()
    private val CORE_FAILURE_CATEGORY = Regex("category=([a-z_]{1,48})")
    private val SELECTABLE_TYPES = setOf("selector", "urltest")
    private val PROBEABLE_ENDPOINT_TYPES = setOf("warp")
}
