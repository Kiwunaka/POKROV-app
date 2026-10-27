package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidLocalDpiFallbackTest {
    @Test fun smartSafeRequiresOnlyYouTubeAndProtectedFinal() {
        val direct = LocalDpiVpnOutbound("direct", "direct")
        val vpn = LocalDpiVpnOutbound("vpn", "vless", tlsSecure = true)
        val outbounds = listOf(direct, vpn)
        assertTrue(localDpiModeAllows("smart_safe", setOf("youtube"), "vpn", outbounds))
        assertFalse(localDpiModeAllows("smart_safe", setOf("youtube", "other"), "vpn", outbounds))
        assertFalse(localDpiModeAllows("smart_safe", setOf("youtube"), "direct", outbounds))
        assertFalse(localDpiModeAllows("smart_safe", setOf("youtube"), "vpn", listOf(vpn.copy(tlsSecure = false))))
        assertTrue(localDpiModeAllows("selective", setOf("other"), "direct", outbounds))
        assertFalse(localDpiModeAllows("selective", setOf("other"), "vpn", outbounds))
        assertFalse(localDpiModeAllows("full", setOf("youtube"), "vpn", outbounds))
    }

    @Test fun atsFallbackKeepsLeaseAndRequiresDirectUpstream() {
        val lease = LocalDpiVpnOutbound("pokrov-ats", "pokrov-ats-lease",
            upstreamTag = "pokrov-ats-upstream")
        val upstream = LocalDpiVpnOutbound("pokrov-ats-upstream", "vless", tlsSecure = true)
        assertEquals("pokrov-ats", localDpiVpnFallback(listOf(lease, upstream), "pokrov-ats"))
        assertNull(localDpiVpnFallback(listOf(lease, upstream.copy(detour = "bridge")), "pokrov-ats"))
    }

    @Test fun fallbackFailureReportsOnlyClosedReason() {
        val lease = LocalDpiVpnOutbound("lease", "pokrov-ats-lease", upstreamTag = "upstream")
        val upstream = LocalDpiVpnOutbound("upstream", "vless", detour = "direct", tlsSecure = true)
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

    @Test fun verifiedBridgeRetainsSelectorAndLeaseFallback() {
        val secureTls = localDpiSecureTls(true, false)
        val direct = LocalDpiVpnOutbound("vpn", "vless", tlsSecure = secureTls)
        val bridged = LocalDpiVpnOutbound("vpn-bridge", "vless", detour = "bridge", tlsSecure = secureTls)
        val bridge = LocalDpiVpnOutbound("bridge", "vless", tlsSecure = localDpiSecureTls(true, null))
        val selector = LocalDpiVpnOutbound("selector", "selector", children = listOf("vpn", "vpn-bridge"))
        val lease = LocalDpiVpnOutbound("lease", "pokrov-ats-lease", upstreamTag = "vpn-bridge")
        fun graph(leaf: LocalDpiVpnOutbound = bridged, carrier: LocalDpiVpnOutbound = bridge) =
            listOf(selector, direct, leaf, carrier, lease)

        assertEquals("selector", localDpiVpnFallback(graph(), "selector"))
        assertEquals("lease", localDpiVpnFallback(graph(), "lease"))
        assertNull(localDpiVpnFallback(graph(leaf = bridged.copy(tlsSecure = localDpiSecureTls(null, null))), "selector"))
        assertNull(localDpiVpnFallback(graph(carrier = bridge.copy(tlsSecure = localDpiSecureTls(true, true))), "lease"))
        assertNull(localDpiVpnFallback(graph(carrier = bridge.copy(type = "direct")), "selector"))
        assertNull(localDpiVpnFallback(graph(carrier = bridge.copy(detour = "vpn-bridge")), "lease"))
    }
}
