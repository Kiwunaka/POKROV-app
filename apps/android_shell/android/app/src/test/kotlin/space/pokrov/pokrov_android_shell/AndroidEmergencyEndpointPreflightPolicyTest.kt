package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidEmergencyEndpointPreflightPolicyTest {
    @Test
    fun `ordinary profiles keep endpoint preflight diagnostic only`() {
        assertTrue(
            offlineEmergencyRootPreflightAccepted(
                coreEgressProbeRequired = true,
                rootCategory = "timeout",
            ),
        )
    }

    @Test
    fun `offline emergency profile requires reachable root endpoint`() {
        assertTrue(
            offlineEmergencyRootPreflightAccepted(
                coreEgressProbeRequired = false,
                rootCategory = "reachable",
            ),
        )
        for (category in listOf(null, "timeout", "dns_unresolved", "endpoint_invalid")) {
            assertFalse(
                offlineEmergencyRootPreflightAccepted(
                    coreEgressProbeRequired = false,
                    rootCategory = category,
                ),
            )
        }
        assertTrue(
            AndroidRuntimeSafety.publicFailureMessage("emergency_endpoint_unreachable")
                .contains("не включил системный VPN"),
        )
    }
}
