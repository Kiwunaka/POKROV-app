package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.content.Intent
import android.net.Uri
import java.io.File
import java.net.URI

internal object AndroidClientUpdateInstaller {
    const val STATUS_INSTALLER_OPENED = "installer_opened"
    const val STATUS_STORE_OPENED = "store_opened"
    const val STATUS_PERMISSION_REQUIRED = "permission_required"
    const val STATUS_FAILED = "failed"

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
        onProgress(
            AndroidClientUpdateProgress(
                phase = "installing",
                downloadedBytes = 0L,
                totalBytes = request.size,
            ),
        )
        return AndroidVerifiedClientUpdate(request = request, apk = null)
    }

    internal fun verifyFile(
        file: File,
        request: AndroidClientUpdateRequest,
        shouldContinue: () -> Boolean = { true },
    ): Boolean = AndroidClientUpdateFileVerifier.verify(file, request, shouldContinue)

    fun canResumePendingInstall(activity: Activity): Boolean = false

    fun openInstaller(
        activity: Activity,
        update: AndroidVerifiedClientUpdate,
    ): String = runCatching {
        AndroidClientUpdateFileVerifier.requireActive { true }
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=${BuildConfig.APPLICATION_ID}"),
        ).apply {
            setPackage("com.android.vending")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
        STATUS_STORE_OPENED
    }.getOrDefault(STATUS_FAILED)
}
