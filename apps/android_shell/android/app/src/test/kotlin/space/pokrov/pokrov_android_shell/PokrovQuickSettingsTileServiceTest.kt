package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class PokrovQuickSettingsTileServiceTest {
    @Test
    fun runningTunnelAlwaysStops() {
        assertEquals(
            QuickTileAction.STOP,
            resolveQuickTileAction(
                isRunning = true,
                hasStagedProfile = true,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun readyProfileStartsWithoutOpeningFlutter() {
        assertEquals(
            QuickTileAction.START,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun missingProfileOrPermissionOpensApp() {
        assertEquals(
            QuickTileAction.OPEN_APP,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = false,
                vpnPermissionRequired = false,
            ),
        )
        assertEquals(
            QuickTileAction.OPEN_APP,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                vpnPermissionRequired = true,
            ),
        )
    }
}
