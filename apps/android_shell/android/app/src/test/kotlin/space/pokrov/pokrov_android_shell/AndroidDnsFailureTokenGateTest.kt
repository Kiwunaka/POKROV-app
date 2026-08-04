package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidDnsFailureTokenGateTest {
    @Test
    fun oldDnsCallbackDuringReplacementCannotOwnTheNewTun() {
        val gate = AndroidDnsFailureTokenGate()
        val oldTunToken = gate.activate()
        var replacementStopped = false

        gate.release()
        val replacementTunToken = gate.activate()

        if (gate.owns(oldTunToken)) {
            replacementStopped = true
        }

        assertFalse(replacementStopped)
        assertFalse(gate.owns(oldTunToken))
        assertTrue(gate.owns(replacementTunToken))
    }
}
