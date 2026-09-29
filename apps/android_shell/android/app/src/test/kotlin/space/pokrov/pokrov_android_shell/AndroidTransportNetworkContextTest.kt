package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AndroidTransportNetworkContextTest {
    @Test
    fun cellularSelectionKeySurvivesNetworkHandleChange() {
        val key = AndroidTransportNetworkContext.CandidateNetwork.Companion::selectionKey
        assertEquals("android:cellular:25001", key(101L, "cellular", "25001"))
        assertEquals("android:cellular:25001", key(202L, "cellular", "25001"))
        assertEquals("android:cellular:25099", key(202L, "cellular", "25099"))
        assertEquals("android:101", key(101L, "wifi", null))
    }

    @Test
    fun carrierIsExposedOnlyForCellularCandidates() {
        val cellular = AndroidTransportNetworkContext.CandidateNetwork(
            null, null, null, true, false, "cellular", "25001", "МТС",
        ).channelValue()
        assertEquals("МТС", cellular["carrier"])
        assertEquals("25001", cellular["mcc_mnc"])

        val wifi = AndroidTransportNetworkContext.CandidateNetwork(
            null, null, null, true, false, "wifi",
        ).channelValue()
        assertFalse(wifi.containsKey("carrier"))
    }
}
