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

    @Test fun fallbackFailureReportsOnlyClosedReason() {
        val lease = LocalDpiVpnOutbound("lease", "pokrov-ats-lease", upstreamTag = "upstream")
        val upstream = LocalDpiVpnOutbound("upstream", "vless", detour = "direct")
        val direct = LocalDpiVpnOutbound("direct", "direct")
        fun check(outbounds: List<LocalDpiVpnOutbound>, expected: String) {
            val reasons = mutableListOf<String>()
            assertNull(localDpiVpnFallback(outbounds, "lease") { reasons.add(it) })
            assertEquals(listOf(expected), reasons)
        }
        check(listOf(lease, upstream, direct), "fallback=detour_direct")
        check(listOf(lease), "fallback=lease_target_missing")
        check(listOf(lease, upstream.copy(type = "direct", detour = "")), "fallback=type_direct")
        check(listOf(lease, upstream.copy(type = "selector", detour = "", children = listOf("lease"))),
            "fallback=cycle")
    }
}
