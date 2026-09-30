package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidResolverPolicyTest {
    @Test
    fun `platform resolver permits retries and bounds a missing callback`() {
        assertEquals(0, AndroidResolverPolicy.QUERY_FLAGS)
        assertTrue(AndroidResolverPolicy.RESPONSE_WAIT_MILLIS > 0)
        assertEquals(2, AndroidResolverPolicy.SERVFAIL_RCODE)
    }

    @Test
    fun `resolver diagnostics use fixed non-sensitive outcome codes`() {
        assertEquals("resolver_response_error", AndroidResolverPolicy.RESPONSE_ERROR)
        assertEquals("resolver_callback_error", AndroidResolverPolicy.CALLBACK_ERROR)
        assertEquals("resolver_timeout", AndroidResolverPolicy.TIMEOUT)
        assertEquals(
            "POKROV не смог подтвердить DNS-подключение устройства.",
            AndroidRuntimeSafety.publicFailureMessage(AndroidResolverPolicy.TIMEOUT),
        )
    }

    @Test
    fun `only DNS transport failures fail close an active runtime`() {
        assertTrue(
            AndroidResolverPolicy.shouldFailCloseRuntime(
                AndroidResolverPolicy.RuntimeOutcome.CALLBACK_ERROR,
            ),
        )
        assertTrue(
            AndroidResolverPolicy.shouldFailCloseRuntime(
                AndroidResolverPolicy.RuntimeOutcome.TIMEOUT,
            ),
        )
        assertFalse(
            AndroidResolverPolicy.shouldFailCloseRuntime(
                AndroidResolverPolicy.RuntimeOutcome.RESPONSE_RCODE,
            ),
        )
        assertFalse(
            AndroidResolverPolicy.shouldFailCloseRuntime(
                AndroidResolverPolicy.RuntimeOutcome.CANCELED,
            ),
        )
    }

    @Test
    fun `only a known single AAAA question isolates a resolver failure`() {
        val ipv6 = byteArrayOf(0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 120, 0, 0, 28, 0, 1)
        assertTrue(AndroidResolverPolicy.isSingleIpv6Question(ipv6))
        assertFalse(AndroidResolverPolicy.isSingleIpv6Question(ipv6.copyOf().apply { this[16] = 1 }))
        assertFalse(AndroidResolverPolicy.isSingleIpv6Question(ipv6.copyOf().apply { this[5] = 2 }))
        assertFalse(AndroidResolverPolicy.isSingleIpv6Question(ipv6.copyOf().apply { this[2] = 0x81.toByte() }))
        assertFalse(AndroidResolverPolicy.isSingleIpv6Question(ipv6.copyOf().apply { this[12] = 0xc0.toByte() }))
        assertFalse(AndroidResolverPolicy.isSingleIpv6Question(ipv6.copyOf(ipv6.size - 1)))
    }
}
