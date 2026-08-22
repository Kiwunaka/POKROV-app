package space.pokrov.pokrov_android_shell

import java.io.File
import java.io.FileOutputStream
import java.net.URI
import java.security.MessageDigest
import java.util.zip.ZipFile

internal data class AndroidClientUpdateRequest(
    val url: String,
    val sha256: String,
    val size: Long,
    val channel: String = "stable",
    val version: String = "1.0.8",
)

internal data class AndroidClientUpdateProgress(
    val phase: String,
    val downloadedBytes: Long,
    val totalBytes: Long,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "phase" to phase,
        "downloaded_bytes" to downloadedBytes.coerceAtLeast(0L),
        "total_bytes" to totalBytes.coerceAtLeast(0L),
    )

    companion object {
        fun idle(): AndroidClientUpdateProgress = AndroidClientUpdateProgress(
            phase = "idle",
            downloadedBytes = 0L,
            totalBytes = 0L,
        )
    }
}

internal data class AndroidVerifiedClientUpdate(
    val request: AndroidClientUpdateRequest,
    val apk: File?,
)

internal object AndroidClientUpdateRequestPolicy {
    const val MAX_APK_BYTES = 256L * 1024L * 1024L
    private const val MAX_URL_LENGTH = 2_048
    private const val MAX_VERSION_LENGTH = 64
    private val sha256Pattern = Regex("^[a-f0-9]{64}$")
    private val versionPattern = Regex(
        "^[0-9]+\\.[0-9]+\\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$",
    )
    private val canonicalPath = Regex(
        "^/Kiwunaka/pokrov/releases/download/[^/]+/[^/]+\\.apk$",
        RegexOption.IGNORE_CASE,
    )

    fun validate(
        url: String?,
        sha256: String?,
        size: Number?,
        channel: String?,
        version: String?,
        expectedChannel: String,
    ): AndroidClientUpdateRequest? {
        val normalizedUrl = url?.trim().orEmpty()
        val normalizedSha = sha256?.trim()?.lowercase().orEmpty()
        val normalizedSize = size?.toLong() ?: 0L
        val normalizedChannel = channel?.trim()?.lowercase().orEmpty()
        val normalizedVersion = version?.trim().orEmpty()
        if (!sha256Pattern.matches(normalizedSha) ||
            normalizedSize <= 0L ||
            normalizedSize > MAX_APK_BYTES ||
            normalizedUrl.length > MAX_URL_LENGTH ||
            normalizedChannel != expectedChannel ||
            normalizedVersion.length > MAX_VERSION_LENGTH ||
            !versionPattern.matches(normalizedVersion)
        ) {
            return null
        }
        val uri = runCatching { URI(normalizedUrl) }.getOrNull() ?: return null
        if (!isCanonicalReleaseUri(uri)) {
            return null
        }
        return AndroidClientUpdateRequest(
            url = uri.toASCIIString(),
            sha256 = normalizedSha,
            size = normalizedSize,
            channel = normalizedChannel,
            version = normalizedVersion,
        )
    }

    fun isCanonicalReleaseUri(uri: URI): Boolean =
        uri.scheme.equals("https", ignoreCase = true) &&
            uri.host.equals("github.com", ignoreCase = true) &&
            uri.userInfo == null &&
            uri.port == -1 &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            canonicalPath.matches(uri.path.orEmpty())

    fun isAllowedRedirectUri(uri: URI): Boolean {
        val host = uri.host?.lowercase().orEmpty()
        val allowedHost = host == "github.com" || host.endsWith(".githubusercontent.com")
        return uri.scheme.equals("https", ignoreCase = true) &&
            allowedHost &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawFragment == null
    }
}

internal object AndroidClientUpdateFileVerifier {
    fun verify(
        file: File,
        request: AndroidClientUpdateRequest,
        shouldContinue: () -> Boolean = { true },
    ): Boolean {
        if (!file.isFile || file.length() != request.size) {
            return false
        }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                requireActive(shouldContinue)
                val count = input.read(buffer)
                if (count < 0) {
                    break
                }
                digest.update(buffer, 0, count)
            }
        }
        val actualSha = digest.digest().joinToString("") {
            "%02x".format(it.toInt() and 0xff)
        }
        return actualSha == request.sha256
    }

    fun requireActive(shouldContinue: () -> Boolean) {
        check(shouldContinue() && !Thread.currentThread().isInterrupted) {
            "update_cancelled"
        }
    }

    fun writeAndSync(file: File, write: (FileOutputStream) -> Unit) {
        FileOutputStream(file).use { output ->
            write(output)
            output.fd.sync()
        }
    }
}

internal data class AndroidApkIdentity(
    val packageName: String,
    val versionName: String,
    val versionCode: Long,
    val minimumSdk: Int,
    val supportedAbis: Set<String>,
    val currentSignerSha256: Set<String>,
    val signingLineageSha256: Set<String>,
    val hasMultipleSigners: Boolean,
)

internal data class AndroidInstalledAppIdentity(
    val versionCode: Long,
    val currentSignerSha256: Set<String>,
    val signingLineageSha256: Set<String>,
)

internal object AndroidApkIdentityPolicy {
    const val PACKAGE_MISMATCH = "update_package_mismatch"
    const val VERSION_MISMATCH = "update_version_mismatch"
    const val DOWNGRADE = "update_downgrade"
    const val SDK_INCOMPATIBLE = "update_sdk_incompatible"
    const val ABI_INCOMPATIBLE = "update_abi_incompatible"
    const val SIGNER_MISMATCH = "update_signer_mismatch"

    fun rejection(
        identity: AndroidApkIdentity,
        request: AndroidClientUpdateRequest,
        expectedPackageName: String,
        installedVersionCode: Long,
        installedCurrentSignerSha256: Set<String>,
        installedSigningLineageSha256: Set<String>,
        deviceSdk: Int,
        deviceAbis: Set<String>,
        authorizedSignerSha256: Set<String>,
    ): String? {
        if (identity.packageName != expectedPackageName) {
            return PACKAGE_MISMATCH
        }
        if (identity.versionName != request.version) {
            return VERSION_MISMATCH
        }
        if (identity.versionCode <= installedVersionCode) {
            return DOWNGRADE
        }
        if (identity.minimumSdk <= 0 || identity.minimumSdk > deviceSdk) {
            return SDK_INCOMPATIBLE
        }
        val normalizedDeviceAbis = deviceAbis.mapTo(mutableSetOf()) { it.lowercase() }
        val normalizedApkAbis = identity.supportedAbis.mapTo(mutableSetOf()) { it.lowercase() }
        if (normalizedApkAbis.isEmpty() || normalizedApkAbis.intersect(normalizedDeviceAbis).isEmpty()) {
            return ABI_INCOMPATIBLE
        }
        val authorized = authorizedSignerSha256.mapTo(mutableSetOf(), ::normalizeSha256)
        val current = identity.currentSignerSha256.mapTo(mutableSetOf(), ::normalizeSha256)
        val lineage = identity.signingLineageSha256.mapTo(mutableSetOf(), ::normalizeSha256)
        val installedCurrent = installedCurrentSignerSha256
            .mapTo(mutableSetOf(), ::normalizeSha256)
        val installedLineage = installedSigningLineageSha256
            .mapTo(mutableSetOf(), ::normalizeSha256)
        val targetSignerAccepted = if (identity.hasMultipleSigners) {
            current.isNotEmpty() && current.all(authorized::contains)
        } else {
            current.size == 1 && (current + lineage).any(authorized::contains)
        }
        val installedSignerAccepted = installedCurrent.isNotEmpty() &&
            (installedCurrent + installedLineage).any(authorized::contains)
        val continuityAccepted = (current + lineage).intersect(installedCurrent).isNotEmpty()
        return if (targetSignerAccepted && installedSignerAccepted && continuityAccepted) {
            null
        } else {
            SIGNER_MISMATCH
        }
    }

    private fun normalizeSha256(value: String): String =
        value.replace(":", "").trim().uppercase()
}

internal object AndroidApkArchiveAbis {
    private val nativeLibraryPath = Regex("^lib/([^/]+)/[^/]+\\.so$")
    private const val MAX_ARCHIVE_ENTRIES = 16_384

    fun read(apk: File): Set<String> = runCatching {
        ZipFile(apk).use { archive ->
            val result = linkedSetOf<String>()
            val entries = archive.entries()
            var inspected = 0
            while (entries.hasMoreElements()) {
                if (++inspected > MAX_ARCHIVE_ENTRIES) {
                    error("update_apk_entry_limit")
                }
                val entry = entries.nextElement()
                nativeLibraryPath.matchEntire(entry.name)?.groupValues?.get(1)?.let(result::add)
            }
            result
        }
    }.getOrDefault(emptySet())
}
