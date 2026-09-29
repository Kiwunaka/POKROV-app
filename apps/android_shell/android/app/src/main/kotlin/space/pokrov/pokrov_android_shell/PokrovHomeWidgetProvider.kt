package space.pokrov.pokrov_android_shell

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PokrovHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            val action = PokrovVpnSystemAction.toggle(context, "home_widget")
            // If permissions/profile changed since rendering, show an activity
            // PendingIntent for the next click; do not launch through a receiver.
            if (action == QuickTileAction.OPEN_APP) refreshAll(context)
        } else {
            super.onReceive(context, intent)
        }
    }

    companion object {
        private const val ACTION_TOGGLE = "space.pokrov.home_widget.TOGGLE"

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PokrovHomeWidgetProvider::class.java))
            if (ids.isNotEmpty()) update(context, manager, ids)
        }

        private fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val control = PokrovVpnSystemAction.read(context)
            val status = when (control.state) {
                SystemVpnState.OFF -> R.string.pokrov_vpn_off
                SystemVpnState.CONNECTING -> R.string.pokrov_vpn_connecting
                SystemVpnState.DISCONNECTING -> R.string.pokrov_vpn_disconnecting
                SystemVpnState.CONNECTED -> R.string.pokrov_vpn_connected
                SystemVpnState.PROTECTED -> R.string.pokrov_vpn_protected
            }
            val actionLabel = when (control.action) {
                QuickTileAction.START -> R.string.pokrov_vpn_connect
                QuickTileAction.STOP -> R.string.pokrov_vpn_disconnect
                QuickTileAction.OPEN_APP -> R.string.pokrov_vpn_open_app
            }
            val openApp = PendingIntent.getActivity(
                context, 14073, PokrovVpnSystemAction.appIntent(context),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val toggle = if (control.action == QuickTileAction.OPEN_APP) openApp else {
                PendingIntent.getBroadcast(
                    context, 14074,
                    Intent(context, PokrovHomeWidgetProvider::class.java).setAction(ACTION_TOGGLE),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            val views = RemoteViews(context.packageName, R.layout.pokrov_home_widget).apply {
                setTextViewText(R.id.pokrov_widget_status, context.getString(status))
                setTextViewText(R.id.pokrov_widget_toggle, context.getString(actionLabel))
                setOnClickPendingIntent(R.id.pokrov_widget_title, openApp)
                setOnClickPendingIntent(R.id.pokrov_widget_toggle, toggle)
            }
            manager.updateAppWidget(ids, views)
        }
    }
}
