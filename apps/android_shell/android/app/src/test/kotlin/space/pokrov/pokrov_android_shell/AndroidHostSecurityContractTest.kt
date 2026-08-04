package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidHostSecurityContractTest {
    @Test
    fun managedProfileInvalidation_clearsQuickSettingsReuseWithoutStoppingRuntime() {
        val bridgeSource = source("RuntimeHostBridge.kt")
        val runtimeStateSource = source("AndroidRuntimeState.kt")

        assertTrue(bridgeSource.contains("METHOD_INVALIDATE_MANAGED_PROFILE"))
        assertTrue(bridgeSource.contains("AndroidRuntimeProfileStore.clear(activity)"))
        assertTrue(bridgeSource.contains("AndroidRuntimeState.invalidateStagedProfile()"))
        assertTrue(runtimeStateSource.contains("if (phase != AndroidRuntimePhase.RUNNING)"))
    }

    @Test
    fun exportedActivity_hasNoIntentExtraThatCanAutoConnect() {
        val activitySource = source("MainActivity.kt")
        val bridgeSource = source("RuntimeHostBridge.kt")
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertFalse(activitySource.contains("handleSystemIntent"))
        assertFalse(bridgeSource.contains("handleSystemIntent"))
        assertFalse(bridgeSource.contains("EXTRA_TILE_CONNECT"))
        assertFalse(tileSource.contains("EXTRA_TILE_CONNECT"))
        assertTrue(tileSource.contains("PokrovRuntimeVpnService.start("))
        assertTrue(tileSource.contains("PokrovRuntimeVpnService.stop("))
    }

    @Test
    fun publicRuntimeFailures_neverContainNativeProfileDetails() {
        val details = listOf(
            "vless://user:secret@example.invalid:443",
            "uuid=123e4567-e89b-12d3-a456-426614174000",
            "private_key=very-secret-key",
            "token=very-secret-token",
            "node.example.invalid",
        )
        val failureKinds = listOf(
            "runtime_initialization_failed",
            "runtime_start_after_permission_failed",
            "runtime_start_failed",
            "runtime_service_start_failed",
            "foreground_start_failed",
            "runtime_stop_failed",
            "profile_staging_failed",
            "config_apply_failed",
            "core_egress_probe_unavailable",
            "notification_permission_denied",
            "resolver_response_error",
            "resolver_callback_error",
            "resolver_timeout",
        )

        for (kind in failureKinds) {
            val message = AndroidRuntimeSafety.publicFailureMessage(kind)
            for (detail in details) {
                assertFalse("$kind leaked $detail", message.contains(detail))
            }
        }
    }

    @Test
    fun hostSources_doNotLogOrSurfaceArbitraryNativeDetails() {
        val bridgeSource = source("RuntimeHostBridge.kt")
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val resolverSource = source("AndroidLocalResolver.kt")
        val monitorSource = source("AndroidDefaultNetworkMonitor.kt")
        val stateSource = source("AndroidRuntimeState.kt")

        assertFalse(bridgeSource.contains("error.message"))
        assertFalse(serviceSource.contains("error.message"))
        assertFalse(serviceSource.contains("Log.d(LOG_TAG, message)"))
        assertFalse(serviceSource.contains("notification.getTitle()"))
        assertFalse(serviceSource.contains("notification.getBody()"))
        assertFalse(serviceSource.contains("configPath=$"))
        assertFalse(resolverSource.contains("domain=$"))
        assertFalse(resolverSource.contains("network=$"))
        assertFalse(resolverSource.contains("bytes=${'$'}"))
        assertFalse(monitorSource.contains("network=${'$'}{"))
        assertFalse(monitorSource.contains("interface=${'$'}"))
        assertFalse(stateSource.contains("Сеть ${'$'}interfaceName"))
    }

    @Test
    fun notificationPermission_isForwardedFromActivityAndRequestedByTheBridge() {
        val activitySource = source("MainActivity.kt")
        val bridgeSource = source("RuntimeHostBridge.kt")

        assertTrue(activitySource.contains("onRequestPermissionsResult("))
        assertTrue(activitySource.contains("runtimeHostBridge?.onRequestPermissionsResult"))
        assertTrue(bridgeSource.contains("Manifest.permission.POST_NOTIFICATIONS"))
        assertTrue(bridgeSource.contains("REQUEST_NOTIFICATION_PERMISSION"))
        assertTrue(bridgeSource.contains("notificationPermissionRequest"))
        assertTrue(
            bridgeSource.contains(
                "connect(checkNotificationPermission = false, pendingRequest = pending)",
            ),
        )
        assertTrue(bridgeSource.contains("PokrovRuntimeVpnService.start("))
        assertTrue(bridgeSource.contains("profile?.routeMode.orEmpty()"))
    }

    @Test
    fun quickSettingsUsesAuthoritativeRuntimeStateForStopBeforeStart() {
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertTrue(tileSource.contains("AndroidRuntimeState.snapshot()"))
        assertTrue(tileSource.contains("isRunning = snapshot.isRunning"))
        assertTrue(tileSource.contains("QuickTileAction.STOP -> beginTransition(QuickTileAction.STOP)"))
        assertTrue(tileSource.contains("PokrovRuntimeVpnService.stop(this, generation)"))
        assertTrue(tileSource.contains("QuickTileAction.START -> beginTransition(QuickTileAction.START)"))
        assertTrue(tileSource.contains("EXTRA_TILE_TRANSITION_GENERATION"))
    }

    @Test
    fun coreEgressFailCloseSynchronouslyErasesQuickSettingsReuse() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val storeSource = source("AndroidRuntimeProfileStore.kt")
        val stateSource = source("AndroidRuntimeState.kt")

        assertTrue(serviceSource.contains("failClosedAfterCoreEgressFailure("))
        assertTrue(storeSource.contains(".commit()"))
        assertTrue(storeSource.contains("AndroidRuntimeState.markStoppedAfterCoreEgressFailure("))
        assertTrue(stateSource.contains("stagedConfigPath = null"))
        assertTrue(serviceSource.contains("AndroidCoreEgressProbeResult.UNAVAILABLE"))
    }

    @Test
    fun pendingQuickSettingsTileStaysClickableToCancelConnection() {
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertTrue(tileSource.contains("QuickTileVisualState.PENDING -> {"))
        assertTrue(tileSource.contains("tile.state = Tile.STATE_ACTIVE"))
        assertTrue(tileSource.contains("Нажмите, чтобы отменить."))
        assertFalse(tileSource.contains("Tile.STATE_UNAVAILABLE"))
    }

    @Test
    fun permissionCallbackCannotResurrectConnectionCancelledByTheTile() {
        val bridgeSource = source("RuntimeHostBridge.kt")
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertTrue(bridgeSource.contains("AndroidRuntimeState.isConnectionPending()"))
        assertTrue(tileSource.contains("AndroidRuntimeState.markStopRequested(stopReason = \"quick_settings\")"))
    }

    @Test
    fun directServiceDispatchAndFailedStartupReleaseTheirOwnedResources() {
        val bridgeSource = source("RuntimeHostBridge.kt")
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val stateSource = source("AndroidRuntimeState.kt")

        assertTrue(bridgeSource.contains("clearPendingConnect(pending)\n        return AndroidRuntimeState.snapshot()"))
        assertTrue(serviceSource.contains("commandServer = nextServer\n            nextServer.start()"))
        assertTrue(serviceSource.contains("cleanupFailedStartup()"))
        assertTrue(serviceSource.contains("runCatching { commandServer?.closeService() }"))
        assertTrue(serviceSource.contains("runCatching { commandServer?.close() }"))
        assertTrue(serviceSource.contains("activeTun = null"))
        assertTrue(stateSource.contains("connectionPending = false\n            lastFailureKind = \"runtime_initialization_failed\""))
    }

    @Test
    fun DNSAndDefaultNetworkSourceContractsFailCloseOnlyTransportFailures() {
        val resolverSource = source("AndroidLocalResolver.kt")
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(resolverSource.contains("if (signal.isCanceled)"))
        assertTrue(resolverSource.contains("reportTransportFailure(AndroidResolverPolicy.TIMEOUT, runtimeToken)"))
        assertTrue(resolverSource.contains("AndroidResolverPolicy.shouldFailCloseRuntime(outcome)"))
        assertTrue(serviceSource.contains("reportDnsTransportFailure(token: Any, failureKind: String)"))
        assertTrue(serviceSource.contains("stopRuntime("))
        assertTrue(serviceSource.contains("stopReason = failureKind"))
        assertTrue(serviceSource.contains("failureKind = failureKind"))
    }

    @Test
    fun defaultNetworkInterfaceResolutionRunsOffCallbackThreadAndFencesStaleResults() {
        val monitorSource = source("AndroidDefaultNetworkMonitor.kt")

        assertTrue(monitorSource.contains("Executors.newSingleThreadExecutor()"))
        assertTrue(monitorSource.contains("submitInterfaceResolution"))
        assertTrue(monitorSource.contains("shutdownNow()"))
        assertTrue(monitorSource.contains("canPublishNetworkResolution("))
    }

    @Test
    fun runtimeReplacementReleasesDnsCallbackBeforeOldResourcesClose() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("healthGeneration.incrementAndGet()\n        releaseDnsFailureToken()\n        runCatching { activeTun?.close() }"))
        assertTrue(serviceSource.contains("val dnsFailureToken = dnsFailureTokenGate.activate()"))
        assertTrue(serviceSource.contains("!dnsFailureTokenGate.owns(token)"))
    }

    @Test
    fun lateEgressProbeUsesLifecycleAndGenerationGuardedDispatch() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("lifecycleActive.set(false)"))
        assertTrue(serviceSource.contains("AndroidRuntimeDispatchPolicy.dispatch("))
        assertTrue(serviceSource.contains("lifecycleActive.get() && healthGeneration.get() == generation"))
    }

    private fun source(fileName: String): String {
        return File("src/main/kotlin/space/pokrov/pokrov_android_shell/$fileName").readText()
    }
}
