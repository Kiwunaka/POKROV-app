package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class PokrovVpnSystemActionTest {
    @Test
    fun explicitStopDoesNotClaimAlreadyDisconnectedOrConnected() {
        assertEquals(SystemVpnState.DISCONNECTING, resolveSystemVpnState(
            tunEstablished = true,
            serviceRunning = true,
            connectionPending = false,
            transportProofPending = false,
            coreEgressVerified = true,
            transportLeaseActive = false,
            stopPending = true,
        ))
    }

    @Test
    fun retainedTunWithoutEgressProofIsProtectionNotConnected() {
        assertEquals(SystemVpnState.PROTECTED, resolveSystemVpnState(
            tunEstablished = true,
            serviceRunning = true,
            connectionPending = false,
            transportProofPending = false,
            coreEgressVerified = false,
            transportLeaseActive = true,
        ))
    }

    @Test
    fun pendingTransportProofDoesNotClaimConnectedTun() {
        assertEquals(SystemVpnState.CONNECTING, resolveSystemVpnState(
            tunEstablished = true,
            serviceRunning = true,
            connectionPending = false,
            transportProofPending = true,
            coreEgressVerified = true,
            transportLeaseActive = false,
        ))
    }

    @Test
    fun verifiedEgressAndConfirmedStopHaveDifferentStates() {
        assertEquals(SystemVpnState.CONNECTED, resolveSystemVpnState(
            tunEstablished = true,
            serviceRunning = true,
            connectionPending = false,
            transportProofPending = false,
            coreEgressVerified = true,
            transportLeaseActive = false,
        ))
        assertEquals(SystemVpnState.OFF, resolveSystemVpnState(
            tunEstablished = false,
            serviceRunning = false,
            connectionPending = false,
            transportProofPending = false,
            coreEgressVerified = null,
            transportLeaseActive = false,
        ))
    }
}
