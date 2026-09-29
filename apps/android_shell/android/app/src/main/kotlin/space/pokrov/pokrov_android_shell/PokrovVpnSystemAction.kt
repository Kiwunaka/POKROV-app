package space.pokrov.pokrov_android_shell

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File

internal enum class SystemVpnState {
    OFF,
    CONNECTING,
    DISCONNECTING,
    CONNECTED,
    PROTECTED,
}

internal fun resolveSystemVpnState(
    tunEstablished: Boolean,
    serviceRunning: Boolean,
    connectionPending: Boolean,
    transportProofPending: Boolean,
    coreEgressVerified: Boolean?,
    transportLeaseActive: Boolean,
    stopPending: Boolean = false,
): SystemVpnState = when {
    stopPending -> SystemVpnState.DISCONNECTING
    connectionPending || transportProofPending -> SystemVpnState.CONNECTING
    tunEstablished && (coreEgressVerified == true ||
        coreEgressVerified == null && transportLeaseActive) -> SystemVpnState.CONNECTED
    tunEstablished -> SystemVpnState.PROTECTED
    serviceRunning -> SystemVpnState.CONNECTING
    else -> SystemVpnState.OFF
}

internal data class SystemVpnControl(
    val state: SystemVpnState,
    val action: QuickTileAction,
    val profile: PersistedRuntimeProfile?,
)

/** Tile and widget use the same private profile checks and the same VPN service. */
internal object PokrovVpnSystemAction {
    private val transitionHandler = Handler(Looper.getMainLooper())

    fun read(context: Context): SystemVpnControl {
        val profile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(context)
        val snapshot = AndroidRuntimeState.snapshot()
        val tunEstablished = PokrovRuntimeVpnService.isTunEstablished()
        val serviceRunning = isRuntimeServiceRunning(context)
        val connectionPending = snapshot["connection_pending"] == true
        val transportProofPending = snapshot["transportProofPending"] == true
        val validProfile = profile?.takeIf {
            it.configPath == snapshot["stagedConfigPath"] &&
                File(it.configPath).isFile && File(it.configPath).length() > 0L
        }
        return SystemVpnControl(
            state = resolveSystemVpnState(
                tunEstablished = tunEstablished,
                serviceRunning = serviceRunning,
                connectionPending = connectionPending,
                transportProofPending = transportProofPending,
                coreEgressVerified = snapshot["core_egress_validated"] as? Boolean,
                transportLeaseActive = snapshot["transportLeaseActive"] == true,
                stopPending = QuickTileTransitionGate.isStopping(),
            ),
            action = resolveQuickTileAction(
                isRunning = tunEstablished || serviceRunning,
                connectionPending = connectionPending || transportProofPending,
                hasStagedProfile = validProfile != null,
                quickSettingsEligible = validProfile?.canStartFromQuickSettings() == true &&
                    !AndroidConnectRequestOwner.blocksStart(null),
                vpnPermissionRequired = VpnService.prepare(context) != null,
                notificationPermissionRequestRequired =
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                        android.content.pm.PackageManager.PERMISSION_GRANTED &&
                        !AndroidNotificationPermissionStore.wasAsked(context),
            ),
            profile = validProfile,
        )
    }

    fun toggle(context: Context, stopReason: String): QuickTileAction {
        // Re-read on click: a RemoteViews action may outlive its profile/permissions.
        val control = read(context)
        if (control.action == QuickTileAction.OPEN_APP) return control.action
        val generation = QuickTileTransitionGate.begin(control.action) ?: return control.action
        transitionHandler.postDelayed({ QuickTileTransitionGate.expire(generation) }, 3_000L)
        try {
            when (control.action) {
                QuickTileAction.STOP -> {
                    AndroidConnectRequestOwner.invalidate()
                    AndroidRuntimeState.markStopRequested(stopReason = stopReason)
                    PokrovRuntimeVpnService.stop(context, generation)
                }
                QuickTileAction.START -> {
                    val profile = requireNotNull(control.profile)
                    AndroidRuntimeState.markConnectionPending()
                    PokrovRuntimeVpnService.start(
                        context, profile.configPath, profile.routeMode, profile.configDigest, generation,
                    )
                }
                QuickTileAction.OPEN_APP -> Unit
            }
        } catch (_: Exception) {
            val failure = if (control.action == QuickTileAction.START) "runtime_start_failed" else "runtime_stop_failed"
            AndroidRuntimeState.markFailure(failure, AndroidRuntimeSafety.publicFailureMessage(failure))
            QuickTileTransitionGate.complete(generation)
        }
        PokrovQuickSettingsTileService.requestRefresh(context)
        return control.action
    }

    fun appIntent(context: Context): Intent = Intent(context, MainActivity::class.java).apply {
        action = Intent.ACTION_VIEW
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    @Suppress("DEPRECATION")
    private fun isRuntimeServiceRunning(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.getRunningServices(Int.MAX_VALUE).any {
            it.service.className == PokrovRuntimeVpnService::class.java.name
        }
    }
}
