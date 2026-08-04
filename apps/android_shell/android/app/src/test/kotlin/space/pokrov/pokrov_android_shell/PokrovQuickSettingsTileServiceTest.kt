package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class PokrovQuickSettingsTileServiceTest {
    @Before
    fun resetTransitionGate() {
        QuickTileTransitionGate.resetForTest()
    }

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
    fun confirmedFreshProfileStartsWithoutOpeningFlutter() {
        assertEquals(
            QuickTileAction.START,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                quickSettingsEligible = true,
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
        assertEquals(
            QuickTileAction.OPEN_APP,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                quickSettingsEligible = true,
                vpnPermissionRequired = false,
                notificationPermissionRequestRequired = true,
            ),
        )
    }

    @Test
    fun runningSnapshotClickResolvesToStopNeverStart() {
        assertEquals(
            QuickTileAction.STOP,
            resolveQuickTileAction(
                isRunning = true,
                hasStagedProfile = false,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun pendingConnectionClickResolvesToStopAndVisualStaysClickable() {
        assertEquals(
            QuickTileAction.STOP,
            resolveQuickTileAction(
                isRunning = false,
                connectionPending = true,
                hasStagedProfile = true,
                vpnPermissionRequired = false,
            ),
        )
        assertEquals(
            QuickTileVisualState.PENDING,
            resolveQuickTileVisualState(isRunning = false, connectionPending = true),
        )
    }

    @Test
    fun repeatedStartIsBlockedButPendingStartCanBeSupersededByStop() {
        val startGeneration = requireNotNull(QuickTileTransitionGate.begin(QuickTileAction.START))
        assertNull(QuickTileTransitionGate.begin(QuickTileAction.START))

        val stopGeneration = requireNotNull(QuickTileTransitionGate.begin(QuickTileAction.STOP))
        QuickTileTransitionGate.complete(startGeneration)
        assertNull(QuickTileTransitionGate.begin(QuickTileAction.START))

        QuickTileTransitionGate.complete(stopGeneration)
        assertNotNull(QuickTileTransitionGate.begin(QuickTileAction.START))
    }

    @Test
    fun visualStateTracksAuthoritativeRunningState() {
        assertEquals(
            QuickTileVisualState.ACTIVE,
            resolveQuickTileVisualState(isRunning = true, connectionPending = false),
        )
        assertEquals(
            QuickTileVisualState.INACTIVE,
            resolveQuickTileVisualState(isRunning = false, connectionPending = false),
        )
    }

    @Test
    fun legacyOrUnconfirmedProfileCannotStartFromQuickSettings() {
        val legacyPathOnlyProfile = PersistedRuntimeProfile(
            configPath = "/tmp/legacy-profile.json",
        )
        assertEquals(
            QuickTileAction.OPEN_APP,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                quickSettingsEligible = legacyPathOnlyProfile.canStartFromQuickSettings(),
                vpnPermissionRequired = false,
            ),
        )
        assertEquals(
            QuickTileAction.START,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                quickSettingsEligible = PersistedRuntimeProfile(
                    configPath = "/tmp/fresh-profile.json",
                    routeMode = "device",
                    quickSettingsEligible = true,
                ).canStartFromQuickSettings(),
                vpnPermissionRequired = false,
            ),
        )
    }
}
