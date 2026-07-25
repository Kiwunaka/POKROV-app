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

class RuntimeHostBridge(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private var handledDebugPath: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_SNAPSHOT -> result.success(snapshot())
            METHOD_INITIALIZE -> result.success(initialize())
            METHOD_STAGE_MANAGED_PROFILE -> result.success(stageManagedProfile(call))
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

        if (resultCode == Activity.RESULT_OK) {
            val stagedConfigPath = AndroidRuntimeState.stagedConfigPath()
            if (stagedConfigPath.isNullOrBlank()) {
                AndroidRuntimeState.markFailure(
                    kind = "missing_staged_config",
                    message = "Разрешение получено, но на устройстве еще нет настроек подключения.",
                )
                return
            }
            runCatching {
                PokrovRuntimeVpnService.start(activity, stagedConfigPath)
            }.onFailure { error ->
                AndroidRuntimeState.markFailure(
                    kind = "runtime_start_after_permission_failed",
                    message = "POKROV не смог завершить подключение после разрешения: ${error.message ?: error.javaClass.simpleName}",
                )
            }
            return
        }

        AndroidRuntimeState.markFailure(
            kind = "vpn_permission_denied",
            message = "Разрешение отклонено, поэтому POKROV не смог подключиться на этом устройстве.",
        )
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

    fun handleSystemIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_TILE_CONNECT, false) != true) {
            return
        }
        intent.removeExtra(EXTRA_TILE_CONNECT)
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        connect()
    }

    private fun snapshot(): Map<String, Any?> {
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        if (AndroidRuntimeState.resolveEnvironment(activity) == null) {
            return AndroidRuntimeState.snapshot()
        }
        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = PokrovRuntimeVpnService.isTunEstablished(),
            runningMessage = PokrovRuntimeVpnService.latestRuntimeMessage(),
        )
        return AndroidRuntimeState.snapshot()
    }

    private fun initialize(): Map<String, Any?> {
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
        AndroidRuntimeState.initialize(activity)
        return AndroidRuntimeState.snapshot()
    }

    private fun stageManagedProfile(call: MethodCall): Map<String, Any?> {
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
                ),
            )
            AndroidRuntimeState.snapshot()
        } catch (error: Throwable) {
            AndroidRuntimeState.markFailure(
                kind = "profile_staging_failed",
                message = "POKROV не смог завершить подготовку устройства: ${error.message ?: error.javaClass.simpleName}",
            )
            AndroidRuntimeState.snapshot()
        }
    }

    private fun connect(): Map<String, Any?> {
        AndroidRuntimeProfileStore.restoreIntoRuntimeState(activity)
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

        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            AndroidRuntimeState.markPermissionRequested()
            activity.runOnUiThread {
                activity.startActivityForResult(prepareIntent, REQUEST_VPN_PERMISSION)
            }
            return AndroidRuntimeState.snapshot()
        }

        runCatching {
            PokrovRuntimeVpnService.start(activity, stagedConfigPath)
        }.onFailure { error ->
            AndroidRuntimeState.markFailure(
                kind = "runtime_start_failed",
                message = "POKROV не смог подключиться на этом устройстве: ${error.message ?: error.javaClass.simpleName}",
            )
        }
        return AndroidRuntimeState.snapshot()
    }

    private fun disconnect(): Map<String, Any?> {
        AndroidRuntimeState.markStopRequested(stopReason = "user_requested")
        runCatching {
            PokrovRuntimeVpnService.stop(activity)
        }.onFailure { error ->
            AndroidRuntimeState.markFailure(
                kind = "runtime_stop_failed",
                message = "POKROV не смог корректно отключиться: ${error.message ?: error.javaClass.simpleName}",
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
                "reason" to (error.message ?: error.javaClass.simpleName),
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
        const val EXTRA_TILE_CONNECT = "space.pokrov.tile.CONNECT"
        private const val METHOD_SNAPSHOT = "runtimeEngine.snapshot"
        private const val METHOD_INITIALIZE = "runtimeEngine.initialize"
        private const val METHOD_STAGE_MANAGED_PROFILE = "runtimeEngine.stageManagedProfile"
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
    }
}
