package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest

internal data class AndroidClientUpdateRequest(
    val url: String,
    val sha256: String,
    val size: Long,
)

internal object AndroidClientUpdateInstaller {
    const val STATUS_INSTALLER_OPENED = "installer_opened"
    const val STATUS_PERMISSION_REQUIRED = "permission_required"
    const val STATUS_FAILED = "failed"

    private const val MAX_APK_BYTES = 256L * 1024L * 1024L
    private const val MAX_REDIRECTS = 5
    private const val CONNECT_TIMEOUT_MS = 20_000
    private const val READ_TIMEOUT_MS = 45_000
    private val sha256Pattern = Regex("^[a-f0-9]{64}$")
    private val canonicalPath = Regex(
        "^/Kiwunaka/pokrov/releases/download/[^/]+/[^/]+\\.apk$",
        RegexOption.IGNORE_CASE,
    )

    fun validateRequest(url: String?, sha256: String?, size: Number?): AndroidClientUpdateRequest? {
        val normalizedUrl = url?.trim().orEmpty()
        val normalizedSha = sha256?.trim()?.lowercase().orEmpty()
        val normalizedSize = size?.toLong() ?: 0L
        if (!sha256Pattern.matches(normalizedSha) ||
            normalizedSize <= 0L ||
            normalizedSize > MAX_APK_BYTES
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
        )
    }

    internal fun isCanonicalReleaseUri(uri: URI): Boolean =
        uri.scheme.equals("https", ignoreCase = true) &&
            uri.host.equals("github.com", ignoreCase = true) &&
            uri.userInfo == null &&
            uri.port == -1 &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            canonicalPath.matches(uri.path.orEmpty())

    internal fun isAllowedRedirectUri(uri: URI): Boolean {
        val host = uri.host?.lowercase().orEmpty()
        val allowedHost = host == "github.com" || host.endsWith(".githubusercontent.com")
        return uri.scheme.equals("https", ignoreCase = true) &&
            allowedHost &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawFragment == null
    }

    fun downloadVerified(activity: Activity, request: AndroidClientUpdateRequest): File {
        val updateDirectory = File(activity.cacheDir, "updates")
        check(updateDirectory.exists() || updateDirectory.mkdirs()) {
            "update_cache_unavailable"
        }
        val destination = File(
            updateDirectory,
            "pokrov-update-${request.sha256.take(16)}.apk",
        )
        if (destination.isFile && verifyFile(destination, request)) {
            return destination
        }
        destination.delete()
        val partial = File(updateDirectory, "${destination.name}.part")
        partial.delete()

        var current = URI(request.url)
        var redirects = 0
        while (true) {
            val connection = current.toURL().openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = CONNECT_TIMEOUT_MS
                connection.readTimeout = READ_TIMEOUT_MS
                connection.setRequestProperty("Accept", "application/vnd.android.package-archive, application/octet-stream")
                connection.setRequestProperty("User-Agent", "POKROV-Android-Updater/1")
                val status = connection.responseCode
                if (status in setOf(301, 302, 303, 307, 308)) {
                    if (++redirects > MAX_REDIRECTS) {
                        error("update_redirect_limit")
                    }
                    val location = connection.getHeaderField("Location")?.trim().orEmpty()
                    val next = runCatching { current.resolve(location) }.getOrNull()
                        ?: error("update_redirect_invalid")
                    if (!isAllowedRedirectUri(next)) {
                        error("update_redirect_rejected")
                    }
                    current = next
                    continue
                }
                if (status !in 200..299) {
                    error("update_http_failure")
                }
                val contentLength = connection.contentLengthLong
                if (contentLength > 0L && contentLength != request.size) {
                    error("update_size_mismatch")
                }
                val digest = MessageDigest.getInstance("SHA-256")
                var written = 0L
                connection.inputStream.buffered().use { input ->
                    FileOutputStream(partial).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) {
                                break
                            }
                            written += count.toLong()
                            if (written > request.size || written > MAX_APK_BYTES) {
                                error("update_size_limit")
                            }
                            digest.update(buffer, 0, count)
                            output.write(buffer, 0, count)
                        }
                        output.fd.sync()
                    }
                }
                val actualSha = digest.digest().joinToString("") {
                    "%02x".format(it.toInt() and 0xff)
                }
                if (written != request.size || actualSha != request.sha256) {
                    error("update_integrity_failure")
                }
                check(partial.renameTo(destination)) { "update_cache_commit_failed" }
                return destination
            } catch (error: Throwable) {
                partial.delete()
                throw error
            } finally {
                connection.disconnect()
            }
        }
    }

    internal fun verifyFile(file: File, request: AndroidClientUpdateRequest): Boolean {
        if (!file.isFile || file.length() != request.size) {
            return false
        }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
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

    fun openInstaller(activity: Activity, apk: File): String {
        if (!apk.isFile) {
            return STATUS_FAILED
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
        ) {
            return runCatching {
                activity.startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        android.net.Uri.parse("package:${activity.packageName}"),
                    ),
                )
                STATUS_PERMISSION_REQUIRED
            }.getOrDefault(STATUS_FAILED)
        }
        return runCatching {
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.updates",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val installer = activity.packageManager
                .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                .asSequence()
                .filter { candidate ->
                    val flags = candidate.activityInfo.applicationInfo.flags
                    flags and ApplicationInfo.FLAG_SYSTEM != 0 ||
                        flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0
                }
                .sortedBy { candidate ->
                    when (candidate.activityInfo.packageName) {
                        "com.google.android.packageinstaller" -> 0
                        "com.android.packageinstaller" -> 1
                        "com.android.permissioncontroller" -> 2
                        else -> 3
                    }
                }
                .firstOrNull()
                ?: return STATUS_FAILED
            intent.component = ComponentName(
                installer.activityInfo.packageName,
                installer.activityInfo.name,
            )
            activity.startActivity(intent)
            STATUS_INSTALLER_OPENED
        }.getOrDefault(STATUS_FAILED)
    }
}
