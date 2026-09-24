package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.net.Uri
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import java.io.ByteArrayOutputStream
import java.io.File
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal data class PendingRuntimeConnect(
    val id: Long,
    val configPath: String,
    val profileDigest: String,
    val clientRequestId: String? = null,
    val coreModuleSha256: String? = null,
    val deadline: AndroidConnectDeadline? = null,
)

/** Owns only consent callbacks; a dispatched service start must release it. */
internal class PendingRuntimeConnectGate {
    private var nextId = 0L
    private var current: PendingRuntimeConnect? = null

    @Synchronized
    fun acquire(configPath: String, profileDigest: String, clientRequestId: String? = null,
        coreModuleSha256: String? = null, deadline: AndroidConnectDeadline? = null): Pair<PendingRuntimeConnect, Boolean> {
        val existing = current
        if (existing != null && existing.configPath == configPath && existing.profileDigest == profileDigest &&
            existing.clientRequestId == clientRequestId && existing.coreModuleSha256 == coreModuleSha256 &&
            existing.deadline == deadline) {
            return existing to false
        }
        return PendingRuntimeConnect(id = ++nextId, configPath = configPath, profileDigest = profileDigest,
            clientRequestId = clientRequestId, coreModuleSha256 = coreModuleSha256, deadline = deadline).also {
            current = it
        } to true
    }

    @Synchronized
    fun isCurrent(pending: PendingRuntimeConnect): Boolean = current == pending

    @Synchronized
    fun ownsClientRequest(request: String): Boolean = current?.clientRequestId == request

    @Synchronized
    fun completeDispatch(pending: PendingRuntimeConnect) {
        if (current == pending) {
            current = null
        }
    }

    @Synchronized
    fun invalidate() {
        current = null
    }

    @Synchronized
    fun cancelClientRequest(request: String): Boolean {
        if (current?.clientRequestId != request) return false
        current = null
        return true
    }
}

class RuntimeHostBridge(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private val hostTaskScope = AndroidLifecycleTaskScope(
        generation = 1L,
        threadNamePrefix = "pokrov-host",
        parallelism = 4,
    )
    private var handledDebugPath: String? = null
    private val pendingConnectLock = Any()
    private val pendingConnectGate = PendingRuntimeConnectGate()
    private val connectDeadlineHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var pendingConnectDeadlineWatchdog: Runnable? = null
    private var notificationPermissionRequest: PendingRuntimeConnect? = null
    private var vpnPermissionRequest: PendingRuntimeConnect? = null
    @Volatile
    private var updateDownloadInProgress = false
    @Volatile
    private var pendingVerifiedUpdate: AndroidVerifiedClientUpdate? = null
    @Volatile
    private var updateDownloadProgress = AndroidClientUpdateProgress.idle()
    private val catalogIdentityResolver = lazy { AndroidCatalogIdentityResolver(activity) }
    private val transportNetworkContext = lazy { AndroidTransportNetworkContext(activity) }

    init {
        AndroidOperationalRuntime.start(activity)
    }

    fun close() {
        connectDeadlineHandler.removeCallbacksAndMessages(null)
        invalidatePendingConnect()
        if (transportNetworkContext.isInitialized()) {
            val network = transportNetworkContext.value
            if (!AndroidConnectRequestOwner.bridgeClosing(network)) network.close()
        }
        hostTaskScope.close()
        if (catalogIdentityResolver.isInitialized()) catalogIdentityResolver.value.close()
        updateDownloadInProgress = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "runtimeEngine.clockSnapshot" -> {
                try {
                    val bootCount = Settings.Global.getInt(activity.contentResolver, Settings.Global.BOOT_COUNT)
                    if (bootCount < 0) throw IllegalStateException()
                    result.success(mapOf("schema" to 1, "boot_ref" to "android:$bootCount",
                        "elapsed_ms" to android.os.SystemClock.elapsedRealtime(), "quantum_ms" to 1))
                } catch (_: Exception) {
                    result.error("runtime_clock_unavailable", "System clock unavailable.", null)
                }
            }
            METHOD_SNAPSHOT -> result.success(snapshot())
            "runtimeEngine.transportNetworkContext" -> {
                val reference = runCatching { transportNetworkContext.value.read() }.getOrNull()
                if (reference == null) result.error("network_context_unavailable", "Network context unavailable.", null)
                else result.success(mapOf("schema" to 1, "network_context_ref" to reference))
            }
            "runtimeEngine.snapshotForConnectRequest" -> snapshotForConnectRequest(call, result)
            METHOD_INITIALIZE -> result.success(initialize())
            METHOD_STAGE_MANAGED_PROFILE -> result.success(stageManagedProfile(call))
            METHOD_INVALIDATE_MANAGED_PROFILE -> result.success(invalidateManagedProfile())
            METHOD_CONNECT -> {
                val request = call.argument<Any>("requestId")
                if (request != null && (request !is String || !AndroidConnectRequestOwner.valid(request))) {
                    result.error("invalid_connect_request", "Invalid connection request.", null)
                } else {
                    val requestId = request as? String
                    if (AndroidConnectRequestOwner.blocksStart(requestId) ||
                        (requestId != null && !AndroidConnectRequestOwner.begin(requestId))) {
                        result.error("runtime_busy", "Stop the current request first.", null)
                        return
                    }
                    result.success(connect(clientRequestId = requestId))
                }
            }
            "runtimeEngine.cancelConnectRequest" -> cancelConnectRequest(call, result)
            "runtimeEngine.cancelAndConfirmConnectStopped" -> cancelAndConfirmConnectStopped(call, result)
            "runtimeEngine.connectWithCoreIdentity" -> connectWithCoreIdentity(call, result)
            "runtimeEngine.promoteBoundTransportLease" -> promoteBoundTransportLease(call, result)
            "runtimeEngine.revokeBoundTransportLease" -> revokeBoundTransportLease(call, result)
            "runtimeEngine.revokeSmartAccessLease" -> revokeSmartAccessLease(call, result)
            "runtimeEngine.renewSmartAccessLease" -> renewSmartAccessLease(call, result)
            "runtimeEngine.configureSmartAccessRuntimeControl" -> configureSmartAccessRuntimeControl(call, result)
            "runtimeEngine.configureBoundSmartAccessRuntimeControl" -> configureSmartAccessRuntimeControl(call, result, bound = true)
            "runtimeEngine.configureSmartAccessRenewal" -> configureSmartAccessRuntimeControl(call, result, renewal = true)
            "runtimeEngine.readSmartAccessRestrictions" -> readSmartAccessRestrictions(call, result)
            "runtimeEngine.readSmartAccessLeases" -> readSmartAccessLeases(call, result)
            "runtimeEngine.acknowledgeSmartAccessRestrictions" -> acknowledgeSmartAccessRestrictions(call, result)
            "runtimeEngine.revokeRoutingCatalog" -> revokeRoutingCatalog(call, result)
            "runtimeEngine.revokeRoutingCatalogService" -> revokeRoutingCatalogService(call, result)
            "runtimeEngine.revokeSmartAccessPolicy" -> revokeSmartAccessPolicy(call, result)
            METHOD_DISCONNECT -> result.success(disconnect())
            METHOD_APPLY_WARP -> result.success(applyWarp(call))
            METHOD_LIVE_STATS -> result.success(AndroidRuntimeState.liveStats())
            METHOD_PUSH_TOKEN -> result.success(pushToken())
            METHOD_DEVICE_NAME -> result.success(deviceName())
            METHOD_SUPPORTED_ABIS -> result.success(supportedAbis())
            METHOD_LIST_INSTALLED_APPS -> listInstalledApps(result)
            "runtimeEngine.catalogAppIdentities" -> catalogAppIdentities(call, result)
            METHOD_CURRENT_WIFI -> result.success(currentWifi())
            METHOD_MEASURE_NODE_LATENCIES -> measureNodeLatencies(call, result)
            "runtimeEngine.observeNetworkContext" -> executeHostTask(result, emptyMap<String, Any?>()) {
                AndroidNetworkDiagnostics.observe(
                    activity, call.argument<String>("apiBaseUrl").orEmpty(),
                    call.argument<String>("sessionToken").orEmpty(),
                    call.argument<String>("appVersion").orEmpty(),
                    call.argument<String>("profileRevision").orEmpty(),
                    call.argument<String>("runtimePhase").orEmpty(),
                )
            }
            METHOD_MEASURE_LOCATION_VARIANTS -> measureLocationVariants(call, result)
            METHOD_REQUEST_WIFI_PERMISSION ->
                result.success(requestWifiPermission())
            METHOD_OPEN_VPN_SETTINGS -> result.success(openVpnSettings())
            METHOD_SYSTEM_SURFACE_PREFERENCES ->
                result.success(AndroidSystemSurfacePreferencesStore.load(activity).toMap())
            METHOD_UPDATE_SYSTEM_SURFACE_PREFERENCES ->
                result.success(updateSystemSurfacePreferences())
            METHOD_OPEN_NOTIFICATION_SETTINGS -> result.success(openNotificationSettings())
            METHOD_OPEN_IN_APP_WEB_SURFACE -> result.success(openInAppWebSurface(call))
            METHOD_CLIENT_UPDATE_PROGRESS -> result.success(updateDownloadProgress.toMap())
            METHOD_INSTALL_CLIENT_UPDATE -> installClientUpdate(call, result)
            else -> result.notImplemented()
        }
    }

    fun resumePendingUpdateInstall() {
        val update = pendingVerifiedUpdate ?: return
        if (!AndroidClientUpdateInstaller.canResumePendingInstall(activity)) {
            return
        }
        val status = AndroidClientUpdateInstaller.openInstaller(activity, update)
        recordUpdateHandoff(status)
        if (status == AndroidClientUpdateInstaller.STATUS_INSTALLER_OPENED ||
            status == AndroidClientUpdateInstaller.STATUS_STORE_OPENED ||
            status == AndroidClientUpdateInstaller.STATUS_FAILED
        ) {
            pendingVerifiedUpdate = null
        }
    }

    private fun installClientUpdate(call: MethodCall, result: MethodChannel.Result) {
        val request = AndroidClientUpdateInstaller.validateRequest(
            url = call.argument<String>("url"),
            sha256 = call.argument<String>("sha256"),
            size = call.argument<Number>("size"),
            channel = call.argument<String>("channel"),
            version = call.argument<String>("version"),
        )
        if (request == null) {
            result.success(mapOf("status" to AndroidClientUpdateInstaller.STATUS_FAILED))
            return
        }
        synchronized(this) {
            if (updateDownloadInProgress) {
                result.success(mapOf("status" to AndroidClientUpdateInstaller.STATUS_FAILED))
                return
            }
            updateDownloadInProgress = true
            updateDownloadProgress = AndroidClientUpdateProgress(
                phase = "preparing",
                downloadedBytes = 0L,
                totalBytes = request.size,
            )
        }
        val accepted = hostTaskScope.execute {
            val update = runCatching {
                AndroidClientUpdateInstaller.downloadVerified(
                    activity = activity,
                    request = request,
                    onProgress = { progress ->
                        if (hostTaskScope.isActive()) {
                            updateDownloadProgress = progress
                        }
                    },
                    shouldContinue = hostTaskScope::isActive,
                )
            }.getOrNull()
            activity.runOnUiThread {
                if (!hostTaskScope.isActive()) {
                    return@runOnUiThread
                }
                val status = if (update == null) {
                    AndroidClientUpdateInstaller.STATUS_FAILED
                } else {
                    val verifiedBytes = if (update.apk == null) 0L else request.size
                    updateDownloadProgress = AndroidClientUpdateProgress(
                        phase = "installing",
                        downloadedBytes = verifiedBytes,
                        totalBytes = request.size,
                    )
                    AndroidClientUpdateInstaller.openInstaller(activity, update)
                }
                recordUpdateHandoff(status)
                pendingVerifiedUpdate = if (
                    status == AndroidClientUpdateInstaller.STATUS_PERMISSION_REQUIRED
                ) update else null
                updateDownloadInProgress = false
                if (status == AndroidClientUpdateInstaller.STATUS_FAILED) {
                    updateDownloadProgress = AndroidClientUpdateProgress(
                        phase = "failed",
                        downloadedBytes = updateDownloadProgress.downloadedBytes,
                        totalBytes = request.size,
                    )
                }
                result.success(mapOf("status" to status))
            }
        }
        if (!accepted) {
            updateDownloadInProgress = false
            updateDownloadProgress = AndroidClientUpdateProgress(
                phase = "failed",
                downloadedBytes = 0L,
                totalBytes = request.size,
            )
            recordUpdateHandoff(AndroidClientUpdateInstaller.STATUS_FAILED)
            result.success(mapOf("status" to AndroidClientUpdateInstaller.STATUS_FAILED))
        }
    }

    private fun supportedAbis(): List<String> =
        Build.SUPPORTED_ABIS
            .map { it.trim().lowercase() }
            .filter { it in SUPPORTED_UPDATE_ABIS }
            .distinct()

    private fun openInAppWebSurface(call: MethodCall): Boolean =
        PokrovInAppWebSurface.open(
            activity = activity,
            url = call.argument<String>("url"),
            title = call.argument<String>("title"),
        )

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_VPN_PERMISSION) {
            return
        }
        val pending = takeVpnPermissionRequest() ?: return
        if (!isCurrentPendingConnect(pending)) {
            return
        }

        if (resultCode == Activity.RESULT_OK) {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.VPN_PERMISSION,
                AndroidOperationalOutcome.GRANTED,
            )
            if (pending.configPath != AndroidRuntimeState.stagedConfigPath()) {
                clearPendingConnect(pending)
                AndroidRuntimeState.markFailure(
                    kind = "missing_staged_config",
                    message = "Разрешение получено, но на устройстве еще нет настроек подключения.",
                )
                return
            }
            runCatching {
                val profile = AndroidRuntimeProfileStore.load(activity)
                PokrovRuntimeVpnService.start(
                    activity,
                    pending.configPath,
                    profile?.routeMode.orEmpty(),
                    pending.profileDigest,
                    connectRequestId = pending.clientRequestId,
                    expectedCoreModuleSha256 = pending.coreModuleSha256,
                    deadline = pending.deadline,
                )
            }.onFailure {
                AndroidRuntimeState.markFailure(
                    kind = "runtime_start_after_permission_failed",
                    message = AndroidRuntimeSafety.publicFailureMessage(
                        "runtime_start_after_permission_failed",
                    ),
                )
            }
            clearPendingConnect(pending)
            return
        }

        clearPendingConnect(pending)
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_PERMISSION,
            AndroidOperationalOutcome.DENIED,
        )
        AndroidRuntimeState.markFailure(
            kind = "vpn_permission_denied",
            message = "Разрешение отклонено, поэтому POKROV не смог подключиться на этом устройстве.",
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION ||
            !permissions.contains(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            return
        }
        val pending = takeNotificationPermissionRequest() ?: return
        if (!isCurrentPendingConnect(pending)) {
            return
        }
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (granted) {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.NOTIFICATION_PERMISSION,
                AndroidOperationalOutcome.GRANTED,
            )
            AndroidRuntimeState.clearSystemNotificationWarning()
        } else {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.NOTIFICATION_PERMISSION,
                AndroidOperationalOutcome.DENIED,
            )
            AndroidRuntimeState.markSystemNotificationWarning()
        }
        connect(checkNotificationPermission = false, pendingRequest = pending)
    }

    fun handleDebugIntent(intent: Intent?) {
        val isDebuggable =
            (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable || intent == null) {
            return
        }
        val debugConfigPath = intent.getStringExtra(EXTRA_DEBUG_RUNTIME_PATH)
            ?: return
        if (handledDebugPath == debugConfigPath) {
            return
        }
        if (!File(debugConfigPath).exists()) {
            AndroidRuntimeState.markFailure(
                kind = "debug_runtime_path_missing",
                message = "Debug runtime path does not exist: $debugConfigPath",
            )
            handledDebugPath = debugConfigPath
            return
        }
        AndroidRuntimeState.resolveEnvironment(activity) ?: return
        if (!AndroidRuntimeState.initialize(activity)) {
            handledDebugPath = debugConfigPath
            return
        }
        val currentSnapshot = AndroidRuntimeState.snapshot()
        if (
            currentSnapshot["phase"] == "running" &&
                currentSnapshot["stagedConfigPath"] == debugConfigPath
        ) {
            handledDebugPath = debugConfigPath
            return
        }
        AndroidRuntimeState.markProfileStaged(debugConfigPath)
        handledDebugPath = debugConfigPath
        if (intent.getBooleanExtra(EXTRA_DEBUG_AUTO_CONNECT, false)) {
            connect()
        }
    }

    private fun snapshot(): Map<String, Any?> {
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        refreshNotificationPermissionWarning()
        if (AndroidRuntimeState.resolveEnvironment(activity) == null) {
            return AndroidRuntimeState.snapshot()
        }
        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = PokrovRuntimeVpnService.isTunEstablished(),
            runningMessage = PokrovRuntimeVpnService.latestRuntimeMessage(),
        )
        AndroidRuntimeState.updateVpnValidation(AndroidVpnNetworkHealth.resolve(activity))
        return AndroidRuntimeState.snapshot()
    }

    private fun initialize(): Map<String, Any?> {
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        refreshNotificationPermissionWarning()
        AndroidRuntimeState.initialize(activity)
        return AndroidRuntimeState.snapshot()
    }

    private fun stageManagedProfile(call: MethodCall): Map<String, Any?> {
        invalidatePendingConnect()
        AndroidRuntimeState.cancelPendingConnection()
        val runtimeEnvironment = AndroidRuntimeState.resolveEnvironment(activity)
            ?: return snapshot()
        initialize()

        val profileName = call.argument<String>("profileName")
            ?: run {
                AndroidRuntimeState.markFailure(
                    kind = "missing_profile_name",
                    message = "Для этого шага настройки не хватает имени профиля POKROV.",
                )
                return AndroidRuntimeState.snapshot()
            }
        val configPayload = call.argument<String>("configPayload")
            ?: run {
                AndroidRuntimeState.markFailure(
                    kind = "missing_config_payload",
                    message = "Для этого шага настройки не хватает данных подключения POKROV.",
                )
                return AndroidRuntimeState.snapshot()
        }
        val materializedForRuntime = call.argument<Boolean>("materializedForRuntime") ?: false
        val routeMode = call.argument<String>("routeMode")
            ?.trim()
            ?.takeIf { it in setOf("allExceptRu", "fullTunnel", "selectedApps", "excludedApps", "selectiveServices") }
            ?: run {
                AndroidRuntimeState.markFailure(
                    kind = "missing_route_mode",
                    message = "Сначала обновите настройки POKROV и попробуйте подключиться еще раз.",
                )
                return AndroidRuntimeState.snapshot()
            }
        // Only Flutter can attest that the user has completed the first-connect
        // routing scope choice for this new managed manifest. Omitted/legacy
        // MethodChannel calls remain ineligible for Quick Settings reuse.
        val quickSettingsEligible = call.argument<Boolean>("quickSettingsEligible") == true
        val requiresBoundConnect = call.argument<Boolean>("requiresBoundConnect") == true
        val coreEgressProbeRequired =
            call.argument<Boolean>("coreEgressProbeRequired") != false
        val displayCountry = call.argument<String>("displayCountry")
            ?.trim()
            ?.take(64)
            .orEmpty()
        val displayNodeCode = call.argument<String>("displayNodeCode")
            ?.trim()
            ?.take(64)
            .orEmpty()
        val displayRouteMode = call.argument<String>("displayRouteMode")
            ?.trim()
            ?.takeIf { it in setOf("allExceptRu", "fullTunnel", "selectedApps", "excludedApps", "selectiveServices") }
            .orEmpty()
        val finalPath = File(runtimeEnvironment.configDirectory, "managed-profile.json")

        return try {
            if (!materializedForRuntime) {
                throw IllegalArgumentException(
                    "POKROV Core requires a materialized sing-box profile.",
                )
            }
            val serviceRouteMode = when (routeMode) {
                "selectedApps" -> "selected_apps"
                "excludedApps" -> "excluded_apps"
                else -> "device"
            }
            val profileDigest = runtimeProfileDigest(configPayload, serviceRouteMode, coreEgressProbeRequired)
            val expectedDigest = call.argument<String>("expectedProfileDigest")
            require(expectedDigest == null || expectedDigest == profileDigest) { "profile_identity_mismatch" }
            val catalogAppBinding = AndroidCatalogAppBinding.fromStage(profileDigest,
                call.argument<Any>("catalogAppDigest"), call.argument<Any>("catalogAppExpiresAt"),
                call.argument<Any>("catalogAppSigners"), call.argument<Any>("catalogAppLineages"), routeMode)
            // Persist reuse authority before replacing bytes at the shared path.
            // A failed disk commit must not leave ATS bytes under old metadata.
            AndroidCatalogAppBinding.clear()
            AndroidRuntimeProfileStore.save(
                activity,
                PersistedRuntimeProfile(
                    configPath = finalPath.absolutePath,
                    configDigest = profileDigest,
                    routeMode = serviceRouteMode,
                    quickSettingsEligible = quickSettingsEligible && catalogAppBinding == null,
                    requiresBoundConnect = requiresBoundConnect,
                    catalogAppIdentityRequired = catalogAppBinding != null,
                    lanScopeVersion = call.argument<Int>("lanScopeVersion") ?: 0,
                    coreEgressProbeRequired = coreEgressProbeRequired,
                    displayCountry = displayCountry,
                    displayNodeCode = displayNodeCode,
                    displayRouteMode = displayRouteMode,
                ),
            )
            writePrivateConfig(finalPath, configPayload)
            AndroidRuntimeState.markProfileStaged(finalPath.absolutePath, profileDigest = profileDigest,
                requiresBoundConnect = requiresBoundConnect)
            AndroidCatalogAppBinding.publish(catalogAppBinding)
            AndroidRuntimeState.snapshot()
        } catch (error: Throwable) {
            AndroidRuntimeState.markFailure(
                kind = "profile_staging_failed",
                message = AndroidRuntimeSafety.publicFailureMessage("profile_staging_failed"),
            )
            AndroidRuntimeState.snapshot()
        }
    }

    private fun connect(
        checkNotificationPermission: Boolean = true,
        pendingRequest: PendingRuntimeConnect? = null,
        clientRequestId: String? = pendingRequest?.clientRequestId,
        expectedCoreModuleSha256: String? = pendingRequest?.coreModuleSha256,
        expectedProfileDigest: String? = pendingRequest?.takeIf { it.coreModuleSha256 != null }?.profileDigest,
        deadline: AndroidConnectDeadline? = pendingRequest?.deadline,
    ): Map<String, Any?> {
        if (clientRequestId != null && !AndroidConnectRequestOwner.owns(clientRequestId)) {
            return AndroidRuntimeState.snapshot()
        }
        val persistedProfile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        if (AndroidRuntimeState.resolveEnvironment(activity) == null) {
            return snapshot()
        }
        if (!AndroidRuntimeState.initialize(activity)) {
            return AndroidRuntimeState.snapshot()
        }
        if (persistedProfile?.catalogAppIdentityRequired == true &&
            AndroidCatalogAppBinding.forProfile(persistedProfile.configDigest) == null) {
            AndroidRuntimeState.markFailure("profile_identity_mismatch",
                AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch"))
            return AndroidRuntimeState.snapshot()
        }
        if (deadline != null && !deadline.isCurrent()) {
            invalidatePendingConnect()
            AndroidRuntimeState.markFailure("connect_deadline",
                AndroidRuntimeSafety.publicFailureMessage("connect_deadline"))
            return AndroidRuntimeState.snapshot()
        }

        if (expectedCoreModuleSha256 != null &&
            !AndroidRuntimeState.matchesCoreModuleSha256(expectedCoreModuleSha256)) {
            invalidatePendingConnect()
            AndroidRuntimeState.markFailure("core_identity_mismatch",
                AndroidRuntimeSafety.publicFailureMessage("core_identity_mismatch"))
            return AndroidRuntimeState.snapshot()
        }
        if (expectedProfileDigest != null && (persistedProfile?.configDigest != expectedProfileDigest ||
                !AndroidRuntimeState.isStagedProfileCurrent(expectedProfileDigest))) {
            invalidatePendingConnect()
            AndroidRuntimeState.markFailure("profile_identity_mismatch",
                AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch"))
            return AndroidRuntimeState.snapshot()
        }

        val stagedConfigPath = AndroidRuntimeState.stagedConfigPath()
        if (stagedConfigPath.isNullOrBlank()) {
            AndroidRuntimeState.markFailure(
                kind = "missing_staged_config",
                message = "Сначала завершите подготовку устройства, затем попробуйте подключиться еще раз.",
            )
            return AndroidRuntimeState.snapshot()
        }
        val routeMode = persistedProfile?.takeIf { it.configPath == stagedConfigPath }
            ?.routeMode
            .orEmpty()
        if (routeMode.isBlank()) {
            AndroidRuntimeState.markFailure(
                kind = "missing_route_mode",
                message = "Сначала обновите настройки POKROV и попробуйте подключиться еще раз.",
            )
            return AndroidRuntimeState.snapshot()
        }
        val pending = pendingRequest ?: currentOrBeginPendingConnect(
            stagedConfigPath, persistedProfile?.configDigest.orEmpty(), clientRequestId, expectedCoreModuleSha256, deadline)
        if (!isCurrentPendingConnect(pending)) {
            return AndroidRuntimeState.snapshot()
        }

        if (checkNotificationPermission) {
            when (notificationPermissionAction()) {
                AndroidNotificationPermissionAction.REQUEST -> {
                    if (!setNotificationPermissionRequest(pending)) {
                        return AndroidRuntimeState.snapshot()
                    }
                    AndroidOperationalJournal.record(
                        AndroidOperationalEvent.NOTIFICATION_PERMISSION,
                        AndroidOperationalOutcome.REQUIRED,
                    )
                    AndroidNotificationPermissionStore.markAsked(activity)
                    activity.runOnUiThread {
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQUEST_NOTIFICATION_PERMISSION,
                        )
                    }
                    return AndroidRuntimeState.snapshot()
                }
                AndroidNotificationPermissionAction.CONTINUE_WITH_WARNING -> {
                    AndroidOperationalJournal.recordRateLimited(
                        AndroidOperationalEvent.NOTIFICATION_PERMISSION,
                        AndroidOperationalOutcome.DENIED,
                    )
                    AndroidRuntimeState.markSystemNotificationWarning()
                }
                AndroidNotificationPermissionAction.WAIT_FOR_RESULT ->
                    return AndroidRuntimeState.snapshot()
                AndroidNotificationPermissionAction.CONTINUE -> {
                    AndroidOperationalJournal.recordRateLimited(
                        AndroidOperationalEvent.NOTIFICATION_PERMISSION,
                        AndroidOperationalOutcome.ALREADY_GRANTED,
                    )
                    AndroidRuntimeState.clearSystemNotificationWarning()
                }
            }
        }

        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.VPN_PERMISSION,
                AndroidOperationalOutcome.REQUIRED,
            )
            AndroidRuntimeState.markPermissionRequested()
            if (!setVpnPermissionRequest(pending)) {
                return AndroidRuntimeState.snapshot()
            }
            activity.runOnUiThread {
                activity.startActivityForResult(prepareIntent, REQUEST_VPN_PERMISSION)
            }
            return AndroidRuntimeState.snapshot()
        }
        AndroidOperationalJournal.recordRateLimited(
            AndroidOperationalEvent.VPN_PERMISSION,
            AndroidOperationalOutcome.ALREADY_GRANTED,
        )

        runCatching {
            PokrovRuntimeVpnService.start(
                activity, stagedConfigPath, routeMode, pending.profileDigest,
                connectRequestId = pending.clientRequestId,
                expectedCoreModuleSha256 = pending.coreModuleSha256,
                deadline = pending.deadline,
            )
        }.onFailure {
            AndroidRuntimeState.markFailure(
                kind = "runtime_start_failed",
                message = AndroidRuntimeSafety.publicFailureMessage("runtime_start_failed"),
            )
        }
        // The bridge token is needed only for Android permission callbacks.
        // From here the service owns the pending lifecycle and its terminal state.
        clearPendingConnect(pending)
        return AndroidRuntimeState.snapshot()
    }

    private fun connectWithCoreIdentity(call: MethodCall, result: MethodChannel.Result) {
        val request = call.argument<Any>("requestId") as? String
        fun rejectBeforeAdmission(code: String, message: String) {
            if (request != null && AndroidConnectRequestOwner.valid(request) && !AndroidConnectRequestOwner.knows(request)) {
                result.error("core_identity_connect_not_dispatched", message,
                    mapOf("schema" to 1, "requestId" to request, "settled" to true))
            } else result.error(code, message, null)
        }
        val core = call.argument<Any>("expectedCoreModuleSha256") as? String
        val profile = call.argument<Any>("expectedProfileDigest") as? String
        val networkRef = call.argument<Any>("expectedNetworkContextRef") as? String
        val boot = call.argument<Any>("bootRef") as? String
        val startValue = call.argument<Any>("startedElapsedMs")
        val endValue = call.argument<Any>("deadlineElapsedMs")
        val started = when (startValue) { is Int -> startValue.toLong(); is Long -> startValue; else -> null }
        val expires = when (endValue) { is Int -> endValue.toLong(); is Long -> endValue; else -> null }
        val digestPattern = Regex("[0-9a-f]{64}")
        if ((call.arguments as? Map<*, *>)?.size != 7 || request == null || !AndroidConnectRequestOwner.valid(request) ||
            networkRef == null || !Regex("network_[0-9a-f]{32}").matches(networkRef) ||
            core == null || !digestPattern.matches(core) || profile == null || !digestPattern.matches(profile)) {
            rejectBeforeAdmission("invalid_connect_identity", "Invalid connection identity.")
            return
        }
        val bootCount = runCatching { Settings.Global.getInt(activity.contentResolver, Settings.Global.BOOT_COUNT) }.getOrNull()
        if (bootCount == null || bootCount < 0 || boot == null || boot != "android:$bootCount" ||
            started == null || expires == null || started < 0 || expires > 9007199254740991L ||
            expires <= started || expires-started > 86400000L) {
            rejectBeforeAdmission("invalid_connect_deadline", "Invalid connection deadline.")
            return
        }
        val deadline = AndroidConnectDeadline(boot, started, expires)
        if (!deadline.isCurrent()) {
            rejectBeforeAdmission("connect_deadline", "Connection deadline expired.")
            return
        }
        val network = if (transportNetworkContext.isInitialized()) transportNetworkContext.value else null
        if (network == null || network.read() != networkRef) {
            rejectBeforeAdmission("network_context_changed", "Network context changed.")
            return
        }
        if (!AndroidConnectRequestOwner.beginBound(request, core, profile, deadline, network, networkRef)) {
            rejectBeforeAdmission("conflicting_connect_identity", "Connection request identity changed.")
            return
        }
        connect(clientRequestId = request, expectedCoreModuleSha256 = core,
            expectedProfileDigest = profile, deadline = deadline)
        watchPendingConnectDeadline(request)
        val value = AndroidConnectRequestOwner.snapshotForBoundRequest(request)
        if (value == null) {
            result.error("core_identity_connect_unacknowledged", "Connection owner is unavailable.", null)
            return
        }
        result.success(mapOf("schema" to 1, "requestId" to request, "snapshot" to value))
    }

    private fun snapshotForConnectRequest(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val request = arguments?.get("requestId") as? String
        if (arguments?.size != 1 || request == null || !AndroidConnectRequestOwner.valid(request)) {
            result.error("invalid_connect_request", "Invalid connection request.", null)
            return
        }
        val value = AndroidConnectRequestOwner.snapshotForBoundRequest(request)
        if (value == null) {
            result.error("connect_progress_unconfirmed", "Connection owner is unavailable.", null)
        } else {
            result.success(mapOf("schema" to 1, "requestId" to request, "snapshot" to value))
        }
    }

    private fun promoteBoundTransportLease(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val request = arguments?.get("requestId") as? String
        val profile = arguments?.get("profileDigest") as? String
        val lease = arguments?.get("endpointLeaseRef") as? String
        val issued = arguments?.get("issuedAt") as? String
        val newUntil = arguments?.get("newFlowsUntil") as? String
        val activeUntil = arguments?.get("activeFlowsUntil") as? String
        if (arguments?.size != 6 || request == null || !AndroidConnectRequestOwner.valid(request) ||
            profile == null || !Regex("[a-f0-9]{64}").matches(profile) ||
            lease == null || !Regex("lease_[a-f0-9]{32}").matches(lease) ||
            issued == null || newUntil == null || activeUntil == null) {
            result.error("invalid_transport_lease_handoff", "Invalid transport lease.", null)
            return
        }
        PokrovRuntimeVpnService.promoteBoundTransportLease(request, profile, lease,
            issued, newUntil, activeUntil) { promoted ->
            activity.runOnUiThread {
                if (!hostTaskScope.isActive()) return@runOnUiThread
                val snapshot = if (promoted) AndroidConnectRequestOwner.snapshotForBoundRequest(request) else null
                if (snapshot == null || snapshot["transportProofPending"] != false ||
                    snapshot["core_egress_validated"] != true) {
                    result.error("transport_lease_handoff_unconfirmed", "Transport lease unavailable.", null)
                } else {
                    result.success(mapOf("schema" to 1, "requestId" to request, "snapshot" to snapshot))
                }
            }
        }
    }

    private fun revokeBoundTransportLease(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val request = arguments?.get("requestId") as? String
        val profile = arguments?.get("profileDigest") as? String
        val lease = arguments?.get("endpointLeaseRef") as? String
        val terminateActive = arguments?.get("terminateActive") as? Boolean
        if (arguments?.size != 4 || request == null || !AndroidConnectRequestOwner.valid(request) ||
            profile == null || !Regex("[a-f0-9]{64}").matches(profile) ||
            lease == null || !Regex("lease_[a-f0-9]{32}").matches(lease) || terminateActive == null) {
            result.error("invalid_transport_lease_revocation", "Invalid transport lease.", null)
            return
        }
        PokrovRuntimeVpnService.revokeBoundTransportLease(request, profile, lease, terminateActive) { revoked ->
            activity.runOnUiThread {
                if (!hostTaskScope.isActive()) return@runOnUiThread
                val snapshot = if (revoked) AndroidConnectRequestOwner.snapshotForBoundRequest(request) else null
                if (snapshot == null || snapshot["core_egress_validated"] != false ||
                    (terminateActive && (snapshot["transportProofPending"] != true ||
                        snapshot["transportLeaseActive"] != false))) {
                    result.error("transport_lease_revocation_unconfirmed", "Transport lease unavailable.", null)
                } else {
                    result.success(mapOf("schema" to 1, "requestId" to request, "snapshot" to snapshot))
                }
            }
        }
    }

    private fun watchPendingConnectDeadline(request: String) {
        pendingConnectDeadlineWatchdog?.let(connectDeadlineHandler::removeCallbacks)
        val watchdog = object : Runnable {
            override fun run() {
                if (!pendingConnectGate.ownsClientRequest(request)) return
                if (AndroidConnectRequestOwner.expire(request)) {
                    pendingConnectGate.cancelClientRequest(request)
                    synchronized(pendingConnectLock) {
                        if (notificationPermissionRequest?.clientRequestId == request) notificationPermissionRequest = null
                        if (vpnPermissionRequest?.clientRequestId == request) vpnPermissionRequest = null
                    }
                    AndroidRuntimeState.markFailure("connect_deadline",
                        AndroidRuntimeSafety.publicFailureMessage("connect_deadline"))
                } else if (AndroidConnectRequestOwner.owns(request)) {
                    connectDeadlineHandler.postDelayed(this, 100L)
                }
            }
        }
        pendingConnectDeadlineWatchdog = watchdog
        connectDeadlineHandler.post(watchdog)
    }

    private fun cancelConnectRequest(call: MethodCall, result: MethodChannel.Result) {
        val request = call.argument<Any>("requestId") as? String
        if (request == null || !AndroidConnectRequestOwner.valid(request)) {
            result.error("invalid_connect_request", "Invalid connection request.", null)
            return
        }
        val accepted = AndroidConnectRequestOwner.cancel(request)
        if (accepted) {
            val awaitingPermission = pendingConnectGate.cancelClientRequest(request)
            synchronized(pendingConnectLock) {
                if (notificationPermissionRequest?.clientRequestId == request) notificationPermissionRequest = null
                if (vpnPermissionRequest?.clientRequestId == request) vpnPermissionRequest = null
            }
            // The service checks this exact request again when the intent is
            // received. A queued cancellation must not stop a newer request.
            try {
                if (awaitingPermission) AndroidRuntimeState.cancelPendingConnection()
                else PokrovRuntimeVpnService.cancelConnectRequest(activity, request)
            } catch (_: Exception) {
                result.error("connect_cancel_dispatch_failed", "Connection cancellation was not confirmed.", null)
                return
            }
        }
        result.success(mapOf("schema" to 1, "requestId" to request, "cancelled" to accepted))
    }

    private fun cancelAndConfirmConnectStopped(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val request = arguments?.get("requestId") as? String
        if (arguments?.size != 1 || request == null || !AndroidConnectRequestOwner.valid(request)) {
            result.error("invalid_connect_request", "Invalid connection request.", null)
            return
        }
        fun respond(settled: Boolean) {
            result.success(mapOf("schema" to 1, "requestId" to request, "settled" to settled))
        }
        if (AndroidConnectRequestOwner.isStopped(request)) { respond(true); return }
        if (!AndroidConnectRequestOwner.cancel(request)) { respond(false); return }
        pendingConnectGate.cancelClientRequest(request)
        synchronized(pendingConnectLock) {
            if (notificationPermissionRequest?.clientRequestId == request) notificationPermissionRequest = null
            if (vpnPermissionRequest?.clientRequestId == request) vpnPermissionRequest = null
        }
        if (AndroidConnectRequestOwner.settleBeforeServiceAdmission(request)) {
            AndroidRuntimeState.cancelPendingConnection()
            respond(true)
            return
        }
        val owner = AndroidConnectRequestOwner.serviceFor(request)
        if (owner == null) { respond(false); return }
        owner.cancelAndConfirmConnectStopped(request) { settled ->
            activity.runOnUiThread { respond(settled) }
        }
    }

    private fun revokeRoutingCatalog(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        if (arguments?.size != 1 || profile == null || !Regex("^[a-f0-9]{64}$").matches(profile)) {
            result.error("invalid_catalog_revocation", "Invalid catalog revocation.", null)
            return
        }
        PokrovRuntimeVpnService.revokeRoutingCatalog(profile) { revoked ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (revoked == null) result.error("catalog_revoke_unconfirmed", "Catalog revocation was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile, "revoked" to revoked))
                }
            }
        }
    }

    private fun revokeRoutingCatalogService(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        val service = arguments?.get("serviceId") as? String
        if (arguments?.size != 2 || profile == null || service == null ||
            !Regex("^[a-f0-9]{64}$").matches(profile) || !Regex("^[a-z0-9][a-z0-9._-]{0,63}$").matches(service)) {
            result.error("invalid_catalog_revocation", "Invalid service revocation.", null)
            return
        }
        PokrovRuntimeVpnService.revokeRoutingCatalogService(profile, service) { revoked ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (revoked == null) result.error("catalog_revoke_unconfirmed", "Service revocation was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile, "serviceId" to service, "revoked" to revoked))
                }
            }
        }
    }

    private fun readSmartAccessRestrictions(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments != null || AndroidRuntimeState.snapshot()["smartAccessRuntimeControlVersion"] != 1) {
            result.error("smart_access_restriction_read_unavailable", "Restriction recovery is unavailable.", null)
            return
        }
        executeHostTask(result, emptyMap<String, Any?>()) {
            val journal = space.pokrov.core.libbox.Libbox::class.java.getMethod("readSmartAccessRestrictions").invoke(null) as? String
            if (journal == null || journal.toByteArray(Charsets.UTF_8).size > 1024 * 1024) emptyMap()
            else mapOf("schema" to 1, "journalJson" to journal)
        }
    }

    private fun readSmartAccessLeases(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        if (arguments?.size != 1 || profile == null || !Regex("^[a-f0-9]{64}$").matches(profile) ||
            AndroidRuntimeState.snapshot()["smartAccessRuntimeControlVersion"] != 1) {
            result.error("smart_access_lease_read_unavailable", "Lease recovery is unavailable.", null)
            return
        }
        PokrovRuntimeVpnService.readSmartAccessLeases(profile) { encoded ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (encoded == null) result.error("smart_access_lease_read_unconfirmed", "Lease recovery was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile, "leaseIdsJson" to encoded))
                }
            }
        }
    }

    private fun acknowledgeSmartAccessRestrictions(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val digest = arguments?.get("snapshotSha256") as? String
        if (arguments?.size != 1 || digest == null || !Regex("^[a-f0-9]{64}$").matches(digest) ||
            AndroidRuntimeState.snapshot()["smartAccessRuntimeControlVersion"] != 1) {
            result.error("smart_access_restriction_ack_invalid", "Invalid restriction acknowledgement.", null)
            return
        }
        executeHostTask(result, emptyMap<String, Any?>()) {
            val accepted = space.pokrov.core.libbox.Libbox::class.java.getMethod("acknowledgeSmartAccessRestrictions", String::class.java)
                .invoke(null, digest) as? Boolean
            if (accepted == null) emptyMap() else mapOf("schema" to 1, "snapshotSha256" to digest, "acknowledged" to accepted)
        }
    }

    private fun configureSmartAccessRuntimeControl(call: MethodCall, result: MethodChannel.Result, renewal: Boolean = false, bound: Boolean = false) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        val config = arguments?.get("configJson") as? String
        val request = arguments?.get("requestId") as? String
        if (arguments?.size != (if (bound) 3 else 2) || profile == null || config == null ||
            (bound && (request == null || !AndroidConnectRequestOwner.valid(request))) ||
            !Regex("^[a-f0-9]{64}$").matches(profile) || config.toByteArray(Charsets.UTF_8).size > 16384) {
            result.error("invalid_smart_access_runtime_control", "Invalid runtime control request.", null)
            return
        }
        if (AndroidRuntimeState.snapshot()["smartAccessRuntimeControlVersion"] != 1) {
            result.error("smart_access_runtime_control_unsupported", "Runtime control is unavailable.", null)
            return
        }
        PokrovRuntimeVpnService.configureSmartAccessRuntimeControl(profile, config, renewal, if (bound) request else null) { configured ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (configured == null) result.error("smart_access_runtime_control_unconfirmed", "Runtime control was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile, "configured" to configured) +
                        (if (bound) mapOf("requestId" to request) else emptyMap()))
                }
            }
        }
    }

    private fun renewSmartAccessLease(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        val expected = arguments?.get("expectedLeaseId") as? String
        val next = arguments?.get("nextLeaseId") as? String
        val issued = arguments?.get("issuedAt") as? String
        val newUntil = arguments?.get("newFlowsUntil") as? String
        val activeUntil = arguments?.get("activeFlowsUntil") as? String
        if (arguments?.size != 6 || profile == null || expected == null || next == null ||
            issued == null || newUntil == null || activeUntil == null ||
            !Regex("^[a-f0-9]{64}$").matches(profile)) {
            result.error("invalid_smart_access_renewal", "Invalid lease renewal.", null)
            return
        }
        if (AndroidRuntimeState.snapshot()["routingCatalogControlVersion"] != 4) {
            result.error("smart_access_renewal_unsupported", "Lease renewal is unavailable.", null)
            return
        }
        PokrovRuntimeVpnService.renewSmartAccessLease(profile, expected, next, issued, newUntil, activeUntil) { renewed ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (renewed == null) result.error("smart_access_renewal_unconfirmed", "Lease renewal was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile,
                        "expectedLeaseId" to expected, "nextLeaseId" to next, "renewed" to renewed))
                }
            }
        }
    }

    private fun revokeSmartAccessLease(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        val lease = arguments?.get("leaseId") as? String
        val terminate = arguments?.get("terminateActive") as? Boolean
        if (arguments?.size != 3 || profile == null || lease == null || terminate == null ||
            !Regex("^[a-f0-9]{64}$").matches(profile) || !Regex("^[a-f0-9]{32}$").matches(lease)) {
            result.error("invalid_smart_access_revocation", "Invalid lease revocation.", null)
            return
        }
        PokrovRuntimeVpnService.revokeSmartAccessLease(profile, lease, terminate) { revoked ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (revoked == null) result.error("smart_access_revoke_unconfirmed", "Lease revocation was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile,
                        "leaseId" to lease, "revoked" to revoked))
                }
            }
        }
    }

    private fun revokeSmartAccessPolicy(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val profile = arguments?.get("profileDigest") as? String
        val terminate = arguments?.get("terminateActive") as? Boolean
        if (arguments?.size != 2 || profile == null || terminate == null || !Regex("^[a-f0-9]{64}$").matches(profile)) {
            result.error("invalid_smart_access_revocation", "Invalid policy revocation.", null)
            return
        }
        PokrovRuntimeVpnService.revokeSmartAccessPolicy(profile, terminate) { revoked ->
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    if (revoked == null) result.error("smart_access_revoke_unconfirmed", "Policy revocation was not confirmed.", null)
                    else result.success(mapOf("schema" to 1, "profileDigest" to profile,
                        "terminateActive" to terminate, "revoked" to revoked))
                }
            }
        }
    }

    private fun disconnect(): Map<String, Any?> {
        AndroidConnectRequestOwner.invalidate()
        invalidatePendingConnect()
        AndroidRuntimeState.markStopRequested(stopReason = "user_requested")
        runCatching {
            PokrovRuntimeVpnService.stop(activity)
        }.onFailure { error ->
            AndroidRuntimeState.markFailure(
                kind = "runtime_stop_failed",
                message = AndroidRuntimeSafety.publicFailureMessage("runtime_stop_failed"),
            )
        }
        return AndroidRuntimeState.snapshot()
    }

    private fun applyWarp(call: MethodCall): Map<String, Any?> {
        val stagedConfigPath = AndroidRuntimeState.stagedConfigPath()
        val configPayload = call.argument<String>("configPayload")
        if (stagedConfigPath.isNullOrBlank()) {
            return mapOf(
                "applied" to false,
                "effectiveAt" to "none",
                "fallbackUsed" to false,
                "reason" to "no_staged_profile",
            )
        }
        if (configPayload.isNullOrBlank()) {
            return mapOf(
                "applied" to false,
                "effectiveAt" to "none",
                "fallbackUsed" to false,
                "reason" to "config_payload_missing",
            )
        }
        return try {
            val existingProfile = AndroidRuntimeProfileStore.load(activity)
                ?: error("missing staged profile")
            // A config replacement changes the digest. Rebuild the signed app
            // scope through the normal stage instead of carrying old signers.
            check(!existingProfile.catalogAppIdentityRequired) { "catalog_app_scope_requires_restage" }
            val profileDigest = runtimeProfileDigest(
                configPayload, existingProfile.routeMode, existingProfile.coreEgressProbeRequired,
            )
            writePrivateConfig(File(stagedConfigPath), configPayload)
            AndroidRuntimeProfileStore.save(
                activity,
                existingProfile.copy(configPath = stagedConfigPath, configDigest = profileDigest),
            )
            AndroidRuntimeState.markProfileStaged(stagedConfigPath, profileDigest = profileDigest)
            mapOf(
                "applied" to true,
                "effectiveAt" to "next_connect",
                "fallbackUsed" to false,
                "reason" to null,
            )
        } catch (error: Throwable) {
            mapOf(
                "applied" to false,
                "effectiveAt" to "none",
                "fallbackUsed" to false,
                "reason" to "config_apply_failed",
            )
        }
    }

    private fun writePrivateConfig(target: File, content: String) {
        target.parentFile?.mkdirs()
        val next = File(target.parentFile, "${target.name}.next")
        next.writeText(content)
        next.setReadable(false, false)
        next.setWritable(false, false)
        next.setExecutable(false, false)
        check(next.setReadable(true, true)) { "Could not restrict profile read access." }
        check(next.setWritable(true, true)) { "Could not restrict profile write access." }
        // POSIX rename replaces atomically; on failure the previous file remains.
        android.system.Os.rename(next.absolutePath, target.absolutePath)
    }

    private fun pushToken(): Map<String, Any?> {
        return mapOf(
            "token" to "",
            "provider" to "poll",
        )
    }

    private fun currentWifi(): Map<String, Any?> {
        val connectivityManager = activity.getSystemService(
            ConnectivityManager::class.java,
        )
        val activeNetwork = connectivityManager?.activeNetwork
        val capabilities = activeNetwork?.let(connectivityManager::getNetworkCapabilities)
        val connected = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        if (!connected) {
            return mapOf(
                "connected" to false,
                "name" to null,
                "permissionRequired" to false,
                "reason" to "not_connected",
            )
        }

        val permission = wifiPermissionName()
        val permissionGranted = ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
        if (!permissionGranted) {
            return mapOf(
                "connected" to true,
                "name" to null,
                "permissionRequired" to true,
                "reason" to "permission_required",
            )
        }

        return try {
            @Suppress("DEPRECATION")
            val wifiInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                capabilities.transportInfo as? WifiInfo
            } else {
                activity.applicationContext
                    .getSystemService(WifiManager::class.java)
                    ?.connectionInfo
            }
            val name = wifiInfo?.ssid
                ?.trim()
                ?.removeSurrounding("\"")
                ?.takeUnless {
                    it.isBlank() || it.equals(WifiManager.UNKNOWN_SSID, ignoreCase = true)
                }
            mapOf(
                "connected" to true,
                "name" to name,
                "permissionRequired" to (name == null),
                "reason" to if (name == null) "ssid_unavailable" else null,
            )
        } catch (_: SecurityException) {
            mapOf(
                "connected" to true,
                "name" to null,
                "permissionRequired" to true,
                "reason" to "permission_required",
            )
        }
    }

    private fun requestWifiPermission(): Map<String, Any?> {
        val permission = wifiPermissionName()
        if (
            ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf("requested" to false, "granted" to true)
        }
        activity.runOnUiThread {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(permission),
                REQUEST_WIFI_PERMISSION,
            )
        }
        return mapOf("requested" to true, "granted" to false)
    }

    private fun invalidateManagedProfile(): Map<String, Any?> {
        // This intentionally leaves a live VPN service untouched. Its current
        // tunnel can still be stopped, but no old profile remains reusable.
        invalidatePendingConnect()
        AndroidRuntimeState.cancelPendingConnection()
        AndroidRuntimeProfileStore.clear(activity)
        AndroidRuntimeState.invalidateStagedProfile()
        return AndroidRuntimeState.snapshot()
    }

    private fun notificationPermissionAction(): AndroidNotificationPermissionAction {
        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        return AndroidNotificationPermissionPlanner.decide(
            sdkInt = Build.VERSION.SDK_INT,
            granted = granted,
            askedBefore = AndroidNotificationPermissionStore.wasAsked(activity),
            shouldShowRationale = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.POST_NOTIFICATIONS,
                ),
            requestInFlight = hasNotificationPermissionRequest(),
        )
    }

    private fun refreshNotificationPermissionWarning() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        val granted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        when {
            granted -> AndroidRuntimeState.clearSystemNotificationWarning()
            !hasNotificationPermissionRequest() &&
                AndroidNotificationPermissionStore.wasAsked(activity) ->
                AndroidRuntimeState.markSystemNotificationWarning()
        }
    }

    private fun currentOrBeginPendingConnect(configPath: String, profileDigest: String,
        clientRequestId: String? = null, coreModuleSha256: String? = null,
        deadline: AndroidConnectDeadline? = null): PendingRuntimeConnect {
        val (pending, created) = pendingConnectGate.acquire(configPath, profileDigest, clientRequestId, coreModuleSha256, deadline)
        if (created) {
            synchronized(pendingConnectLock) {
                notificationPermissionRequest = null
                vpnPermissionRequest = null
            }
            AndroidRuntimeState.markConnectionRequested()
        }
        return pending
    }

    private fun invalidatePendingConnect() {
        synchronized(pendingConnectLock) {
            notificationPermissionRequest = null
            vpnPermissionRequest = null
        }
        pendingConnectGate.invalidate()
    }

    private fun isCurrentPendingConnect(pending: PendingRuntimeConnect): Boolean =
        pendingConnectGate.isCurrent(pending) && AndroidRuntimeState.isConnectionPending() &&
            (pending.clientRequestId == null || AndroidConnectRequestOwner.owns(pending.clientRequestId))

    private fun setNotificationPermissionRequest(pending: PendingRuntimeConnect): Boolean =
        synchronized(pendingConnectLock) {
            if (!pendingConnectGate.isCurrent(pending)) {
                false
            } else {
                notificationPermissionRequest = pending
                true
            }
        }

    private fun takeNotificationPermissionRequest(): PendingRuntimeConnect? =
        synchronized(pendingConnectLock) {
            notificationPermissionRequest.also {
                notificationPermissionRequest = null
            }
        }

    private fun hasNotificationPermissionRequest(): Boolean =
        synchronized(pendingConnectLock) {
            notificationPermissionRequest != null
        }

    private fun setVpnPermissionRequest(pending: PendingRuntimeConnect): Boolean =
        synchronized(pendingConnectLock) {
            if (!pendingConnectGate.isCurrent(pending) || vpnPermissionRequest != null) {
                false
            } else {
                vpnPermissionRequest = pending
                true
            }
        }

    private fun takeVpnPermissionRequest(): PendingRuntimeConnect? =
        synchronized(pendingConnectLock) {
            vpnPermissionRequest.also {
                vpnPermissionRequest = null
            }
        }

    private fun clearPendingConnect(pending: PendingRuntimeConnect) =
        pendingConnectGate.completeDispatch(pending)

    private fun recordUpdateHandoff(status: String) {
        val outcome = when (status) {
            AndroidClientUpdateInstaller.STATUS_INSTALLER_OPENED ->
                AndroidOperationalOutcome.INSTALLER_OPENED
            AndroidClientUpdateInstaller.STATUS_STORE_OPENED ->
                AndroidOperationalOutcome.STORE_OPENED
            AndroidClientUpdateInstaller.STATUS_PERMISSION_REQUIRED ->
                AndroidOperationalOutcome.PERMISSION_REQUIRED
            else -> AndroidOperationalOutcome.FAILED
        }
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.UPDATER_HANDOFF,
            outcome,
        )
    }

    private fun wifiPermissionName(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }

    private fun openVpnSettings(): Boolean {
        return runCatching {
            activity.runOnUiThread {
                val intent = Intent(Settings.ACTION_VPN_SETTINGS)
                activity.startActivity(intent)
            }
            true
        }.getOrElse {
            runCatching {
                activity.runOnUiThread {
                    activity.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                }
                true
            }.getOrDefault(false)
        }
    }

    private fun updateSystemSurfacePreferences(): Map<String, Boolean> {
        AndroidSystemSurfacePreferencesStore.save(activity)
        PokrovRuntimeVpnService.refreshNotification(activity)
        return AndroidSystemSurfacePreferencesStore.load(activity).toMap()
    }

    private fun openNotificationSettings(): Boolean = runCatching {
        activity.runOnUiThread {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
            activity.startActivity(intent)
        }
        true
    }.getOrElse {
        runCatching {
            activity.runOnUiThread {
                activity.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:${activity.packageName}")
                    },
                )
            }
            true
    }.getOrDefault(false)
    }

    private fun measureNodeLatencies(call: MethodCall, result: MethodChannel.Result) {
        val targets = AndroidNodeLatencyProbe.parseTargets(call.argument<Any?>("targets"))
        if (targets.isEmpty()) {
            result.success(emptyMap<String, Int>())
            return
        }
        executeHostTask(result, emptyMap<String, Int>()) {
            AndroidNodeLatencyProbe.measure(activity, targets)
        }
    }

    private fun measureLocationVariants(call: MethodCall, result: MethodChannel.Result) {
        val requestedVariantId = call.argument<String>("variantId")
            ?.trim()
            ?.lowercase()
            .orEmpty()
        val environment = AndroidRuntimeState.resolveEnvironment(activity)
            ?: run {
                result.success(AndroidVariantAvailabilityProbe.probe("", requestedVariantId))
                return
            }
        val expectedFile = File(environment.configDirectory, "managed-profile.json")
        val stagedPath = AndroidRuntimeState.stagedConfigPath().orEmpty()
        executeHostTask(
            result,
            AndroidVariantAvailabilityProbe.probe("", requestedVariantId),
        ) {
            // A terminal egress failure deliberately clears the reusable
            // staged path. The canonical private file may still be read to
            // match a short-lived exact-catalog status cache; probe() cannot
            // stage or reactivate it and returns unavailable on a mismatch.
            val stagedFile = if (stagedPath.isBlank()) expectedFile else File(stagedPath)
            if (
                !stagedFile.isFile ||
                stagedFile.canonicalPath != expectedFile.canonicalPath ||
                stagedFile.length() !in 1..MAX_VARIANT_PROBE_CONFIG_BYTES
            ) {
                return@executeHostTask AndroidVariantAvailabilityProbe.probe(
                    "",
                    requestedVariantId,
                )
            }
            AndroidVariantAvailabilityProbe.probe(
                stagedFile.readText(Charsets.UTF_8),
                requestedVariantId,
            )
        }
    }

    private fun listInstalledApps(result: MethodChannel.Result) {
        executeHostTask(result, emptyList<Map<String, String>>()) {
            installedLauncherApps()
        }
    }

    private fun catalogAppIdentities(call: MethodCall, result: MethodChannel.Result) {
        val packages = call.argument<Any>("packages") as? List<*>
        val digest = call.argument<Any>("catalogDigest") as? String
        if (!hostTaskScope.isActive() || packages == null || packages.size > 256 ||
            packages.any { it !is String } || digest == null) {
            result.success(AndroidCatalogIdentityResolver.unavailable())
            return
        }
        // Initialize the lifecycle-bound receiver on this bridge's UI thread,
        // before dispatch, so close cannot race a late lazy registration.
        val resolver = catalogIdentityResolver.value
        val fresh = call.argument<Any>("fresh") == true
        executeHostTask(result, AndroidCatalogIdentityResolver.unavailable()) {
            resolver.scan(digest, packages.filterIsInstance<String>(), fresh)
        }
    }

    private fun <T> executeHostTask(
        result: MethodChannel.Result,
        fallback: T,
        task: () -> T,
    ) {
        val accepted = hostTaskScope.execute {
            val value = runCatching(task).getOrDefault(fallback)
            activity.runOnUiThread {
                if (hostTaskScope.isActive()) {
                    result.success(value)
                }
            }
        }
        if (!accepted) {
            result.success(fallback)
        }
    }

    private fun deviceName(): String {
        val manufacturer = Build.MANUFACTURER.trim()
        val model = Build.MODEL.trim()
        val identity = when {
            model.isBlank() -> manufacturer
            manufacturer.isBlank() || model.startsWith(manufacturer, ignoreCase = true) -> model
            else -> "$manufacturer $model"
        }
        return identity
            .replace(Regex("[\\p{Cc}\\p{Cf}]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
            .take(80)
            .ifBlank { "Android" }
    }

    @Suppress("DEPRECATION")
    private fun installedLauncherApps(): List<Map<String, String>> {
        val packageManager = activity.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        return packageManager.queryIntentActivities(launcherIntent, 0)
            .asSequence()
            .mapNotNull { resolveInfo ->
                val packageName = resolveInfo.activityInfo?.packageName
                    ?: return@mapNotNull null
                if (packageName == activity.packageName) {
                    return@mapNotNull null
                }
                val label = resolveInfo.loadLabel(packageManager)
                    ?.toString()
                    ?.trim()
                    .orEmpty()
                Triple(
                    packageName,
                    if (label.isBlank()) packageName else label,
                    resolveInfo,
                )
            }
            // Resolve duplicate launcher activities before bitmap work. Keep
            // every app searchable, but only encode the first icons: some
            // Huawei builds expose hundreds of activities and encoding every
            // bitmap used to make the picker look empty while it was loading.
            .distinctBy { (packageName, _, _) -> packageName }
            .sortedBy { (_, label, _) -> label.lowercase() }
            .mapIndexed { index, (packageName, label, resolveInfo) ->
                buildMap<String, String> {
                    put("label", label)
                    put("identifier", packageName)
                    put("subtitle", packageName)
                    if (index < MAX_INSTALLED_APP_ICONS) {
                        encodeLauncherIcon(resolveInfo.loadIcon(packageManager))?.let {
                            put("iconPngBase64", it)
                        }
                    }
                }
            }
            .toList()
    }

    private fun encodeLauncherIcon(drawable: android.graphics.drawable.Drawable): String? =
        runCatching {
            val bitmap = drawable.toBitmap(width = 72, height = 72)
            val stream = ByteArrayOutputStream()
            if (!bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)) {
                return@runCatching null
            }
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        }.getOrNull()

    companion object {
        private const val MAX_INSTALLED_APP_ICONS = 80
        private const val MAX_VARIANT_PROBE_CONFIG_BYTES = 4L * 1024L * 1024L
        private val SUPPORTED_UPDATE_ABIS = setOf("arm64-v8a", "armeabi-v7a", "x86_64")
        const val CHANNEL_NAME = "space.pokrov/runtime_engine"
        const val REQUEST_VPN_PERMISSION = 14071
        const val EXTRA_DEBUG_RUNTIME_PATH = "space.pokrov.debug.RUNTIME_PATH"
        const val EXTRA_DEBUG_AUTO_CONNECT = "space.pokrov.debug.AUTO_CONNECT"
        private const val METHOD_SNAPSHOT = "runtimeEngine.snapshot"
        private const val METHOD_INITIALIZE = "runtimeEngine.initialize"
        private const val METHOD_STAGE_MANAGED_PROFILE = "runtimeEngine.stageManagedProfile"
        private const val METHOD_INVALIDATE_MANAGED_PROFILE = "runtimeEngine.invalidateManagedProfile"
        private const val METHOD_CONNECT = "runtimeEngine.connect"
        private const val METHOD_DISCONNECT = "runtimeEngine.disconnect"
        private const val METHOD_APPLY_WARP = "runtimeEngine.applyWarp"
        private const val METHOD_LIVE_STATS = "runtimeEngine.liveStats"
        private const val METHOD_PUSH_TOKEN = "runtimeEngine.pushToken"
        private const val METHOD_DEVICE_NAME = "runtimeEngine.deviceName"
        private const val METHOD_SUPPORTED_ABIS = "runtimeEngine.supportedAbis"
        private const val METHOD_LIST_INSTALLED_APPS = "runtimeEngine.listInstalledApps"
        private const val METHOD_CURRENT_WIFI = "runtimeEngine.currentWifi"
        private const val METHOD_MEASURE_NODE_LATENCIES =
            "runtimeEngine.measureNodeLatencies"
        private const val METHOD_MEASURE_LOCATION_VARIANTS =
            "runtimeEngine.measureLocationVariants"
        private const val METHOD_REQUEST_WIFI_PERMISSION =
            "runtimeEngine.requestWifiPermission"
        private const val METHOD_OPEN_VPN_SETTINGS = "runtimeEngine.openVpnSettings"
        private const val METHOD_SYSTEM_SURFACE_PREFERENCES =
            "runtimeEngine.systemSurfacePreferences"
        private const val METHOD_UPDATE_SYSTEM_SURFACE_PREFERENCES =
            "runtimeEngine.updateSystemSurfacePreferences"
        private const val METHOD_OPEN_NOTIFICATION_SETTINGS =
            "runtimeEngine.openNotificationSettings"
        private const val METHOD_OPEN_IN_APP_WEB_SURFACE =
            "runtimeEngine.openInAppWebSurface"
        private const val METHOD_CLIENT_UPDATE_PROGRESS =
            "runtimeEngine.clientUpdateProgress"
        private const val METHOD_INSTALL_CLIENT_UPDATE =
            "runtimeEngine.installClientUpdate"
        private const val REQUEST_WIFI_PERMISSION = 14073
        private const val REQUEST_NOTIFICATION_PERMISSION = 14074
    }
}
