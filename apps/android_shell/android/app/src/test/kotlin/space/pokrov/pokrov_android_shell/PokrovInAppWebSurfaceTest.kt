package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PokrovInAppWebSurfaceTest {
    @Test
    fun acceptsOnlyOwnedHttpsOriginsForInitialNavigation() {
        assertTrue(
            PokrovWebSurfacePolicy.initialUrlAllowed(
                "https://app.pokrov.space/profile?handoff_token=opaque",
            ),
        )
        assertTrue(PokrovWebSurfacePolicy.initialUrlAllowed("https://pokrov.space/guides/"))
        assertFalse(PokrovWebSurfacePolicy.initialUrlAllowed("http://app.pokrov.space/"))
        assertFalse(PokrovWebSurfacePolicy.initialUrlAllowed("https://pokrov.space.evil.example/"))
        assertFalse(PokrovWebSurfacePolicy.initialUrlAllowed("file:///data/local/tmp/token"))
    }

    @Test
    fun keepsOwnedPagesInAppAndHandsNativeOrPaymentDestinationsOut() {
        assertEquals(
            PokrovWebNavigationDecision.IN_APP,
            PokrovWebSurfacePolicy.decision("https://app.pokrov.space/subscription/"),
        )
        assertEquals(
            PokrovWebNavigationDecision.EXTERNAL,
            PokrovWebSurfacePolicy.decision("https://pay.lava.top/checkout/opaque"),
        )
        assertEquals(
            PokrovWebNavigationDecision.EXTERNAL,
            PokrovWebSurfacePolicy.decision("tg://resolve?domain=pokrov_vpnbot"),
        )
        assertEquals(
            PokrovWebNavigationDecision.BLOCK,
            PokrovWebSurfacePolicy.decision("javascript:alert(1)"),
        )
    }
}
