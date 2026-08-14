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

internal data class AndroidVariantProbeTarget(
    val id: String,
    val outboundTag: String,
)

internal data class AndroidVariantProbeCatalog(
    val groupTag: String,
    val finalGroupTag: String,
    val targets: List<AndroidVariantProbeTarget>,
)

private data class AndroidVariantProbeCache(
    val catalogKey: String,
    val capturedAtMs: Long,
    val snapshot: Map<String, Any?>,
)

/**
 * Measures the already-staged variant outbounds through POKROV Core.
 *
 * The config owns the private id-to-tag mapping. Only stable ids, coarse status,
 * latency and freshness cross the MethodChannel boundary; endpoint and transport
 * material never leave the Android host.
 */
internal object AndroidVariantAvailabilityProbe {
    @Volatile
    private var cachedSnapshot: AndroidVariantProbeCache? = null

    fun parseCatalog(configContent: String): AndroidVariantProbeCatalog? = runCatching {
        val config = JSONObject(configContent)
        val meta = config.optJSONObject("_meta")
            ?.optJSONObject("runtime_variant_probe")
            ?: return@runCatching null
        val groupTag = meta.optString("group_tag").trim()
        if (!AndroidCoreEgressProbe.isSafeTag(groupTag)) {
            return@runCatching null
        }
        val outbounds = config.optJSONArray("outbounds") ?: return@runCatching null
        var probeMembers: Set<String>? = null
        for (index in 0 until outbounds.length()) {
            val outbound = outbounds.optJSONObject(index) ?: continue
            if (
                outbound.optString("tag").trim() == groupTag &&
                outbound.optString("type").trim().equals("urltest", ignoreCase = true)
            ) {
                val members = outbound.optJSONArray("outbounds") ?: return@runCatching null
                probeMembers = buildSet {
                    for (memberIndex in 0 until members.length()) {
                        val tag = members.optString(memberIndex).trim()
                        if (AndroidCoreEgressProbe.isSafeTag(tag)) {
                            add(tag)
                        }
                    }
                }
                break
            }
        }
        val allowedMembers = probeMembers ?: return@runCatching null
        val mappings = meta.optJSONArray("mappings") ?: return@runCatching null
        val targets = mutableListOf<AndroidVariantProbeTarget>()
        for (index in 0 until minOf(mappings.length(), MAX_TARGETS)) {
            val mapping = mappings.optJSONObject(index) ?: continue
            val id = mapping.optString("id").trim().lowercase()
            val tag = mapping.optString("outbound_tag").trim()
            targets += AndroidVariantProbeTarget(id = id, outboundTag = tag)
        }
        val finalGroupTag = config.optJSONObject("route")
            ?.optString("final")
            ?.trim()
            .orEmpty()
        validateCatalog(
            groupTag = groupTag,
            finalGroupTag = finalGroupTag,
            probeMembers = allowedMembers,
            targets = targets,
        )
    }.getOrNull()

    internal fun validateCatalog(
        groupTag: String,
        finalGroupTag: String,
        probeMembers: Set<String>,
        targets: List<AndroidVariantProbeTarget>,
    ): AndroidVariantProbeCatalog? {
        if (
            !AndroidCoreEgressProbe.isSafeTag(groupTag) ||
            (finalGroupTag.isNotEmpty() && !AndroidCoreEgressProbe.isSafeTag(finalGroupTag)) ||
            probeMembers.isEmpty() ||
            probeMembers.size > MAX_TARGETS ||
            probeMembers.any { !AndroidCoreEgressProbe.isSafeTag(it) } ||
            targets.size != probeMembers.size ||
            targets.any {
                !SAFE_ID.matches(it.id) ||
                    !AndroidCoreEgressProbe.isSafeTag(it.outboundTag) ||
                    it.outboundTag !in probeMembers
            } ||
            targets.map { it.id }.toSet().size != targets.size ||
            targets.map { it.outboundTag }.toSet().size != targets.size
        ) {
            return null
        }
        return AndroidVariantProbeCatalog(
            groupTag = groupTag,
            finalGroupTag = finalGroupTag,
            targets = targets,
        )
    }

    fun probe(configContent: String, requestedVariantId: String = ""): Map<String, Any?> {
        val catalog = parseCatalog(configContent)
            ?: return unavailableSnapshot("profile_unavailable")
        val requestedId = requestedVariantId.trim().lowercase()
        if (
            requestedId.isNotEmpty() &&
            (!SAFE_ID.matches(requestedId) || catalog.targets.none { it.id == requestedId })
        ) {
            return unavailableSnapshot("variant_unavailable")
        }
        val liveSnapshot = probeLive(catalog)
        val liveComplete = isCompletedSnapshot(liveSnapshot, catalog)
        var cacheHit = false
        val resolvedSnapshot = if (liveComplete) {
            remember(catalog, liveSnapshot)
            liveSnapshot
        } else {
            cachedSnapshot(catalog, System.currentTimeMillis())?.also {
                cacheHit = true
            } ?: liveSnapshot
        }
        Log.i(
            LOG_TAG,
            "Android variant probe readback targets=${catalog.targets.size} " +
                "liveComplete=$liveComplete cacheHit=$cacheHit " +
                "results=${(resolvedSnapshot["results"] as? List<*>)?.size ?: 0}.",
        )
        return filterSnapshot(resolvedSnapshot, requestedId)
    }

    /**
     * Runs the private group test while Core is still alive after the selected
     * outbound failed. The TUN remains fail-closed during this bounded check;
     * only the safe in-memory status snapshot survives the service stop.
     */
    fun captureBeforeFailClosed(configContent: String): Boolean {
        val catalog = parseCatalog(configContent) ?: return false
        repeat(CAPTURE_CONNECT_ATTEMPTS) { attempt ->
            val snapshot = probeLive(catalog)
            if (isCompletedSnapshot(snapshot, catalog)) {
                remember(catalog, snapshot)
                return true
            }
            if (
                snapshot["errorCategory"] != "core_unavailable" ||
                attempt == CAPTURE_CONNECT_ATTEMPTS - 1
            ) {
                return false
            }
            Thread.sleep(CAPTURE_CONNECT_RETRY_MILLIS)
        }
        return false
    }

    private fun probeLive(catalog: AndroidVariantProbeCatalog): Map<String, Any?> {
        val handler = ProbeHandler(catalog)
        val options = CommandClientOptions().apply {
            addCommand(Libbox.CommandGroup)
        }
        val client = Libbox.newCommandClient(handler, options)
        return try {
            client.connect()
            if (!handler.awaitInitial()) {
                return unavailableSnapshot("core_unavailable", catalog.targets)
            }
            handler.arm()
            client.urlTest(catalog.groupTag)
            if (!handler.awaitResult()) {
                return unavailableSnapshot("timeout", catalog.targets)
            }
            handler.snapshot()
        } catch (error: Throwable) {
            Log.w(LOG_TAG, "Android variant probe client failure=${error.javaClass.simpleName}.")
            unavailableSnapshot("core_unavailable", catalog.targets)
        } finally {
            runCatching { client.disconnect() }
        }
    }

    internal fun rememberForTest(
        catalog: AndroidVariantProbeCatalog,
        snapshot: Map<String, Any?>,
        capturedAtMs: Long,
    ) {
        cachedSnapshot = AndroidVariantProbeCache(
            catalogKey = catalogKey(catalog),
            capturedAtMs = capturedAtMs,
            snapshot = snapshot,
        )
    }

    internal fun cachedSnapshotForTest(
        catalog: AndroidVariantProbeCatalog,
        nowMs: Long,
    ): Map<String, Any?>? = cachedSnapshot(catalog, nowMs)

    internal fun clearCacheForTest() {
        cachedSnapshot = null
    }

    private fun remember(
        catalog: AndroidVariantProbeCatalog,
        snapshot: Map<String, Any?>,
    ) {
        rememberForTest(
            catalog = catalog,
            snapshot = snapshot,
            capturedAtMs = System.currentTimeMillis(),
        )
    }

    private fun cachedSnapshot(
        catalog: AndroidVariantProbeCatalog,
        nowMs: Long,
    ): Map<String, Any?>? {
        val cached = cachedSnapshot ?: return null
        if (
            cached.catalogKey != catalogKey(catalog) ||
            nowMs - cached.capturedAtMs !in 0..CACHE_TTL_MILLIS
        ) {
            return null
        }
        return cached.snapshot + mapOf(
            "observedAtMs" to cached.capturedAtMs,
            "activeVariantId" to "",
            "fromCache" to true,
        )
    }

    private fun isCompletedSnapshot(
        snapshot: Map<String, Any?>,
        catalog: AndroidVariantProbeCatalog,
    ): Boolean {
        if (snapshot["errorCategory"] != null) {
            return false
        }
        val results = snapshot["results"] as? List<*> ?: return false
        return results.size == catalog.targets.size && results.all {
            val row = it as? Map<*, *> ?: return@all false
            row["id"] is String && row["status"] in setOf("available", "unavailable")
        }
    }

    private fun catalogKey(catalog: AndroidVariantProbeCatalog): String = buildString {
        append(catalog.groupTag)
        append('|')
        catalog.targets.forEach { target ->
            append(target.id)
            append('=')
            append(target.outboundTag)
            append(';')
        }
    }

    internal fun filterSnapshot(
        snapshot: Map<String, Any?>,
        requestedVariantId: String,
    ): Map<String, Any?> {
        if (requestedVariantId.isBlank()) {
            return snapshot
        }
        val results = (snapshot["results"] as? List<*>)
            .orEmpty()
            .filter { (it as? Map<*, *>)?.get("id") == requestedVariantId }
        return snapshot + ("results" to results)
    }

    internal fun hasFreshSamples(
        catalog: AndroidVariantProbeCatalog,
        current: AndroidCoreEgressProbeGroupSnapshot?,
        observedAtMs: Long,
    ): Boolean = current != null && catalog.targets.all { target ->
        val sample = current.items[target.outboundTag] ?: return@all false
        observedAtMs - sample.time in 0..SAMPLE_MAX_AGE_MILLIS
    }

    internal fun buildSnapshot(
        catalog: AndroidVariantProbeCatalog,
        groups: Map<String, AndroidCoreEgressProbeGroupSnapshot>,
        observedAtMs: Long,
    ): Map<String, Any?> {
        val probeGroup = groups[catalog.groupTag]
        val activeTag = AndroidCoreEgressProbe.resolveSelectedOutbound(
            groups = groups,
            rootGroupTag = catalog.finalGroupTag,
        )?.outboundTag.orEmpty()
        val activeVariantId = catalog.targets
            .firstOrNull { it.outboundTag == activeTag }
            ?.id
            .orEmpty()
        return mapOf(
            "observedAtMs" to observedAtMs,
            "activeVariantId" to activeVariantId,
            "results" to catalog.targets.map { target ->
                val sample = probeGroup?.items?.get(target.outboundTag)
                val healthy = sample != null &&
                    AndroidCoreEgressProbe.isHealthySample(sample.time, sample.delay)
                mapOf(
                    "id" to target.id,
                    "status" to when {
                        healthy -> "available"
                        sample != null -> "unavailable"
                        else -> "unknown"
                    },
                    "latencyMs" to if (healthy) sample?.delay else null,
                    "measuredAtMs" to if (sample != null && sample.time > 0L) {
                        sample.time
                    } else {
                        null
                    },
                    "errorCategory" to when {
                        healthy -> ""
                        sample != null -> "url_test_failed"
                        else -> "no_sample"
                    },
                )
            },
        )
    }

    private fun unavailableSnapshot(
        category: String,
        targets: List<AndroidVariantProbeTarget> = emptyList(),
    ): Map<String, Any?> = mapOf(
        "observedAtMs" to System.currentTimeMillis(),
        "activeVariantId" to "",
        "results" to targets.map { target ->
            mapOf(
                "id" to target.id,
                "status" to "unknown",
                "latencyMs" to null,
                "measuredAtMs" to null,
                "errorCategory" to category,
            )
        },
        "errorCategory" to category,
    )

    private class ProbeHandler(
        private val catalog: AndroidVariantProbeCatalog,
    ) : CommandClientHandler {
        private val lock = Any()
        private val initialLatch = CountDownLatch(1)
        private val resultLatch = CountDownLatch(1)
        private var armed = false
        private var groups = emptyMap<String, AndroidCoreEgressProbeGroupSnapshot>()

        fun awaitInitial(): Boolean =
            initialLatch.await(INITIAL_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun arm() {
            synchronized(lock) {
                armed = true
            }
        }

        fun awaitResult(): Boolean =
            resultLatch.await(RESULT_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)

        fun snapshot(): Map<String, Any?> = synchronized(lock) {
            buildSnapshot(
                catalog = catalog,
                groups = groups,
                observedAtMs = System.currentTimeMillis(),
            )
        }

        override fun writeGroups(iterator: OutboundGroupIterator) {
            val nextGroups = mutableMapOf<String, AndroidCoreEgressProbeGroupSnapshot>()
            while (iterator.hasNext()) {
                val group = iterator.next()
                val samples = mutableMapOf<String, AndroidCoreEgressProbeSample?>()
                val items = group.items
                while (items.hasNext()) {
                    val item = items.next()
                    samples[item.tag] = if (item.urlTestTime > 0L) {
                        AndroidCoreEgressProbeSample(
                            AndroidCoreEgressProbe.urlTestTimeMillis(item.urlTestTime),
                            item.urlTestDelay,
                        )
                    } else {
                        null
                    }
                }
                nextGroups[group.tag] = AndroidCoreEgressProbeGroupSnapshot(
                    selected = group.selected,
                    items = samples,
                )
            }
            synchronized(lock) {
                groups = nextGroups
                if (groups.containsKey(catalog.groupTag)) {
                    initialLatch.countDown()
                    if (
                        armed &&
                        hasFreshSamples(
                            catalog = catalog,
                            current = groups[catalog.groupTag],
                            observedAtMs = System.currentTimeMillis(),
                        )
                    ) {
                        resultLatch.countDown()
                    }
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

    private const val MAX_TARGETS = 12
    private const val INITIAL_TIMEOUT_MILLIS = 2_500L
    private const val RESULT_TIMEOUT_MILLIS = 16_500L
    private const val CACHE_TTL_MILLIS = 120_000L
    private const val SAMPLE_MAX_AGE_MILLIS = 120_000L
    private const val CAPTURE_CONNECT_ATTEMPTS = 3
    private const val CAPTURE_CONNECT_RETRY_MILLIS = 250L
    private const val LOG_TAG = "PokrovVariantProbe"
    private val SAFE_ID = Regex("[a-z0-9][a-z0-9._-]{0,63}")
}
