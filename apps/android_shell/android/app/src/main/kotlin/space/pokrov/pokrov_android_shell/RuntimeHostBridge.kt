package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal data class PendingRuntimeConnect(
    val id: Long,
    val configPath: String,
)

/** Owns only consent callbacks; a dispatched service start must release it. */
internal class PendingRuntimeConnectGate {
    private var nextId = 0L
    private var current: PendingRuntimeConnect? = null

    @Synchronized
    fun acquire(configPath: String): Pair<PendingRuntimeConnect, Boolean> {
        val existing = current
        if (existing != null && existing.configPath == configPath) {
            return existing to false
        }
        return PendingRuntimeConnect(id = ++nextId, configPath = configPath).also {
            current = it
        } to true
    }

    @Synchronized
    fun isCurrent(pending: PendingRuntimeConnect): Boolean = current == pending

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
}

class RuntimeHostBridge(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private var handledDebugPath: String? = null
    private val pendingConnectLock = Any()
    private val pendingConnectGate = PendingRuntimeConnectGate()
    private var notificationPermissionRequest: PendingRuntimeConnect? = null
    private var vpnPermissionRequest: PendingRuntimeConnect? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_SNAPSHOT -> result.success(snapshot())
            METHOD_INITIALIZE -> result.success(initialize())
            METHOD_STAGE_MANAGED_PROFILE -> result.success(stageManagedProfile(call))
            METHOD_INVALIDATE_MANAGED_PROFILE -> result.success(invalidateManagedProfile())
            METHOD_CONNECT -> result.success(connect())
            METHOD_DISCONNECT -> result.success(disconnect())
            METHOD_APPLY_WARP -> result.success(applyWarp(call))
            METHOD_LIVE_STATS -> result.success(AndroidRuntimeState.liveStats())
            METHOD_PUSH_TOKEN -> result.success(pushToken())
            METHOD_LIST_INSTALLED_APPS -> result.success(listInstalledApps())
            METHOD_CURRENT_WIFI -> result.success(currentWifi())
            METHOD_REQUEST_WIFI_PERMISSION ->
                result.success(requestWifiPermission())
            METHOD_OPEN_VPN_SETTINGS -> result.success(openVpnSettings())
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_VPN_PERMISSION) {
            return
        }
        val pending = takeVpnPermissionRequest() ?: return
        if (!isCurrentPendingConnect(pending)) {
            return
        }

        if (resultCode == Activity.RESULT_OK) {
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
            AndroidRuntimeState.clearSystemNotificationWarning()
        } else {
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
            ?.takeIf { it in setOf("allExceptRu", "fullTunnel", "selectedApps") }
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
        val finalPath = File(runtimeEnvironment.configDirectory, "managed-profile.json")

        return try {
            if (!materializedForRuntime) {
                throw IllegalArgumentException(
                    "POKROV Core requires a materialized sing-box profile.",
                )
            }
            writePrivateConfig(finalPath, configPayload)
            AndroidRuntimeState.markProfileStaged(finalPath.absolutePath)
            AndroidRuntimeProfileStore.save(
                activity,
                PersistedRuntimeProfile(
                    configPath = finalPath.absolutePath,
                    routeMode = when (routeMode) {
                        "selectedApps" -> "selected_apps"
                        else -> "device"
                    },
                    quickSettingsEligible = quickSettingsEligible,
                ),
            )
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
    ): Map<String, Any?> {
        val persistedProfile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        if (AndroidRuntimeState.resolveEnvironment(activity) == null) {
            return snapshot()
        }
        if (!AndroidRuntimeState.initialize(activity)) {
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
        val pending = pendingRequest ?: currentOrBeginPendingConnect(stagedConfigPath)
        if (!isCurrentPendingConnect(pending)) {
            return AndroidRuntimeState.snapshot()
        }

        if (checkNotificationPermission) {
            when (notificationPermissionAction()) {
                AndroidNotificationPermissionAction.REQUEST -> {
                    if (!setNotificationPermissionRequest(pending)) {
                        return AndroidRuntimeState.snapshot()
                    }
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
                AndroidNotificationPermissionAction.CONTINUE_WITH_WARNING ->
                    AndroidRuntimeState.markSystemNotificationWarning()
                AndroidNotificationPermissionAction.WAIT_FOR_RESULT ->
                    return AndroidRuntimeState.snapshot()
                AndroidNotificationPermissionAction.CONTINUE ->
                    AndroidRuntimeState.clearSystemNotificationWarning()
            }
        }

        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            AndroidRuntimeState.markPermissionRequested()
            if (!setVpnPermissionRequest(pending)) {
                return AndroidRuntimeState.snapshot()
            }
            activity.runOnUiThread {
                activity.startActivityForResult(prepareIntent, REQUEST_VPN_PERMISSION)
            }
            return AndroidRuntimeState.snapshot()
        }

        runCatching {
            PokrovRuntimeVpnService.start(activity, stagedConfigPath, routeMode)
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

    private fun disconnect(): Map<String, Any?> {
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
            writePrivateConfig(File(stagedConfigPath), configPayload)
            AndroidRuntimeProfileStore.save(
                activity,
                PersistedRuntimeProfile(
                    configPath = stagedConfigPath,
                ),
            )
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
        if (target.exists() && !target.delete()) {
            throw IllegalStateException("Could not replace the staged profile.")
        }
        if (!next.renameTo(target)) {
            throw IllegalStateException("Could not activate the staged profile.")
        }
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

    private fun currentOrBeginPendingConnect(configPath: String): PendingRuntimeConnect {
        val (pending, created) = pendingConnectGate.acquire(configPath)
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
        pendingConnectGate.isCurrent(pending) && AndroidRuntimeState.isConnectionPending()

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

    @Suppress("DEPRECATION")
    private fun listInstalledApps(): List<Map<String, String>> {
        val packageManager = activity.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val activities = packageManager.queryIntentActivities(launcherIntent, 0)
        return activities
            .mapNotNull { resolveInfo ->
                val packageName = resolveInfo.activityInfo?.packageName
                    ?: return@mapNotNull null
                val label = resolveInfo.loadLabel(packageManager)
                    ?.toString()
                    ?.trim()
                    .orEmpty()
                mapOf(
                    "label" to if (label.isBlank()) packageName else label,
                    "identifier" to packageName,
                    "subtitle" to packageName,
                )
            }
            .distinctBy { app -> app["identifier"] }
            .sortedBy { app -> app["label"]?.lowercase() }
    }

    companion object {
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
        private const val METHOD_LIST_INSTALLED_APPS = "runtimeEngine.listInstalledApps"
        private const val METHOD_CURRENT_WIFI = "runtimeEngine.currentWifi"
        private const val METHOD_REQUEST_WIFI_PERMISSION =
            "runtimeEngine.requestWifiPermission"
        private const val METHOD_OPEN_VPN_SETTINGS = "runtimeEngine.openVpnSettings"
        private const val REQUEST_WIFI_PERMISSION = 14073
        private const val REQUEST_NOTIFICATION_PERMISSION = 14074
    }
}
