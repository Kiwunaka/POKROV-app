package space.pokrov.pokrov_android_shell

import org.junit.Assert.*
import org.junit.Test

class AndroidNetworkDiagnosticsTest {
    @Test fun userAgentUsesTheBackendClientVersionContract() {
        assertEquals("POKROV/android/1.5.0+4191", AndroidNetworkDiagnostics.userAgent("1.5.0+4191"))
    }
    @Test fun hourlyChecksRespectResourceLimits() {
        val interval = AndroidNetworkDiagnostics.intervalMs
        assertTrue(AndroidNetworkDiagnostics.checkDue(interval + 1, 1, 75, false, false))
        assertFalse(AndroidNetworkDiagnostics.checkDue(interval, 1, 75, false, false))
        assertFalse(AndroidNetworkDiagnostics.checkDue(interval + 1, 1, 20, false, false))
        assertFalse(AndroidNetworkDiagnostics.checkDue(interval + 1, 1, -1, false, false))
        assertFalse(AndroidNetworkDiagnostics.checkDue(interval + 1, 1, 75, true, false))
        assertFalse(AndroidNetworkDiagnostics.checkDue(interval + 1, 1, 75, false, true))
    }
}
