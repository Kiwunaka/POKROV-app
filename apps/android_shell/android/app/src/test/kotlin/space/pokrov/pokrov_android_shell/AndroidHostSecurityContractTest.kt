package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidHostSecurityContractTest {
    @Test
    fun runtimeFailureCategoriesNeverExposeExceptionMessages() {
        val hostile = IllegalStateException(
            "token=secret server=10.0.0.1",
            IllegalArgumentException("vless://private"),
        )

        assertEquals("invalid_runtime_state", AndroidRuntimeSafety.safeFailureCategory(hostile))
        assertFalse(AndroidRuntimeSafety.safeFailureCategory(hostile).contains("secret"))
        assertEquals(
            "IllegalStateException>IllegalArgumentException",
            AndroidRuntimeSafety.safeFailureTypes(hostile),
        )
        assertFalse(AndroidRuntimeSafety.safeFailureTypes(hostile).contains("vless"))
        assertEquals(
            "unknown,invalid,field,config,json,server,outbounds",
            AndroidRuntimeSafety.safeCoreFailureHints(
                IllegalStateException(
                    "invalid config json: unknown field outbounds token=secret server=10.0.0.1",
                ),
            ),
        )
        assertFalse(AndroidRuntimeSafety.safeCoreFailureHints(hostile).contains("secret"))
    }

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
            "vpn_permission_denied",
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
    fun androidRuntimeProtectsCoreUplinkSocketsFromVpnRecapture() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("route.put(\"auto_detect_interface\", false)"))
        assertTrue(serviceSource.contains("override fun autoDetectInterfaceControl(fd: Int)"))
        assertTrue(serviceSource.contains("val protected = protect(fd)"))
        assertTrue(serviceSource.contains("AndroidOperationalEvent.UPLINK_SOCKET"))
    }

    @Test
    fun androidRuntimeDiscardsArbitraryNativeDebugLines() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("override fun writeDebugMessage(_message: String)"))
        assertTrue(serviceSource.contains("lifecycle and egress results arrive through OperationalEventHandler"))
        assertFalse(serviceSource.contains("android.util.Log"))
        assertFalse(serviceSource.contains("Log."))
    }

    @Test
    fun nodeLatencyProbeBindsToAValidatedNonVpnNetwork() {
        val probeSource = source("AndroidNodeLatencyProbe.kt")
        val bridgeSource = source("RuntimeHostBridge.kt")

        assertTrue(bridgeSource.contains("METHOD_MEASURE_NODE_LATENCIES"))
        assertTrue(probeSource.contains("NET_CAPABILITY_NOT_VPN"))
        assertTrue(probeSource.contains("NET_CAPABILITY_VALIDATED"))
        assertTrue(probeSource.contains("network.bindSocket(socket)"))
        assertTrue(probeSource.contains("firstOrNull(::isPublicAddress)"))
    }

    @Test
    fun quickSettingsTilePublishesTheObservedRuntimeState() {
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertTrue(tileSource.contains("Tile.STATE_ACTIVE else Tile.STATE_INACTIVE"))
        assertTrue(tileSource.contains("if (running) \"Включен\" else \"Выключен\""))
        assertTrue(tileSource.contains("snapshot.isRunning || runtimeServiceRunning"))
        assertTrue(tileSource.contains("authoritativeRuntimeSnapshot().isRunning || isRuntimeServiceRunning()"))
        assertTrue(tileSource.contains("getRunningServices(Int.MAX_VALUE)"))
        assertFalse(tileSource.contains("Tile.STATE_UNAVAILABLE"))
    }

    @Test
    fun standardTileRefreshesWhenSystemUiListensAndRuntimeCommits() {
        val tileSource = source("PokrovQuickSettingsTileService.kt")
        val activitySource = source("MainActivity.kt")

        assertTrue(tileSource.contains("override fun onStartListening()"))
        assertTrue(tileSource.contains("refreshTile()"))
        assertTrue(tileSource.contains("requestListeningState("))
        assertTrue(tileSource.contains("firstInstallTime != packageInfo.lastUpdateTime"))
        assertTrue(tileSource.contains("PackageManager.DONT_KILL_APP"))
        assertTrue(activitySource.contains("ensureActiveModeRegistration(this)"))
        assertTrue(activitySource.contains("PokrovQuickSettingsTileService.requestRefresh(this)"))
    }

    @Test
    fun quickSettingsRefreshFollowsCommittedRuntimeState() {
        val runtimeSource = source("PokrovRuntimeVpnService.kt")
        val startState = runtimeSource.indexOf("AndroidRuntimeState.markRunning(runtimeMessage)")
        val startRefresh = runtimeSource.indexOf(
            "PokrovQuickSettingsTileService.completeRuntimeTransition(\n            this,",
            startState,
        )
        val stopState = runtimeSource.indexOf("AndroidRuntimeState.markStopped(message = message")
        val stopRefresh = runtimeSource.indexOf(
            "PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)",
            stopState,
        )

        assertTrue(startState >= 0 && startRefresh > startState)
        assertTrue(stopState >= 0 && stopRefresh > stopState)

        val dispatchSource = runtimeSource.substring(
            runtimeSource.indexOf("fun start(\n            context: Context"),
        )
        assertFalse(
            dispatchSource.substringBefore("fun stop(").contains(
                "PokrovQuickSettingsTileService.requestRefresh(context)",
            ),
        )
        assertFalse(
            dispatchSource.substringAfter("fun stop(").substringBefore("fun refreshNotification(").contains(
                "PokrovQuickSettingsTileService.requestRefresh(context)",
            ),
        )
    }

    @Test
    fun completedTileTransitionReleasesTheClickGate() {
        val tileSource = source("PokrovQuickSettingsTileService.kt")

        assertTrue(tileSource.contains("QuickTileTransitionGate.complete(generation)"))
        assertTrue(tileSource.contains("requestRefresh(context)"))
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
        assertTrue(serviceSource.contains("commandServer = nextServer"))
        assertTrue(serviceSource.contains("AndroidCoreOperationalEvents.beginRun("))
        assertTrue(serviceSource.contains("nextServer.start()"))
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
        assertTrue(serviceSource.contains("AndroidRuntimeState.markDnsTransportFailure(failureKind, failureMessage)"))
        assertTrue(serviceSource.contains("runCatching { commandServer?.resetNetwork() }"))
        assertTrue(serviceSource.contains("Keep the TUN up (which remains fail-closed)"))
        assertFalse(serviceSource.contains("Android DNS transport failed; stopping runtime."))
        assertFalse(resolverSource.contains("android.util.Log"))
        assertFalse(serviceSource.contains("Log."))
    }

    @Test
    fun defaultNetworkInterfaceResolutionAndNativePublishRunOffCallbackThread() {
        val monitorSource = source("AndroidDefaultNetworkMonitor.kt")
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(monitorSource.contains("Executors.newSingleThreadExecutor()"))
        assertTrue(monitorSource.contains("submitInterfaceResolution"))
        assertTrue(monitorSource.contains("interfaceListenerExecutor"))
        assertTrue(monitorSource.contains("submitInterfaceListenerUpdate {"))
        assertTrue(monitorSource.contains("targetListener.updateDefaultInterface("))
        assertTrue(monitorSource.contains("shouldReloadRuntimeForInterfaceChange("))
        assertTrue(serviceSource.contains("reloadActiveRuntimeAfterDefaultNetworkChange()"))
        assertTrue(serviceSource.contains("server.startOrReloadService(content, OverrideOptions())"))
        assertTrue(monitorSource.contains("shutdownNow()"))
        assertTrue(monitorSource.contains("canPublishNetworkResolution("))
    }

    @Test
    fun runtimeReplacementReleasesDnsCallbackBeforeOldResourcesClose() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("val session = replaceRuntimeSession()"))
        assertTrue(serviceSource.contains("cancelRuntimeSession()"))
        assertTrue(serviceSource.contains("releaseDnsFailureToken()"))
        assertTrue(serviceSource.contains("runCatching { activeTun?.close() }"))
        assertTrue(serviceSource.contains("val dnsFailureToken = dnsFailureTokenGate.activate()"))
        assertTrue(serviceSource.contains("!dnsFailureTokenGate.owns(token)"))
    }

    @Test
    fun lateEgressProbeUsesLifecycleAndGenerationGuardedDispatch() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")

        assertTrue(serviceSource.contains("lifecycleActive.set(false)"))
        assertTrue(serviceSource.contains("session.onCancel { mainHandler.removeCallbacks(watchdog) }"))
        assertTrue(serviceSource.contains("session.execute {"))
        assertTrue(serviceSource.contains("ownsRuntimeSession(session)"))
        assertTrue(serviceSource.contains("AndroidRuntimeDispatchPolicy.dispatch("))
        assertTrue(serviceSource.contains("healthGeneration.get() == generation"))

        val probeStart = serviceSource.indexOf("private fun scheduleCoreEgressProbe(")
        val requiredEvent = serviceSource.indexOf(
            "AndroidOperationalOutcome.REQUIRED,\n            generation,",
            probeStart,
        )
        val probeResult = serviceSource.indexOf("private fun handleCoreEgressProbeResult(")
        assertTrue(probeStart >= 0)
        assertTrue(requiredEvent > probeStart)
        assertTrue(probeResult > requiredEvent)
    }

    @Test
    fun installedAppCatalogKeepsEveryLauncherSearchableAndBoundsIconWork() {
        val bridgeSource = source("RuntimeHostBridge.kt")

        assertTrue(bridgeSource.contains(".mapIndexed { index, (packageName, label, resolveInfo) ->"))
        assertTrue(bridgeSource.contains("if (index < MAX_INSTALLED_APP_ICONS)"))
        assertFalse(bridgeSource.contains(".take(160)"))
    }

    @Test
    fun accountDeviceNameUsesSafeManufacturerAndModelInsteadOfLocalhost() {
        val bridgeSource = source("RuntimeHostBridge.kt")

        assertTrue(bridgeSource.contains("METHOD_DEVICE_NAME -> result.success(deviceName())"))
        assertTrue(bridgeSource.contains("Build.MANUFACTURER.trim()"))
        assertTrue(bridgeSource.contains("Build.MODEL.trim()"))
        assertTrue(bridgeSource.contains(".take(80)"))
    }

    @Test
    fun updateDiscoveryReportsOnlySupportedSplitApkAbis() {
        val bridgeSource = source("RuntimeHostBridge.kt")

        assertTrue(bridgeSource.contains("METHOD_SUPPORTED_ABIS -> result.success(supportedAbis())"))
        assertTrue(bridgeSource.contains("Build.SUPPORTED_ABIS"))
        assertTrue(bridgeSource.contains("setOf(\"arm64-v8a\", \"armeabi-v7a\", \"x86_64\")"))
        assertFalse(bridgeSource.contains("SUPPORTED_UPDATE_ABIS = setOf(\"universal\""))
    }

    @Test
    fun foregroundNotificationIsPrivateAndTunMtuFailsClosed() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val preferencesSource = source("AndroidSystemSurfacePreferences.kt")

        assertTrue(serviceSource.contains("Notification.VISIBILITY_PRIVATE"))

        val startAction = serviceSource.indexOf("ACTION_START ->")
        val foregroundStart = serviceSource.indexOf("beginForegroundRuntime()", startAction)
        val missingConfigGuard = serviceSource.indexOf("if (configPath.isNullOrBlank())", startAction)
        assertTrue(startAction >= 0)
        assertTrue(foregroundStart > startAction)
        assertTrue(missingConfigGuard > foregroundStart)
        assertTrue(serviceSource.contains("NotificationCompat.VISIBILITY_PRIVATE"))
        assertFalse(serviceSource.contains("VISIBILITY_PUBLIC"))
        assertFalse(serviceSource.contains("TrafficStats"))
        assertTrue(serviceSource.contains("AndroidTunMtuPolicy.select("))
        assertTrue(serviceSource.contains("activePlatformInterfaceMtu()"))
        assertFalse(serviceSource.contains(".put(\"mtu\", 9000)"))
        assertTrue(preferencesSource.contains("val showCountry: Boolean = false"))
        assertTrue(preferencesSource.contains("val showSpeed: Boolean = false"))
        assertTrue(preferencesSource.contains("val showRouteMode: Boolean = false"))
        assertTrue(preferencesSource.contains(".putBoolean(KEY_SHOW_COUNTRY, false)"))
    }

    @Test
    fun sessionScopeOwnsCoreTrafficAndAllFormerRawBridgeJobs() {
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val bridgeSource = source("RuntimeHostBridge.kt")
        val trafficSource = source("AndroidTunnelTraffic.kt")
        val activitySource = source("MainActivity.kt")
        val installerSource = sourceAt(
            "src/direct/kotlin/space/pokrov/pokrov_android_shell/" +
                "AndroidClientUpdateInstaller.kt",
        )

        assertTrue(serviceSource.contains("AndroidLifecycleTaskScope("))
        assertTrue(serviceSource.contains("AndroidRuntimeState.beginTunnelTrafficSession(scope.generation)"))
        assertTrue(serviceSource.contains("AndroidRuntimeState.endTunnelTrafficSession(scope.generation)"))
        assertTrue(serviceSource.contains("startTunnelTrafficMonitor(session)"))
        assertTrue(serviceSource.contains("override fun onDestroy()"))
        assertTrue(serviceSource.contains("cancelRuntimeSession()"))
        assertFalse(serviceSource.contains("healthExecutor"))

        assertTrue(trafficSource.contains("addCommand(Libbox.CommandStatus)"))
        assertTrue(trafficSource.contains("status.getUplinkTotal()"))
        assertTrue(trafficSource.contains("status.getDownlinkTotal()"))
        assertFalse(trafficSource.contains("TrafficStats"))

        assertTrue(bridgeSource.contains("private val hostTaskScope = AndroidLifecycleTaskScope("))
        assertTrue(bridgeSource.contains("hostTaskScope.close()"))
        assertTrue(bridgeSource.contains("shouldContinue = hostTaskScope::isActive"))
        assertFalse(
            bridgeSource.lineSequence().any { line ->
                line.trimStart().startsWith("Thread {")
            },
        )
        assertTrue(activitySource.contains("runtimeHostBridge?.close()"))
        assertTrue(installerSource.contains("requireActive(shouldContinue)"))
    }

    @Test
    fun operationalJournalIsPrivateBoundedAndWiredToClosedAndroidProducers() {
        val journalSource = source("AndroidOperationalJournal.kt")
        val serviceSource = source("PokrovRuntimeVpnService.kt")
        val bridgeSource = source("RuntimeHostBridge.kt")
        val monitorSource = source("AndroidDefaultNetworkMonitor.kt")
        val installerSource = sourceAt(
            "src/direct/kotlin/space/pokrov/pokrov_android_shell/" +
                "AndroidClientUpdateInstaller.kt",
        )

        assertTrue(journalSource.contains("context.applicationContext.noBackupFilesDir"))
        assertTrue(journalSource.contains("ArrayBlockingQueue(256)"))
        assertTrue(journalSource.contains("DEFAULT_MAX_FILE_BYTES = 256L * 1024L"))
        assertTrue(journalSource.contains("android-operational-v1.previous.jsonl"))
        assertFalse(journalSource.contains("val message:"))
        assertFalse(journalSource.contains("val url:"))
        assertFalse(journalSource.contains("val profile:"))
        assertFalse(journalSource.contains("val token:"))
        assertTrue(serviceSource.contains("AndroidOperationalOutcome.TUN_ESTABLISHED"))
        assertTrue(bridgeSource.contains("AndroidOperationalEvent.VPN_PERMISSION"))
        assertTrue(monitorSource.contains("AndroidOperationalEvent.NETWORK_CALLBACK"))
        assertTrue(journalSource.contains("AndroidOperationalEvent.DOZE"))
        assertTrue(journalSource.contains("AndroidOperationalEvent.APP_STANDBY"))
        assertTrue(journalSource.contains("AndroidOperationalEvent.MAIN_THREAD_WATCHDOG"))
        assertTrue(installerSource.contains("AndroidOperationalEvent.UPDATER_IDENTITY"))
    }

    @Test
    fun supportExportUsesSystemDocumentPickerAndAcceptsOnlyEncryptedEnvelope() {
        val activitySource = source("MainActivity.kt")

        assertTrue(activitySource.contains("space.pokrov/support-export"))
        assertTrue(activitySource.contains("saveEncryptedBundle"))
        assertTrue(activitySource.contains("Intent.ACTION_CREATE_DOCUMENT"))
        assertTrue(activitySource.contains("application/vnd.pokrov.support-bundle+json"))
        assertTrue(activitySource.contains("isEncryptedSupportEnvelope(bytes"))
        assertTrue(activitySource.contains("X25519-HKDF-SHA256-AES-256-GCM"))
        assertTrue(activitySource.contains("SUPPORT_EXPORT_NAME"))
        assertTrue(activitySource.contains("output.write(pending.bytes)"))
        assertTrue(activitySource.contains("pending.bytes.fill(0)"))
        assertFalse(activitySource.contains("connection_state\""))
        assertFalse(activitySource.contains("files\""))
    }

    private fun source(fileName: String): String {
        return sourceAt("src/main/kotlin/space/pokrov/pokrov_android_shell/$fileName")
    }

    private fun sourceAt(relativePath: String): String {
        return File(relativePath)
            .readText()
            .replace("\r\n", "\n")
    }
}
