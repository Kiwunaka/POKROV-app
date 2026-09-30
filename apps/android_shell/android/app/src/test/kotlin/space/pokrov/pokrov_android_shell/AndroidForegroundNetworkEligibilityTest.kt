package space.pokrov.pokrov_android_shell

import org.junit.Assert.*
import org.junit.Test

class AndroidForegroundNetworkEligibilityTest {
    @Test fun foregroundRequiresExistingPermissionsKnownSsidAndNonCaptiveUplink() {
        fun eligible(foreground: Boolean = true, vpn: Boolean = true,
            notifications: Boolean = true, knownSsid: Boolean = true,
            captive: Boolean? = false): Boolean =
            AndroidForegroundNetworkEligibility.eligible(foreground, vpn, notifications,
                wifiConnected = true, ssidKnown = knownSsid, wifiPermissionRequired = false,
                networkAvailable = true, captivePortal = captive, suppressed = false)
        assertTrue(eligible())
        assertFalse(eligible(foreground = false))
        assertFalse(eligible(vpn = false))
        assertFalse(eligible(notifications = false))
        assertFalse(eligible(knownSsid = false))
        assertFalse(eligible(captive = true))
        assertFalse(eligible(captive = null))
    }

    @Test fun explicitStopFencesOldRequestsAndSuppressesOnlyTheStoppedPhysicalKey() {
        val policy = AndroidForegroundStopPolicy()
        val before = policy.capture("wifi-a")
        assertFalse(before.second)
        policy.explicitStop()
        val stopped = policy.capture("wifi-a")
        assertTrue(stopped.first > before.first)
        assertTrue(stopped.second)
        assertTrue(policy.capture("wifi-a").second)
        assertFalse(policy.capture("wifi-b").second)
        assertEquals(stopped.first, policy.epoch)
    }
}
