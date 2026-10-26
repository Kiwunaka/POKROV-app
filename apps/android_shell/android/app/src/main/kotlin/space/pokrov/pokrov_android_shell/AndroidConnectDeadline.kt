package space.pokrov.pokrov_android_shell

import android.os.SystemClock
import java.time.Duration
import java.time.Instant

/** Boot-relative bound; permission/start retries never renew its original budget. */
internal data class AndroidConnectDeadline(
    val bootRef: String,
    val startedElapsedMs: Long,
    val expiresElapsedMs: Long,
    val expiresAt: Instant? = null,
) {
    fun isCurrent(now: Long = SystemClock.elapsedRealtime(), wallNow: Instant? = null): Boolean {
        return now >= startedElapsedMs && now < expiresElapsedMs &&
            (expiresAt == null || (wallNow ?: Instant.now()).isBefore(expiresAt))
    }

    companion object {
        // The caller has verified the signed permit/control and installed the
        // bound Core worker. Match its expiry to the running leased profile.
        fun firstProviderQa(start: AndroidConnectDeadline, elapsed: Long, now: Instant,
            issued: String, expires: String, leaseIssued: String, leaseNewUntil: String,
            leaseActiveUntil: String): AndroidConnectDeadline? {
            if (!start.isCurrent(elapsed, now) || issued != leaseIssued || expires != leaseNewUntil ||
                expires != leaseActiveUntil) return null
            val times = runCatching { Instant.parse(issued) to Instant.parse(expires) }.getOrNull() ?: return null
            val lifetime = Duration.between(times.first, times.second).toMillis()
            val remaining = Duration.between(now, times.second).toMillis()
            if (now.isBefore(times.first) || lifetime !in 1L..600_000L || remaining !in 1L..600_000L) return null
            return start.copy(expiresElapsedMs = elapsed + remaining, expiresAt = times.second)
        }
    }
}
