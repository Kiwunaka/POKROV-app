package space.pokrov.pokrov_android_shell

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import androidx.core.content.ContextCompat
import java.security.MessageDigest
import java.time.Instant
import java.time.Duration
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/** Bounded, process-local observations of requested catalog packages only. */
internal class AndroidCatalogIdentityResolver(context: Context) : AutoCloseable {
    private val context = context.applicationContext
    private val generation = AtomicLong(0)
    private val closed = AtomicBoolean(false)
    @Volatile private var cached: CachedScan? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            generation.incrementAndGet()
            cached = null
        }
    }

    init {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }
        ContextCompat.registerReceiver(this.context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    @Synchronized
    fun scan(digest: String, requested: List<String>, fresh: Boolean): Map<String, Any?> {
        if (closed.get() || !digest.matches(Regex("[0-9a-f]{64}")) ||
            requested.size > 256 || requested.toSet().size != requested.size ||
            requested.any { it.length > 255 || !it.matches(PACKAGE_NAME) }) return unavailable()
        val packages = requested.sorted()
        val observedGeneration = generation.get()
        cached?.takeIf { !fresh && it.digest == digest && it.packages == packages &&
            it.generation == observedGeneration }?.let { return it.result }
        val observations = packages.map { name ->
            if (Thread.currentThread().isInterrupted || closed.get()) return unavailable()
            observe(name)
        }
        if (generation.get() != observedGeneration || closed.get()) return unavailable("changed")
        val result = mapOf<String, Any?>(
            "schema" to 1, "status" to "ready", "catalog_digest" to digest,
            "generation" to observedGeneration, "packages" to observations,
        )
        cached = CachedScan(digest, packages, observedGeneration, result)
        return result
    }

    @Suppress("DEPRECATION")
    private fun observe(name: String): Map<String, Any?> {
        fun missing(state: String) = mapOf<String, Any?>("package" to name, "state" to state)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return missing("unsupported")
        return try {
            val manager = context.packageManager
            val info = manager.getPackageInfo(name, PackageManager.GET_SIGNING_CERTIFICATES)
            val app = info.applicationInfo ?: return missing("unavailable")
            if (!app.enabled) return missing("unavailable")
            val signing = info.signingInfo ?: return missing("unavailable")
            val multiple = signing.hasMultipleSigners()
            val history = if (multiple) emptyList() else
                signing.signingCertificateHistory?.map { sha256(it.toByteArray()) }.orEmpty()
            val signers = if (multiple) signing.apkContentsSigners
                ?.map { sha256(it.toByteArray()) }.orEmpty().sorted()
                else history.takeLast(1)
            if (signers.isEmpty() || signers.size > 8 || history.size > 16) return missing("unsupported")
            val browser = manager.queryIntentActivities(Intent(Intent.ACTION_VIEW,
                Uri.parse("https://example.invalid/")).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                setPackage(name)
            }, 0).isNotEmpty()
            val uidPackages = manager.getPackagesForUid(app.uid)
            // Package visibility can hide a peer from the UID lookup. A
            // declared sharedUserId is enough to keep this app manual-only.
            val sharedUid = !info.sharedUserId.isNullOrBlank() ||
                uidPackages == null || uidPackages.toSet() != setOf(name)
            mapOf(
                "package" to name, "state" to "visible", "signers" to signers,
                "lineage" to history, "multiple_signers" to multiple,
                "browser" to browser, "shared_uid" to sharedUid,
            )
        } catch (_: PackageManager.NameNotFoundException) {
            // Visibility filtering is indistinguishable from absence here.
            missing("unavailable")
        } catch (_: SecurityException) {
            missing("unavailable")
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        generation.incrementAndGet()
        cached = null
        context.unregisterReceiver(receiver)
    }

    private data class CachedScan(val digest: String, val packages: List<String>,
        val generation: Long, val result: Map<String, Any?>)

    companion object {
        private val PACKAGE_NAME = Regex("[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)+")
        fun unavailable(status: String = "unavailable"): Map<String, Any?> =
            mapOf("schema" to 1, "status" to status)
        private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
            .digest(bytes).joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }
}

/** Exact local signer scope for one catalog-backed staged profile. Never persisted. */
internal class AndroidCatalogAppBinding private constructor(
    val profileDigest: String,
    private val catalogDigest: String,
    private val expiresAt: Instant,
    private val signers: Map<String, List<String>>,
    private val lineages: Map<String, List<String>>,
) {
    private val invalidated = AtomicBoolean(false)
    private val elapsedDeadline = SystemClock.elapsedRealtime() +
        Duration.between(Instant.now(), expiresAt).toMillis().coerceAtLeast(0)

    fun affectsPackage(name: String): Boolean = signers.containsKey(name)
    fun invalidate(): Boolean = invalidated.compareAndSet(false, true)
    fun remainingMillis(): Long = minOf(
        Duration.between(Instant.now(), expiresAt).toMillis(),
        elapsedDeadline - SystemClock.elapsedRealtime(),
    ).coerceAtLeast(0)
    fun isValid(): Boolean = !invalidated.get() && remainingMillis() > 0

    fun verifies(context: Context, packages: Set<String>): Boolean {
        if (packages != signers.keys || !isValid()) return false
        val result = AndroidCatalogIdentityResolver(context).use { resolver ->
            resolver.scan(catalogDigest, packages.toList(), fresh = true)
        }
        if (result["status"] != "ready" || result["catalog_digest"] != catalogDigest) return false
        val rows = result["packages"] as? List<*> ?: return false
        if (rows.size != packages.size) return false
        val seen = mutableSetOf<String>()
        for (row in rows) {
            val observed = row as? Map<*, *> ?: return false
            val name = observed["package"] as? String ?: return false
            if (!seen.add(name)) return false
            val expected = signers[name] ?: return false
            val expectedLineage = lineages[name] ?: return false
            val current = observed["signers"] as? List<*> ?: return false
            val currentLineage = observed["lineage"] as? List<*> ?: return false
            if (observed["state"] != "visible" || observed["browser"] != false ||
                observed["shared_uid"] != false || observed["multiple_signers"] != (expected.size > 1) ||
                current.size != expected.size || current.toSet() != expected.toSet() ||
                currentLineage != expectedLineage) return false
        }
        return seen == packages && isValid()
    }

    companion object {
        private val DIGEST = Regex("[a-f0-9]{64}")
        private val PACKAGE = Regex("[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)+")
        @Volatile private var staged: AndroidCatalogAppBinding? = null

        fun clear() { staged = null }
        fun publish(binding: AndroidCatalogAppBinding?) { staged = binding }
        fun forProfile(digest: String): AndroidCatalogAppBinding? = staged?.takeIf { it.profileDigest == digest }

        fun fromStage(profileDigest: String, catalogDigest: Any?, expiry: Any?, raw: Any?,
                      rawLineages: Any?, routeMode: String): AndroidCatalogAppBinding? {
            if (catalogDigest == null && expiry == null && raw == null && rawLineages == null) return null
            require(routeMode == "selectedApps" || routeMode == "excludedApps") { "catalog_app_scope_invalid" }
            require(profileDigest.matches(DIGEST) && catalogDigest is String && catalogDigest.matches(DIGEST) &&
                expiry is String && raw is Map<*, *> && raw.isNotEmpty() && raw.size <= 128 &&
                rawLineages is Map<*, *> && raw.keys == rawLineages.keys) { "catalog_app_scope_invalid" }
            val expiresAt = try { Instant.parse(expiry) } catch (_: Exception) { throw IllegalArgumentException("catalog_app_scope_invalid") }
            require(Instant.now().isBefore(expiresAt)) { "catalog_app_scope_expired" }
            val signers = mutableMapOf<String, List<String>>()
            val lineages = mutableMapOf<String, List<String>>()
            for ((key, value) in raw) {
                val lineage = rawLineages[key]
                require(key is String && key.matches(PACKAGE) && value is List<*> &&
                    value.isNotEmpty() && value.size <= 8 && value.all { it is String && it.matches(DIGEST) } &&
                    value.toSet().size == value.size && lineage is List<*> && lineage.size <= 16 &&
                    lineage.all { it is String && it.matches(DIGEST) } && lineage.toSet().size == lineage.size &&
                    (if (value.size == 1) lineage.isNotEmpty() && lineage.last() == value.single()
                     else lineage.isEmpty())) { "catalog_app_scope_invalid" }
                signers[key] = value.filterIsInstance<String>().toList()
                lineages[key] = lineage.filterIsInstance<String>().toList()
            }
            return AndroidCatalogAppBinding(profileDigest, catalogDigest, expiresAt,
                signers.toMap(), lineages.toMap())
        }
    }
}
