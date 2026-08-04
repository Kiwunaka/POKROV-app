package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidCoreEgressFailClosedPolicyTest {
    @Test
    fun healthyProbe_keepsRuntimeRunning() {
        assertFalse(
            AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = AndroidCoreEgressProbeResult.HEALTHY,
                probeGeneration = 7L,
                activeGeneration = 7L,
                hasActiveTun = true,
            ),
        )
    }

    @Test
    fun confirmedFailedProbe_stopsActiveRuntime() {
        assertTrue(
            AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = AndroidCoreEgressProbeResult.FAILED,
                probeGeneration = 7L,
                activeGeneration = 7L,
                hasActiveTun = true,
            ),
        )
    }

    @Test
    fun unavailableChannel_stopsActiveRuntime() {
        assertTrue(
            AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                probeGeneration = 7L,
                activeGeneration = 7L,
                hasActiveTun = true,
            ),
        )
    }

    @Test
    fun staleFailedProbe_cannotStopNewRuntime() {
        assertFalse(
            AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = AndroidCoreEgressProbeResult.FAILED,
                probeGeneration = 7L,
                activeGeneration = 8L,
                hasActiveTun = true,
            ),
        )
    }

    @Test
    fun failedProbe_afterStopRace_cannotStopAgain() {
        assertFalse(
            AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = AndroidCoreEgressProbeResult.TIMED_OUT,
                probeGeneration = 7L,
                activeGeneration = 7L,
                hasActiveTun = false,
            ),
        )
    }
}
