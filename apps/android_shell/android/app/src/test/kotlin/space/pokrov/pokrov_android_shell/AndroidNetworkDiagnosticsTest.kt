package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidNetworkDiagnosticsTest {
    @Test
    fun credentialsOnlyGoToFixedOwnedHttpsObservationPath() {
        assertEquals("https://app.pokrov.space/api/client/network/context",
            AndroidNetworkDiagnostics.observationUrl("https://app.pokrov.space/").toString())
        listOf("http://app.pokrov.space", "https://app.pokrov.space.evil.test",
            "https://app.pokrov.space@evil.test", "https://app.pokrov.space:444",
            "https://app.pokrov.space/redirect", "https://api.pokrov.space?token=x",
            "https://api.pokrov.space#fragment").forEach {
            assertNull(AndroidNetworkDiagnostics.observationUrl(it))
        }
    }

    @Test
    fun carrierIsBoundedAndCannotCarryHeadersOrUrls() {
        assertEquals("МТС", AndroidNetworkDiagnostics.safeCarrier(" МТС "))
        assertNull(AndroidNetworkDiagnostics.safeCarrier("carrier\nheader"))
        assertNull(AndroidNetworkDiagnostics.safeCarrier("https://example.test"))
        assertNull(AndroidNetworkDiagnostics.safeCarrier("x".repeat(81)))
    }

    @Test
    fun mobileOperatorCodeIsOnlyAsciiMccAndMnc() {
        assertEquals("25001", AndroidNetworkDiagnostics.safeMccMnc("25001"))
        assertEquals("310260", AndroidNetworkDiagnostics.safeMccMnc("310260"))
        assertNull(AndroidNetworkDiagnostics.safeMccMnc("25001\n"))
        assertNull(AndroidNetworkDiagnostics.safeMccMnc("25A01"))
        assertNull(AndroidNetworkDiagnostics.safeMccMnc(""))
    }
}
