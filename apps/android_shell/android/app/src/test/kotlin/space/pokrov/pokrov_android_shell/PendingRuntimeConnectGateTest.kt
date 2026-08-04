package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingRuntimeConnectGateTest {
    @Test
    fun dispatchedDirectStart_releasesGateSoTheNextConnectIsFresh() {
        val gate = PendingRuntimeConnectGate()
        val (first, createdFirst) = gate.acquire("/tmp/pokrov-runtime.json")

        assertTrue(createdFirst)
        assertTrue(gate.isCurrent(first))

        gate.completeDispatch(first)

        assertFalse(gate.isCurrent(first))
        val (second, createdSecond) = gate.acquire("/tmp/pokrov-runtime.json")
        assertTrue(createdSecond)
        assertNotEquals(first.id, second.id)
        assertTrue(gate.isCurrent(second))
    }

    @Test
    fun staleDispatchCompletion_cannotReleaseNewConnect() {
        val gate = PendingRuntimeConnectGate()
        val (first, _) = gate.acquire("/tmp/pokrov-runtime.json")
        gate.invalidate()
        val (second, _) = gate.acquire("/tmp/pokrov-runtime.json")

        gate.completeDispatch(first)

        assertTrue(gate.isCurrent(second))
    }
}
