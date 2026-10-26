package space.pokrov.pokrov_android_shell

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidConnectDeadlineTest {
    @Test
    fun firstProviderQaHandoffOutlivesStartButEndsAtMatchingLeaseExpiry() {
        val start = AndroidConnectDeadline("boot", 1_000L, 19_000L)
        val issued = "2026-10-26T20:00:00Z"
        val expires = "2026-10-26T20:05:00Z"
        val now = Instant.parse("2026-10-26T20:00:10Z")
        val retained = AndroidConnectDeadline.firstProviderQa(start, 11_000L, now,
            issued, expires, issued, expires, expires)!!
        assertFalse(start.isCurrent(20_000L))
        assertTrue(retained.isCurrent(20_000L, now))
        assertEquals(301_000L, retained.expiresElapsedMs)
        assertTrue(retained.isCurrent(300_999L, now))
        assertFalse(retained.isCurrent(301_000L, now))
        assertFalse(retained.isCurrent(20_000L, Instant.parse(expires)))

        assertNull(AndroidConnectDeadline.firstProviderQa(start, 19_000L, now,
            issued, expires, issued, expires, expires))
        assertNull(AndroidConnectDeadline.firstProviderQa(start, 11_000L, now,
            issued, expires, issued, expires, "2026-10-26T20:04:00Z"))
        assertNull(AndroidConnectDeadline.firstProviderQa(start, 11_000L, Instant.parse(expires),
            issued, expires, issued, expires, expires))
        val tooLong = "2026-10-26T20:10:01Z"
        assertNull(AndroidConnectDeadline.firstProviderQa(start, 11_000L, now,
            issued, tooLong, issued, tooLong, tooLong))
    }
}
