package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidLocalDpiFallbackTest {
    @Test fun atsFallbackKeepsLeaseAndRequiresDirectUpstream() {
        val lease = LocalDpiVpnOutbound("pokrov-ats", "pokrov-ats-lease",
            upstreamTag = "pokrov-ats-upstream")
        val upstream = LocalDpiVpnOutbound("pokrov-ats-upstream", "vless")
        assertEquals("pokrov-ats", localDpiVpnFallback(listOf(lease, upstream), "pokrov-ats"))
        assertNull(localDpiVpnFallback(listOf(lease, upstream.copy(detour = "bridge")), "pokrov-ats"))
    }
}
