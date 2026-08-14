package space.pokrov.pokrov_android_shell

import android.app.ActivityManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.graphics.drawable.Icon
import java.io.File

internal enum class QuickTileAction {
    START,
    STOP,
    OPEN_APP,
}

internal fun resolveQuickTileAction(
    isRunning: Boolean,
    connectionPending: Boolean = false,
    hasStagedProfile: Boolean,
    quickSettingsEligible: Boolean = false,
    vpnPermissionRequired: Boolean,
    notificationPermissionRequestRequired: Boolean = false,
): QuickTileAction = when {
    isRunning || connectionPending -> QuickTileAction.STOP
    !hasStagedProfile || !quickSettingsEligible || vpnPermissionRequired ||
        notificationPermissionRequestRequired -> QuickTileAction.OPEN_APP
    else -> QuickTileAction.START
}

/** Serializes a tile transition and lets a pending START be superseded by STOP. */
internal object QuickTileTransitionGate {
    private var nextGeneration = 0L
    private var activeGeneration: Long? = null
    private var activeAction: QuickTileAction? = null

    @Synchronized
    fun begin(action: QuickTileAction): Long? {
        val currentAction = activeAction
        if (currentAction != null && !(currentAction == QuickTileAction.START && action == QuickTileAction.STOP)) {
            return null
        }
        nextGeneration += 1
        activeGeneration = nextGeneration
        activeAction = action
        return nextGeneration
    }

    @Synchronized
    fun complete(generation: Long?) {
        if (generation == null || generation == activeGeneration) {
            activeGeneration = null
            activeAction = null
        }
    }

    @Synchronized
    fun expire(generation: Long) {
        if (generation == activeGeneration) {
            activeGeneration = null
            activeAction = null
        }
    }

    @Synchronized
    fun resetForTest() {
        nextGeneration = 0L
        activeGeneration = null
        activeAction = null
    }
}

class PokrovQuickSettingsTileService : TileService() {
    private val transitionHandler = Handler(Looper.getMainLooper())

    override fun onTileAdded() {
        super.onTileAdded()
        // Let SystemUI finish registering the tile token before updateTile().
        transitionHandler.post(::refreshTile)
    }

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        val profile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(this)
        val snapshot = authoritativeRuntimeSnapshot()
        val runtimeServiceRunning = isRuntimeServiceRunning()
        val validProfile = profile?.takeIf {
            it.configPath == snapshot.stagedConfigPath &&
                File(it.configPath).isFile &&
                File(it.configPath).length() > 0L
        }
        val permissionRequired = !snapshot.isRunning && VpnService.prepare(this) != null
        val notificationPermissionRequestRequired =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED &&
                !AndroidNotificationPermissionStore.wasAsked(this)
        when (
            resolveQuickTileAction(
                isRunning = snapshot.isRunning || runtimeServiceRunning,
                connectionPending = snapshot.connectionPending,
                hasStagedProfile = validProfile != null,
                quickSettingsEligible = validProfile?.canStartFromQuickSettings() == true,
                vpnPermissionRequired = permissionRequired,
                notificationPermissionRequestRequired = notificationPermissionRequestRequired,
            )
        ) {
            QuickTileAction.STOP -> beginTransition(QuickTileAction.STOP)?.let { generation ->
                AndroidRuntimeState.markStopRequested(stopReason = "quick_settings")
                PokrovRuntimeVpnService.stop(this, generation)
            }
            QuickTileAction.START -> beginTransition(QuickTileAction.START)?.let { generation ->
                AndroidRuntimeState.markConnectionPending()
                PokrovRuntimeVpnService.start(
                    this,
                    requireNotNull(validProfile).configPath,
                    requireNotNull(validProfile).routeMode,
                    generation,
                )
            }
            QuickTileAction.OPEN_APP -> openAppForConnection()
        }
        refreshTile()
    }

    private fun openAppForConnection() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                14072,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val running = authoritativeRuntimeSnapshot().isRunning || isRuntimeServiceRunning()
        tile.icon = Icon.createWithResource(this, R.drawable.ic_pokrov_system)
        tile.label = "POKROV"
        tile.state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.contentDescription = if (running) {
            "POKROV включен. Нажмите, чтобы отключить VPN."
        } else {
            "POKROV выключен. Нажмите, чтобы включить VPN."
        }
        setTileSubtitle(tile, if (running) "Включен" else "Выключен")
        tile.updateTile()
    }

    @Suppress("DEPRECATION")
    private fun isRuntimeServiceRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.getRunningServices(Int.MAX_VALUE).any {
            it.service.className == PokrovRuntimeVpnService::class.java.name
        }
    }

    private fun setTileSubtitle(tile: Tile, value: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = value
        }
    }

    private fun authoritativeRuntimeSnapshot(): QuickTileRuntimeSnapshot {
        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = PokrovRuntimeVpnService.isTunEstablished(),
            runningMessage = PokrovRuntimeVpnService.latestRuntimeMessage(),
        )
        val state = AndroidRuntimeState.snapshot()
        return QuickTileRuntimeSnapshot(
            phase = state["phase"] as? String,
            stagedConfigPath = state["stagedConfigPath"] as? String,
            connectionPending = state["connection_pending"] as? Boolean ?: false,
        )
    }

    private fun beginTransition(action: QuickTileAction): Long? {
        val generation = QuickTileTransitionGate.begin(action) ?: return null
        transitionHandler.postDelayed(
            { QuickTileTransitionGate.expire(generation) },
            TRANSITION_TIMEOUT_MILLIS,
        )
        return generation
    }

    private data class QuickTileRuntimeSnapshot(
        val phase: String?,
        val stagedConfigPath: String?,
        val connectionPending: Boolean,
    ) {
        val isRunning: Boolean get() = phase == AndroidRuntimePhase.RUNNING.wireValue
    }

    companion object {
        private const val TRANSITION_TIMEOUT_MILLIS = 3_000L
        private const val REGISTRATION_PREFERENCES = "pokrov_quick_tile_registration"
        private const val ACTIVE_MODE_REGISTRATION_VERSION = 1
        private const val ACTIVE_MODE_REGISTRATION_KEY = "active_mode_version"
        const val EXTRA_TILE_TRANSITION_GENERATION = "space.pokrov.runtime.TILE_GENERATION"

        fun completeRuntimeTransition(context: Context, generation: Long?) {
            QuickTileTransitionGate.complete(generation)
            requestRefresh(context)
        }

        fun requestRefresh(context: Context) {
            TileService.requestListeningState(
                context,
                ComponentName(context, PokrovQuickSettingsTileService::class.java),
            )
        }

        fun ensureActiveModeRegistration(context: Context) {
            val preferences = context.getSharedPreferences(
                REGISTRATION_PREFERENCES,
                Context.MODE_PRIVATE,
            )
            if (preferences.getInt(ACTIVE_MODE_REGISTRATION_KEY, 0) >=
                ACTIVE_MODE_REGISTRATION_VERSION
            ) {
                return
            }
            val packageManager = context.packageManager
            val packageInfo = packageManager.getPackageInfo(context.packageName, 0)
            if (packageInfo.firstInstallTime != packageInfo.lastUpdateTime) {
                val component = ComponentName(
                    context,
                    PokrovQuickSettingsTileService::class.java,
                )
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            preferences.edit()
                .putInt(ACTIVE_MODE_REGISTRATION_KEY, ACTIVE_MODE_REGISTRATION_VERSION)
                .commit()
        }
    }
}
