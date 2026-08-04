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

internal enum class AndroidCoreEgressProbeResult {
    HEALTHY,
    FAILED,
    UNAVAILABLE,
    TIMED_OUT,
}

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
    fun finalGroupTag(configContent: String): String? {
        return runCatching {
            val config = JSONObject(configContent)
            val tag = config.optJSONObject("route")?.optString("final")?.trim().orEmpty()
            if (!isSafeTag(tag)) {
                return@runCatching null
            }
            val outbounds = config.optJSONArray("outbounds") ?: return@runCatching null
            for (index in 0 until outbounds.length()) {
                val outbound = outbounds.optJSONObject(index) ?: continue
                if (outbound.optString("tag").trim() != tag) {
                    continue
                }
                return@runCatching tag.takeIf {
                    isSelectableGroupType(outbound.optString("type"))
                }
            }
            null
        }.getOrNull()
    }

    fun probe(groupTag: String): AndroidCoreEgressProbeResult {
        if (!isSafeTag(groupTag)) {
            return AndroidCoreEgressProbeResult.UNAVAILABLE
        }
        val handler = ProbeHandler(groupTag)
        val options = CommandClientOptions().apply {
            addCommand(Libbox.CommandGroup)
        }
        val client = Libbox.newCommandClient(handler, options)
        return try {
            client.connect()
            if (!handler.awaitInitial()) {
                return AndroidCoreEgressProbeResult.UNAVAILABLE
            }
            val testGroupTag = handler.arm() ?: return AndroidCoreEgressProbeResult.UNAVAILABLE
            client.urlTest(testGroupTag)
            handler.awaitResult()
        } catch (_: Throwable) {
            AndroidCoreEgressProbeResult.UNAVAILABLE
        } finally {
            runCatching { client.disconnect() }
        }
    }

    internal fun isSafeTag(value: String): Boolean =
        value.isNotBlank() &&
            value.length <= MAX_TAG_LENGTH &&
            value.none { it.isISOControl() }

    internal fun isSelectableGroupType(value: String): Boolean =
        value.trim().lowercase() in SELECTABLE_TYPES

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
        private val groupTag: String,
    ) : CommandClientHandler {
        private val lock = Any()
        private val initialLatch = CountDownLatch(1)
        private val resultLatch = CountDownLatch(1)
        private var currentSelection: AndroidCoreEgressProbeSelection? = null
        private var baseline: AndroidCoreEgressProbeSelection? = null
        private var armed = false
        private var result: AndroidCoreEgressProbeResult? = null

        fun awaitInitial(): Boolean =
            initialLatch.await(INITIAL_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun arm(): String? =
            synchronized(lock) {
                val selection = currentSelection ?: return@synchronized null
                baseline = selection
                armed = true
                selection.groupTag
            }

        fun awaitResult(): AndroidCoreEgressProbeResult {
            if (!resultLatch.await(RESULT_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)) {
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
                        AndroidCoreEgressProbeSample(item.urlTestTime, item.urlTestDelay)
                    } else {
                        null
                    }
                }
                snapshots[group.tag] = AndroidCoreEgressProbeGroupSnapshot(
                    selected = group.selected,
                    items = itemSamples,
                )
            }
            val selection = resolveSelectedOutbound(snapshots, groupTag) ?: return
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
        override fun writeLogs(logs: LogIterator) = Unit
        override fun writeStatus(status: StatusMessage) = Unit
    }

    internal fun isHealthySample(time: Long, delay: Int): Boolean =
        time > 0L && delay in 1 until URL_TEST_TIMEOUT_DELAY

    private const val MAX_TAG_LENGTH = 128
    // POKROV Core stores failed URL tests with sing-box's uint16 max sentinel.
    private const val URL_TEST_TIMEOUT_DELAY = 65_535
    private const val INITIAL_TIMEOUT_MILLIS = 2_500L
    // POKROV Core's HTTP URL-test timeout is 15 seconds. The host must wait
    // through that terminal sample instead of misclassifying a slow failure as
    // an early command-channel failure.
    private const val RESULT_TIMEOUT_MILLIS = 16_500L
    private val SELECTABLE_TYPES = setOf("selector", "urltest")
}
