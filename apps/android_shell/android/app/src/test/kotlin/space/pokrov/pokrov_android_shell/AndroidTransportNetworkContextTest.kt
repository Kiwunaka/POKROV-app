package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
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
}
