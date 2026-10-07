package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class PokrovQuickSettingsTileServiceTest {
    @Test
    fun coreEgressProbeDefaultsClosedAndSkipsOnlyMatchingBoundProofProfile() {
        val ordinary = PersistedRuntimeProfile(configPath = "/private/ordinary.json")
        val boundProof = PersistedRuntimeProfile(
            configPath = "/private/boundProof.json",
            coreEgressProbeRequired = false,
        )

        assertEquals(true, coreEgressProbeRequiredForRuntime(null, ordinary.configPath))
        assertEquals(true, coreEgressProbeRequiredForRuntime(ordinary, ordinary.configPath))
        assertEquals(true, coreEgressProbeRequiredForRuntime(boundProof, ordinary.configPath))
        assertEquals(false, coreEgressProbeRequiredForRuntime(boundProof, boundProof.configPath))
    }

    @Test
    fun staleStopCommandCannotDropForegroundOwnedByNewStart() {
        assertEquals(true, ownsLatestRuntimeServiceCommand(null, 3L))
        assertEquals(true, ownsLatestRuntimeServiceCommand(3L, 3L))
        assertEquals(false, ownsLatestRuntimeServiceCommand(2L, 3L))
    }

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
    fun pendingConnectionClickResolvesToStop() {
        assertEquals(
            QuickTileAction.STOP,
            resolveQuickTileAction(
                isRunning = false,
                connectionPending = true,
                hasStagedProfile = true,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun repeatedStartIsBlockedAndStopIgnoresOtherCompletions() {
        val startGeneration = requireNotNull(QuickTileTransitionGate.begin(QuickTileAction.START))
        assertNull(QuickTileTransitionGate.begin(QuickTileAction.START))

        val stopGeneration = requireNotNull(QuickTileTransitionGate.begin(QuickTileAction.STOP))
        QuickTileTransitionGate.complete(startGeneration)
        QuickTileTransitionGate.complete(null)
        assertNull(QuickTileTransitionGate.begin(QuickTileAction.START))

        QuickTileTransitionGate.complete(stopGeneration)
        assertNotNull(QuickTileTransitionGate.begin(QuickTileAction.START))
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
                    lanScopeVersion = 1,
                    configDigest = "a".repeat(64),
                ).canStartFromQuickSettings(),
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun boundAndCatalogProfilesOpenAppInsteadOfBypassingRequestGuard() {
        val ordinary = PersistedRuntimeProfile(
            configPath = "/private/profile.json",
            routeMode = "device",
            quickSettingsEligible = true,
            lanScopeVersion = 1,
            configDigest = "a".repeat(64),
        )
        for (profile in listOf(
            ordinary.copy(requiresBoundConnect = true),
            ordinary.copy(catalogAppIdentityRequired = true),
        )) {
            assertEquals(
                QuickTileAction.OPEN_APP,
                resolveQuickTileAction(
                    isRunning = false,
                    hasStagedProfile = true,
                    quickSettingsEligible = profile.canStartFromQuickSettings(),
                    vpnPermissionRequired = false,
                ),
            )
        }
    }
}
