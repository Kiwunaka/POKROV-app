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
}
