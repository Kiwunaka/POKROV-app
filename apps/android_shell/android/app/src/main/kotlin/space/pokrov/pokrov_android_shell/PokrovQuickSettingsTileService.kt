package space.pokrov.pokrov_android_shell

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

internal enum class QuickTileAction {
    START,
    STOP,
    OPEN_APP,
}

internal fun resolveQuickTileAction(
    isRunning: Boolean,
    hasStagedProfile: Boolean,
    vpnPermissionRequired: Boolean,
): QuickTileAction = when {
    isRunning -> QuickTileAction.STOP
    !hasStagedProfile || vpnPermissionRequired -> QuickTileAction.OPEN_APP
    else -> QuickTileAction.START
}

class PokrovQuickSettingsTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        val profile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(this)
        val isRunning = PokrovRuntimeVpnService.isTunEstablished()
        val permissionRequired = !isRunning && VpnService.prepare(this) != null
        when (
            resolveQuickTileAction(
                isRunning = isRunning,
                hasStagedProfile = profile != null,
                vpnPermissionRequired = permissionRequired,
            )
        ) {
            QuickTileAction.STOP -> PokrovRuntimeVpnService.stop(this)
            QuickTileAction.START -> PokrovRuntimeVpnService.start(
                this,
                requireNotNull(profile).configPath,
            )
            QuickTileAction.OPEN_APP -> openAppForConnection()
        }
        refreshTile()
    }

    private fun openAppForConnection() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(RuntimeHostBridge.EXTRA_TILE_CONNECT, true)
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
        val running = PokrovRuntimeVpnService.isTunEstablished()
        tile.state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "POKROV"
        tile.contentDescription = if (running) {
            "POKROV подключен. Нажмите, чтобы отключить."
        } else {
            "POKROV отключен. Нажмите, чтобы подключить."
        }
        tile.updateTile()
    }

    companion object {
        fun requestRefresh(context: Context) {
            requestListeningState(
                context,
                ComponentName(context, PokrovQuickSettingsTileService::class.java),
            )
        }
    }
}
