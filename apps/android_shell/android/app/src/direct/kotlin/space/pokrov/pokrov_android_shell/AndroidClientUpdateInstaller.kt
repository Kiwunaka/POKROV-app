package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest

internal object AndroidClientUpdateInstaller {
    const val STATUS_INSTALLER_OPENED = "installer_opened"
    const val STATUS_STORE_OPENED = "store_opened"
    const val STATUS_PERMISSION_REQUIRED = "permission_required"
    const val STATUS_FAILED = "failed"

    private const val MAX_REDIRECTS = 5
    private const val CONNECT_TIMEOUT_MS = 20_000
    private const val READ_TIMEOUT_MS = 45_000
    private const val AUTHORIZED_PRODUCTION_SIGNER_SHA256 =
        "0A0602A7DF5D96A0B427909D004F3DDF26DEF86587634BF16694DA8D654B2500"

    fun validateRequest(
        url: String?,
        sha256: String?,
        size: Number?,
        channel: String? = BuildConfig.POKROV_UPDATE_CHANNEL,
        version: String? = "1.0.8",
    ): AndroidClientUpdateRequest? = AndroidClientUpdateRequestPolicy.validate(
        url = url,
        sha256 = sha256,
        size = size,
        channel = channel,
        version = version,
        expectedChannel = BuildConfig.POKROV_UPDATE_CHANNEL,
    )

    internal fun isCanonicalReleaseUri(uri: URI): Boolean =
        AndroidClientUpdateRequestPolicy.isCanonicalReleaseUri(uri)

    internal fun isAllowedRedirectUri(uri: URI): Boolean =
        AndroidClientUpdateRequestPolicy.isAllowedRedirectUri(uri)

    fun downloadVerified(
        activity: Activity,
        request: AndroidClientUpdateRequest,
        onProgress: (AndroidClientUpdateProgress) -> Unit = {},
        shouldContinue: () -> Boolean = { true },
    ): AndroidVerifiedClientUpdate {
        AndroidClientUpdateFileVerifier.requireActive(shouldContinue)
        val updateDirectory = File(activity.cacheDir, "updates")
        check(updateDirectory.exists() || updateDirectory.mkdirs()) {
            "update_cache_unavailable"
        }
        val destination = File(
            updateDirectory,
            "pokrov-update-${request.sha256.take(16)}.apk",
        )
        if (destination.isFile) {
            onProgress(
                AndroidClientUpdateProgress(
                    phase = "verifying",
                    downloadedBytes = request.size,
                    totalBytes = request.size,
                ),
            )
            if (verifyUpdate(activity, destination, request, shouldContinue)) {
                return AndroidVerifiedClientUpdate(request, destination)
            }
        }
        destination.delete()
        val partial = File(updateDirectory, "${destination.name}.part")
        partial.delete()

        var current = URI(request.url)
        var redirects = 0
        while (true) {
            AndroidClientUpdateFileVerifier.requireActive(shouldContinue)
            val connection = current.toURL().openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = CONNECT_TIMEOUT_MS
                connection.readTimeout = READ_TIMEOUT_MS
                connection.setRequestProperty(
                    "Accept",
                    "application/vnd.android.package-archive, application/octet-stream",
                )
                connection.setRequestProperty("User-Agent", "POKROV-Android-Updater/2")
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
                onProgress(
                    AndroidClientUpdateProgress(
                        phase = "downloading",
                        downloadedBytes = 0L,
                        totalBytes = request.size,
                    ),
                )
                val digest = MessageDigest.getInstance("SHA-256")
                var written = 0L
                connection.inputStream.buffered().use { input ->
                    AndroidClientUpdateFileVerifier.writeAndSync(partial) { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            AndroidClientUpdateFileVerifier.requireActive(shouldContinue)
                            val count = input.read(buffer)
                            if (count < 0) {
                                break
                            }
                            written += count.toLong()
                            if (written > request.size ||
                                written > AndroidClientUpdateRequestPolicy.MAX_APK_BYTES
                            ) {
                                error("update_size_limit")
                            }
                            digest.update(buffer, 0, count)
                            output.write(buffer, 0, count)
                            onProgress(
                                AndroidClientUpdateProgress(
                                    phase = "downloading",
                                    downloadedBytes = written,
                                    totalBytes = request.size,
                                ),
                            )
                        }
                    }
                }
                onProgress(
                    AndroidClientUpdateProgress(
                        phase = "verifying",
                        downloadedBytes = written,
                        totalBytes = request.size,
                    ),
                )
                val actualSha = digest.digest().joinToString("") {
                    "%02x".format(it.toInt() and 0xff)
                }
                if (written != request.size || actualSha != request.sha256) {
                    error("update_integrity_failure")
                }
                AndroidClientUpdateFileVerifier.requireActive(shouldContinue)
                if (!verifyApkIdentity(activity, partial, request)) {
                    error("update_identity_rejected")
                }
                check(partial.renameTo(destination)) { "update_cache_commit_failed" }
                return AndroidVerifiedClientUpdate(request, destination)
            } catch (error: Throwable) {
                partial.delete()
                throw error
            } finally {
                connection.disconnect()
            }
        }
    }

    internal fun verifyFile(
        file: File,
        request: AndroidClientUpdateRequest,
        shouldContinue: () -> Boolean = { true },
    ): Boolean = AndroidClientUpdateFileVerifier.verify(file, request, shouldContinue)

    private fun verifyUpdate(
        activity: Activity,
        file: File,
        request: AndroidClientUpdateRequest,
        shouldContinue: () -> Boolean = { true },
    ): Boolean = verifyFile(file, request, shouldContinue) &&
        verifyApkIdentity(activity, file, request)

    fun canResumePendingInstall(activity: Activity): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    fun openInstaller(
        activity: Activity,
        update: AndroidVerifiedClientUpdate,
    ): String {
        val apk = update.apk ?: return STATUS_FAILED
        if (!verifyUpdate(activity, apk, update.request)) {
            return STATUS_FAILED
        }
        if (!canResumePendingInstall(activity)) {
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

    private fun verifyApkIdentity(
        activity: Activity,
        apk: File,
        request: AndroidClientUpdateRequest,
    ): Boolean {
        val identity = readApkIdentity(activity.packageManager, apk)
        if (identity == null) {
            recordIdentity(AndroidOperationalOutcome.REJECTED)
            return false
        }
        val installedIdentity = readInstalledIdentity(
            activity.packageManager,
            activity.packageName,
        )
        if (installedIdentity == null) {
            recordIdentity(AndroidOperationalOutcome.REJECTED)
            return false
        }
        val rejection = AndroidApkIdentityPolicy.rejection(
            identity = identity,
            request = request,
            expectedPackageName = BuildConfig.APPLICATION_ID,
            installedVersionCode = installedIdentity.versionCode,
            installedCurrentSignerSha256 = installedIdentity.currentSignerSha256,
            installedSigningLineageSha256 = installedIdentity.signingLineageSha256,
            deviceSdk = Build.VERSION.SDK_INT,
            deviceAbis = Build.SUPPORTED_ABIS.toSet(),
            authorizedSignerSha256 = setOf(AUTHORIZED_PRODUCTION_SIGNER_SHA256),
        )
        recordIdentity(
            if (rejection == null) {
                AndroidOperationalOutcome.VERIFIED
            } else {
                AndroidOperationalOutcome.REJECTED
            },
        )
        return rejection == null
    }

    private fun recordIdentity(outcome: AndroidOperationalOutcome) {
        AndroidOperationalJournal.recordRateLimited(
            AndroidOperationalEvent.UPDATER_IDENTITY,
            outcome,
        )
    }

    @Suppress("DEPRECATION")
    private fun readApkIdentity(
        packageManager: PackageManager,
        apk: File,
    ): AndroidApkIdentity? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || !apk.isFile) {
            return null
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val packageInfo = readArchivePackageInfo(packageManager, apk, flags) ?: return null
        val applicationInfo = packageInfo.applicationInfo ?: return null
        applicationInfo.sourceDir = apk.absolutePath
        applicationInfo.publicSourceDir = apk.absolutePath
        val currentSigners: Array<out Signature>
        val signingLineage: Array<out Signature>
        val hasMultipleSigners: Boolean
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo ?: return null
            currentSigners = signingInfo.apkContentsSigners.orEmpty()
            signingLineage = signingInfo.signingCertificateHistory.orEmpty()
            hasMultipleSigners = signingInfo.hasMultipleSigners()
        } else {
            currentSigners = packageInfo.signatures.orEmpty()
            signingLineage = emptyArray()
            hasMultipleSigners = currentSigners.size > 1
        }
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
        return AndroidApkIdentity(
            packageName = packageInfo.packageName.orEmpty(),
            versionName = packageInfo.versionName.orEmpty(),
            versionCode = versionCode,
            minimumSdk = applicationInfo.minSdkVersion,
            supportedAbis = AndroidApkArchiveAbis.read(apk),
            currentSignerSha256 = currentSigners.mapTo(mutableSetOf(), ::signatureSha256),
            signingLineageSha256 = signingLineage.mapTo(mutableSetOf(), ::signatureSha256),
            hasMultipleSigners = hasMultipleSigners,
        )
    }

    @Suppress("DEPRECATION")
    private fun readArchivePackageInfo(
        packageManager: PackageManager,
        apk: File,
        flags: Int,
    ): PackageInfo? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getPackageArchiveInfo(
            apk.absolutePath,
            PackageManager.PackageInfoFlags.of(flags.toLong()),
        )
    } else {
        packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
    }

    @Suppress("DEPRECATION")
    private fun readInstalledIdentity(
        packageManager: PackageManager,
        packageName: String,
    ): AndroidInstalledAppIdentity? = runCatching {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            packageManager.getPackageInfo(packageName, flags)
        }
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
        val currentSigners: Array<out Signature>
        val signingLineage: Array<out Signature>
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo ?: return@runCatching null
            currentSigners = signingInfo.apkContentsSigners.orEmpty()
            signingLineage = signingInfo.signingCertificateHistory.orEmpty()
        } else {
            currentSigners = packageInfo.signatures.orEmpty()
            signingLineage = emptyArray()
        }
        AndroidInstalledAppIdentity(
            versionCode = versionCode,
            currentSignerSha256 = currentSigners.mapTo(mutableSetOf(), ::signatureSha256),
            signingLineageSha256 = signingLineage.mapTo(mutableSetOf(), ::signatureSha256),
        )
    }.getOrNull()

    private fun signatureSha256(signature: Signature): String =
        MessageDigest.getInstance("SHA-256")
            .digest(signature.toByteArray())
            .joinToString("") { "%02X".format(it.toInt() and 0xff) }
}
