package space.pokrov.pokrov_android_shell

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import androidx.core.content.ContextCompat

internal data class AndroidForegroundConnectContext(val networkRef: String, val stopEpoch: Long)

/** Process-local stop fence; explicit stop suppresses the current physical uplink. */
internal class AndroidForegroundStopPolicy {
    @Volatile var epoch: Long = 0
        private set
    private var captureStopKey = false
    private var stoppedKey: String? = null

    @Synchronized fun explicitStop() {
        epoch += 1
        captureStopKey = true
        stoppedKey = null
    }

    @Synchronized fun capture(key: String?): Pair<Long, Boolean> {
        if (captureStopKey && !key.isNullOrBlank()) {
            stoppedKey = key
            captureStopKey = false
        } else if (stoppedKey != null && !key.isNullOrBlank() && stoppedKey != key) {
            stoppedKey = null
        }
        return epoch to (captureStopKey || (stoppedKey != null && stoppedKey == key))
    }
}

internal object AndroidForegroundNetworkEligibility {
    private val stops = AndroidForegroundStopPolicy()
    val stopEpoch: Long get() = stops.epoch
    fun explicitStop() = stops.explicitStop()

    fun eligible(foreground: Boolean, vpnAuthorized: Boolean, notificationsAuthorized: Boolean,
        wifiConnected: Boolean, ssidKnown: Boolean, wifiPermissionRequired: Boolean,
        networkAvailable: Boolean?, captivePortal: Boolean?, suppressed: Boolean): Boolean =
        foreground && vpnAuthorized && notificationsAuthorized && wifiConnected && ssidKnown &&
            !wifiPermissionRequired && networkAvailable == true && captivePortal == false && !suppressed

    /** VpnService.prepare is inspected only; no permission activity is launched. */
    fun read(activity: Activity, network: AndroidTransportNetworkContext.CandidateNetwork,
        wifi: Map<String, Any?>): Map<String, Any?> {
        val channel = network.channelValue()
        val key = channel["selection_key"] as? String
        val foreground = !activity.isFinishing && !activity.isDestroyed && activity.hasWindowFocus()
        val vpnAuthorized = VpnService.prepare(activity) == null
        val notificationsAuthorized = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val (epoch, suppressed) = stops.capture(key)
        return mapOf(
            "foreground" to foreground,
            "vpnAuthorized" to vpnAuthorized,
            "notificationsAuthorized" to notificationsAuthorized,
            "networkContextRef" to network.contextRef,
            "networkSelectionKey" to key,
            "manualStopEpoch" to epoch,
            "manualStopSuppressed" to suppressed,
            "autoConnectEligible" to eligible(foreground, vpnAuthorized, notificationsAuthorized,
                wifi["connected"] == true, !(wifi["name"] as? String).isNullOrBlank(),
                wifi["permissionRequired"] == true, network.networkAvailable, network.captivePortal, suppressed),
        )
    }
}
