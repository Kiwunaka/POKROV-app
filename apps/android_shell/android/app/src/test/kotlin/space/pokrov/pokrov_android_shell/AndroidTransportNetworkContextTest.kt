package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.InetAddress

class AndroidTransportNetworkContextTest {
    @Test
    fun vpnContextFollowsRuntimeHandoverWhilePreviousCellularRemainsAvailable() {
        fun select(retained: String, runtime: String): String? = selectTransportUnderlyingNetwork(
            activeIsVpn = true,
            retained = retained,
            runtime = runtime,
            isEligible = { it == "cellular" || it == "wifi" },
            selectDefault = { error("The running VPN already has an observed physical uplink") },
        )

        val connected = select(retained = "cellular", runtime = "cellular")
        assertEquals("cellular", connected)
        assertEquals("wifi", select(retained = connected!!, runtime = "wifi"))
    }

    @Test
    fun ipv6RequiresUsableSourceAndDefaultRouteOnCapturedUplink() {
        val available = AndroidTransportNetworkContext.CandidateNetwork.Companion::ipv6Available
        val global = listOf(InetAddress.getByName("2001:db8::2"))
        assertTrue(available(global, true))
        assertFalse(available(global, false))
        assertFalse(available(listOf(InetAddress.getByName("fe80::2")), true))
        assertFalse(available(listOf(InetAddress.getByName("192.0.2.2")), true))
    }

    @Test
    fun cellularSelectionKeySurvivesNetworkHandleChange() {
        val key = AndroidTransportNetworkContext.CandidateNetwork.Companion::selectionKey
        assertEquals("android:cellular:25001", key(101L, "cellular", "25001"))
        assertEquals("android:cellular:25001", key(202L, "cellular", "25001"))
        assertEquals("android:cellular:25099", key(202L, "cellular", "25099"))
        assertEquals("android:101", key(101L, "wifi", null))
    }

    @Test
    fun ssidDecodingPreservesExactIdentityAndRejectsRedactedValue() {
        val decode = AndroidTransportNetworkContext.Companion::decodeWifiSsid
        assertEquals("Home", decode("\"Home\""))
        assertEquals("home", decode("\"home\""))
        assertEquals(" Home ", decode("\" Home \""))
        assertEquals(null, decode("<unknown ssid>"))
        assertEquals("<unknown ssid>", decode("\"<unknown ssid>\""))
    }

    @Test
    fun carrierIsExposedOnlyForCellularCandidates() {
        val cellular = AndroidTransportNetworkContext.CandidateNetwork(
            null, null, null, true, false, "cellular", "25001", "МТС",
        ).channelValue()
        assertEquals("МТС", cellular["carrier"])
        assertEquals("25001", cellular["mcc_mnc"])

        val wifi = AndroidTransportNetworkContext.CandidateNetwork(
            null, null, null, true, false, "wifi", wifiSsid = "Home",
        ).channelValue()
        assertFalse(wifi.containsKey("carrier"))
        assertFalse(wifi.containsKey("wifiSsid"))
        assertFalse(wifi.containsValue("Home"))
    }
}
