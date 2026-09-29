package space.pokrov.pokrov_android_shell

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.graphics.drawable.Icon

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
    fun isStopping(): Boolean = activeAction == QuickTileAction.STOP

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
        if (isLocked) {
            unlockAndRun(::toggleVpn)
        } else {
            toggleVpn()
        }
    }

    private fun toggleVpn() {
        if (PokrovVpnSystemAction.toggle(this, "quick_settings") == QuickTileAction.OPEN_APP) {
            openAppForConnection()
        }
        refreshTile()
    }

    private fun openAppForConnection() {
        val intent = PokrovVpnSystemAction.appIntent(this)
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
        val control = PokrovVpnSystemAction.read(this)
        val status = when (control.state) {
            SystemVpnState.OFF -> getString(R.string.pokrov_vpn_off)
            SystemVpnState.CONNECTING -> getString(R.string.pokrov_vpn_connecting)
            SystemVpnState.DISCONNECTING -> getString(R.string.pokrov_vpn_disconnecting)
            SystemVpnState.CONNECTED -> getString(R.string.pokrov_vpn_connected)
            SystemVpnState.PROTECTED -> "Защита активна"
        }
        val action = when (control.action) {
            QuickTileAction.START -> getString(R.string.pokrov_vpn_connect)
            QuickTileAction.STOP -> getString(R.string.pokrov_vpn_disconnect)
            QuickTileAction.OPEN_APP -> getString(R.string.pokrov_vpn_open_app)
        }
        tile.icon = Icon.createWithResource(this, R.drawable.ic_pokrov_system)
        tile.label = "POKROV"
        tile.state = if (control.state == SystemVpnState.OFF) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.contentDescription = "POKROV: $status. $action."
        setTileSubtitle(tile, status)
        tile.updateTile()
    }

    private fun setTileSubtitle(tile: Tile, value: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = value
        }
    }

    companion object {
        private const val REGISTRATION_PREFERENCES = "pokrov_quick_tile_registration"
        private const val ACTIVE_MODE_REGISTRATION_VERSION = 1
        private const val ACTIVE_MODE_REGISTRATION_KEY = "active_mode_version"
        const val EXTRA_TILE_TRANSITION_GENERATION = "space.pokrov.runtime.TILE_GENERATION"

        fun completeRuntimeTransition(context: Context, generation: Long?) {
            QuickTileTransitionGate.complete(generation)
            requestRefresh(context)
        }

        fun requestRefresh(context: Context) {
            PokrovHomeWidgetProvider.refreshAll(context)
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
