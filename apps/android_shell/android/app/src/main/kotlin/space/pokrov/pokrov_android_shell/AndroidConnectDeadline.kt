package space.pokrov.pokrov_android_shell

import android.os.SystemClock

/** Original boot-relative budget, never renewed by a permission/start retry. */
internal data class AndroidConnectDeadline(
    val bootRef: String,
    val startedElapsedMs: Long,
    val expiresElapsedMs: Long,
) {
    fun isCurrent(): Boolean {
        val now = SystemClock.elapsedRealtime()
        return now >= startedElapsedMs && now < expiresElapsedMs
    }
}
