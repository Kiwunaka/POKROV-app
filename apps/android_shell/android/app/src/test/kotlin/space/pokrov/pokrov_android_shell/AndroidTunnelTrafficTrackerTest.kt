package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidTunnelTrafficTrackerTest {
    @Test
    fun coreTotalsWarmThenProduceSessionRates() {
        var now = 1_000_000_000L
        val tracker = AndroidTunnelTrafficTracker { now }

        val warming = tracker.update(true, 100L, 300L)
        assertEquals(AndroidTunnelTrafficSampleState.WARMING, warming.state)
        assertTrue(warming.available)
        assertNull(warming.uplinkBps)

        now += 2_000_000_000L
        val available = tracker.update(true, 1_100L, 2_300L)
        assertEquals(AndroidTunnelTrafficSampleState.AVAILABLE, available.state)
        assertEquals(500L, available.uplinkBps)
        assertEquals(1_000L, available.downlinkBps)
        assertEquals(1_100L, available.uplinkTotalBytes)
        assertEquals(2_300L, available.downlinkTotalBytes)
    }

    @Test
    fun counterResetNeverTurnsIntoAThroughputSpike() {
        var now = 1_000_000_000L
        val tracker = AndroidTunnelTrafficTracker { now }
        tracker.update(true, 10_000L, 20_000L)
        now += 1_000_000_000L

        val reset = tracker.update(true, 100L, 200L)
        assertEquals(AndroidTunnelTrafficSampleState.RESET, reset.state)
        assertNull(reset.uplinkBps)
        assertNull(reset.downlinkBps)

        now += 1_000_000_000L
        val recovered = tracker.update(true, 500L, 1_000L)
        assertEquals(AndroidTunnelTrafficSampleState.AVAILABLE, recovered.state)
        assertEquals(400L, recovered.uplinkBps)
        assertEquals(800L, recovered.downlinkBps)
    }

    @Test
    fun absentOrInvalidCoreCapabilityIsUnavailableAndClearsBaseline() {
        var now = 1_000_000_000L
        val tracker = AndroidTunnelTrafficTracker { now }
        tracker.update(true, 100L, 200L)
        now += 1_000_000_000L

        assertFalse(tracker.update(false, 200L, 400L).available)
        assertFalse(tracker.update(true, -1L, 400L).available)
        val fresh = tracker.update(true, 300L, 500L)
        assertEquals(AndroidTunnelTrafficSampleState.WARMING, fresh.state)
    }

    @Test
    fun impossibleRateOverflowIsExplicitlyUnavailableForThatSample() {
        var now = 1L
        val tracker = AndroidTunnelTrafficTracker { now }
        tracker.update(true, 0L, 0L)
        now += 1L

        val overflow = tracker.update(true, Long.MAX_VALUE, Long.MAX_VALUE)
        assertEquals(AndroidTunnelTrafficSampleState.OVERFLOW, overflow.state)
        assertNull(overflow.uplinkBps)
        assertNull(overflow.downlinkBps)
    }
}
