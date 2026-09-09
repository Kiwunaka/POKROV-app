package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingRuntimeConnectGateTest {
    @Test
    fun profileReplacementAtSamePath_invalidatesOldConsentRequest() {
        val gate = PendingRuntimeConnectGate()
        val (first, _) = gate.acquire("/tmp/pokrov-runtime.json", "a".repeat(64))
        val (second, created) = gate.acquire("/tmp/pokrov-runtime.json", "b".repeat(64))
        assertTrue(created)
        assertFalse(gate.isCurrent(first))
        gate.completeDispatch(first)
        assertTrue(gate.isCurrent(second))
        assertNotEquals(first.profileDigest, second.profileDigest)
    }

    @Test
    fun dispatchedDirectStart_releasesGateSoTheNextConnectIsFresh() {
        val gate = PendingRuntimeConnectGate()
        val (first, createdFirst) = gate.acquire("/tmp/pokrov-runtime.json", "a".repeat(64))

        assertTrue(createdFirst)
        assertTrue(gate.isCurrent(first))

        gate.completeDispatch(first)

        assertFalse(gate.isCurrent(first))
        val (second, createdSecond) = gate.acquire("/tmp/pokrov-runtime.json", "a".repeat(64))
        assertTrue(createdSecond)
        assertNotEquals(first.id, second.id)
        assertTrue(gate.isCurrent(second))
    }

    @Test
    fun staleDispatchCompletion_cannotReleaseNewConnect() {
        val gate = PendingRuntimeConnectGate()
        val (first, _) = gate.acquire("/tmp/pokrov-runtime.json", "a".repeat(64))
        gate.invalidate()
        val (second, _) = gate.acquire("/tmp/pokrov-runtime.json", "a".repeat(64))

        gate.completeDispatch(first)

        assertTrue(gate.isCurrent(second))
    }
}
