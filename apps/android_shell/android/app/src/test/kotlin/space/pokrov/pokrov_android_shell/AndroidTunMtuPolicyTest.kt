package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidTunMtuPolicyTest {
    @Test
    fun missingAndMalformedValuesUseConservativeDefault() {
        assertEquals(1280, AndroidTunMtuPolicy.select(null, null))
        assertEquals(1280, AndroidTunMtuPolicy.select("1400", null))
        assertEquals(1280, AndroidTunMtuPolicy.select(1400.0, null))
    }

    @Test
    fun valuesOutsideProfileBoundsUseConservativeDefault() {
        assertEquals(1280, AndroidTunMtuPolicy.select(1279, null))
        assertEquals(1280, AndroidTunMtuPolicy.select(1501, null))
        assertEquals(1280, AndroidTunMtuPolicy.select(9000, null))
    }

    @Test
    fun validValueIsLimitedByUsablePlatformInterfaceMtu() {
        assertEquals(1492, AndroidTunMtuPolicy.select(1492L, 1500))
        assertEquals(1400, AndroidTunMtuPolicy.select(1500, 1400))
        assertEquals(1280, AndroidTunMtuPolicy.select(1500, 1280))
        assertEquals(1500, AndroidTunMtuPolicy.select(1500, 9000))
    }

    @Test
    fun unusablePlatformCeilingCannotForceBelowIpv6Minimum() {
        assertEquals(1400, AndroidTunMtuPolicy.select(1400, 1279))
    }
}
