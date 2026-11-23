package space.pokrov.pokrov_android_shell

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

internal object AndroidVpnRecoveryAlarm {
    const val ACTION_RECOVER = "space.pokrov.runtime.RECOVER"
    private const val RESTART_AFTER_MS = 30_000L
    const val REFRESH_AFTER_MS = RESTART_AFTER_MS / 2

    val supported: Boolean
        get() = Build.VERSION.SDK_INT in Build.VERSION_CODES.O..Build.VERSION_CODES.R &&
            (Build.MANUFACTURER.equals("HUAWEI", ignoreCase = true) ||
                Build.MANUFACTURER.equals("HONOR", ignoreCase = true))

    fun schedule(context: Context): Boolean {
        val alarm = context.getSystemService(AlarmManager::class.java) ?: return false
        val restart = pendingIntent(context, PendingIntent.FLAG_IMMUTABLE) ?: return false
        return try {
            // The running service moves the deadline forward. This alarm also
            // survives process death and does not wake a sleeping phone.
            alarm.setExact(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + RESTART_AFTER_MS, restart)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun cancel(context: Context) {
        if (!supported) return
        val intent = pendingIntent(context, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
        context.getSystemService(AlarmManager::class.java)?.cancel(intent)
    }

    private fun pendingIntent(context: Context, flags: Int): PendingIntent? =
        PendingIntent.getForegroundService(context, 0,
            Intent(context, PokrovRuntimeVpnService::class.java).setAction(ACTION_RECOVER), flags)
}
