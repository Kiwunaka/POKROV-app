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
}
