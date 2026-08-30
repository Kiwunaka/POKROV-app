package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidRuntimeLogClassifierTest {
    @Test
    fun awgSafeDiagnosticAcceptsOnlyClosedCanonicalPayload() {
        val diagnostic = AndroidRuntimeLogClassifier.parseAwgSafeDiagnostic(
            "awg_safe_diag code=receive_handshake_response occurrence=4",
        )

        assertEquals(
            AndroidAwgSafeDiagnostic("receive_handshake_response", 4),
            diagnostic,
        )
        assertEquals(
            "awg_safe_diag code=receive_handshake_response occurrence=4",
            diagnostic?.canonicalMessage(),
        )
    }

    @Test
    fun awgSafeDiagnosticRejectsRawOrUnboundedMaterial() {
        val rejected = listOf(
            "WARN awg_safe_diag code=handshake_retry occurrence=1",
            "awg_safe_diag code=handshake_retry occurrence=0",
            "awg_safe_diag code=handshake_retry occurrence=5",
            "awg_safe_diag code=peer_secret occurrence=1",
            "awg_safe_diag code=handshake_retry occurrence=1 endpoint=secret",
            "awg_safe_diag code=handshake_retry occurrence=1\n",
            "service started",
        )

        rejected.forEach { message ->
            assertNull(AndroidRuntimeLogClassifier.parseAwgSafeDiagnostic(message))
        }
    }

    @Test
    fun awgEndpointEgressDiagnosticAcceptsOnlyClosedCoreCategory() {
        assertEquals(
            AndroidAwgSafeDiagnostic("egress_probe_tls_certificate", 1),
            AndroidRuntimeLogClassifier.parseAwgEgressProbeDiagnostic(
                "selected endpoint URL test failed category=tls_certificate",
            ),
        )
        assertEquals(
            AndroidAwgSafeDiagnostic("egress_probe_endpoint_initialization_timeout", 1),
            AndroidRuntimeLogClassifier.parseAwgEgressProbeDiagnostic(
                "selected endpoint URL test failed category=endpoint_initialization_timeout",
            ),
        )

        listOf(
            "WARN selected endpoint URL test failed category=tls_certificate",
            "selected endpoint URL test failed category=raw_secret",
            "selected endpoint URL test failed category=tls_certificate endpoint=secret",
            "selected endpoint URL test failed category=tls_certificate\n",
        ).forEach { message ->
            assertNull(AndroidRuntimeLogClassifier.parseAwgEgressProbeDiagnostic(message))
        }
    }

    @Test
    fun realityFailureReturnsOnlyFixedCategory() {
        val raw = "outbound/vless: reality handshake failed for credential TEST-SECRET"

        val result = AndroidRuntimeLogClassifier.classify(raw)

        assertEquals("reality_handshake_failed", result)
        assertFalse(result.orEmpty().contains("TEST-SECRET"))
    }

    @Test
    fun realityFailuresKeepAUsefulRedactedSubtype() {
        assertEquals(
            "reality_verification_failed",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: reality verification failed for TEST-SECRET",
            ),
        )
        assertEquals(
            "reality_connection_reset",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: reality handshake failed: connection reset by peer",
            ),
        )
        assertEquals(
            "reality_unexpected_eof",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: reality handshake failed: EOF",
            ),
        )
        assertEquals(
            "reality_timeout",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: reality handshake failed: deadline exceeded",
            ),
        )
        assertEquals(
            "reality_utls_unavailable",
            AndroidRuntimeLogClassifier.classify(
                "uTLS is required by reality client",
            ),
        )
    }

    @Test
    fun connectionResetReturnsFixedCategory() {
        assertEquals(
            "outbound_connection_reset",
            AndroidRuntimeLogClassifier.classify("read tcp: connection reset by peer"),
        )
    }

    @Test
    fun vlessDnsFailureIsSeparatedFromAuthenticationFailure() {
        assertEquals(
            "vless_dns_failed",
            AndroidRuntimeLogClassifier.classify("outbound/vless: lookup failed: dns error"),
        )
    }

    @Test
    fun vlessNestedFailuresKeepOnlyActionableFixedCategories() {
        assertEquals(
            "vless_unexpected_eof",
            AndroidRuntimeLogClassifier.classify("outbound/vless: connection failed: EOF"),
        )
        assertEquals(
            "vless_tls_failed",
            AndroidRuntimeLogClassifier.classify("outbound/vless: TLS certificate error"),
        )
        assertEquals(
            "vless_timeout",
            AndroidRuntimeLogClassifier.classify("outbound/vless: dial timed out"),
        )
    }

    @Test
    fun vlessGenericTransportFailuresKeepOnlyFixedCategories() {
        assertEquals(
            "vless_context_cancelled",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: process connection failed: context canceled",
            ),
        )
        assertEquals(
            "vless_connection_closed",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: upload failed: use of closed network connection",
            ),
        )
        assertEquals(
            "vless_broken_pipe",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: upload failed: broken pipe",
            ),
        )
        assertEquals(
            "vless_packet_session_failed",
            AndroidRuntimeLogClassifier.classify(
                "outbound/vless: packet conn failed",
            ),
        )
    }

    @Test
    fun dnsTimeoutReturnsFixedCategory() {
        assertEquals(
            "dns_timeout",
            AndroidRuntimeLogClassifier.classify("dns exchange failed: deadline exceeded"),
        )
    }

    @Test
    fun ordinaryCoreMessageIsDropped() {
        assertNull(AndroidRuntimeLogClassifier.classify("service started"))
    }

    @Test
    fun perRequestFailuresStayAdvisory() {
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("dns_runtime_error"))
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("dns_exchange_failed"))
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("outbound_timeout"))
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("outbound_connection_reset"))
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("tls_handshake_failed"))
    }

    @Test
    fun unscopedCoreFailuresNeverOverrideGlobalVpnHealth() {
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("reality_handshake_failed"))
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("vless_timeout"))
        assertFalse(
            AndroidRuntimeLogClassifier.affectsRuntimeHealth("dns_default_interface_missing"),
        )
        assertFalse(AndroidRuntimeLogClassifier.affectsRuntimeHealth("dns_network_unreachable"))
    }

    @Test
    fun repeatedRuntimeCategoriesAreRateLimitedWithASuppressedCount() {
        var now = 1_000L
        val limiter = AndroidRuntimeLogLimiter(
            emissionIntervalMillis = 10_000L,
            clockMillis = { now },
        )

        assertEquals(
            AndroidRuntimeLogEvent("dns_runtime_error", 0L),
            limiter.record("dns_runtime_error"),
        )
        assertNull(limiter.record("dns_runtime_error"))
        assertNull(limiter.record("dns_runtime_error"))

        now += 10_000L
        assertEquals(
            AndroidRuntimeLogEvent("dns_runtime_error", 2L),
            limiter.record("dns_runtime_error"),
        )
    }

    @Test
    fun runtimeCategoriesHaveIndependentWindowsAndResetPerSession() {
        var now = 5_000L
        val limiter = AndroidRuntimeLogLimiter(
            emissionIntervalMillis = 10_000L,
            clockMillis = { now },
        )

        assertNotNull(limiter.record("dns_runtime_error"))
        assertNotNull(limiter.record("reality_verification_failed"))
        assertNull(limiter.record("dns_runtime_error"))

        limiter.reset()
        now += 1L
        assertEquals(
            AndroidRuntimeLogEvent("dns_runtime_error", 0L),
            limiter.record("dns_runtime_error"),
        )
    }
}
