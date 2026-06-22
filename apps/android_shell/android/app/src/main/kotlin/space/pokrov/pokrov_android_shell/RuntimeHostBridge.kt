package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.VpnService
import java.io.File
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.mobile.Mobile
import org.json.JSONObject

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

    private fun snapshot(): Map<String, Any?> {
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
        val runtimeOptionsJson = call.argument<String>("runtimeOptionsJson")
            ?.takeIf { it.isNotBlank() }

        val tempPath = File(runtimeEnvironment.tempDirectory, "$profileName.seed.json")
        val finalPath = File(runtimeEnvironment.configDirectory, "$profileName.json")
        val basePath = File(runtimeEnvironment.configDirectory, "$profileName.base.json")

        return try {
            Mobile.touch()
            val parsedConfig = if (materializedForRuntime) {
                configPayload
            } else {
                tempPath.writeText(configPayload)
                Mobile.parse(finalPath.absolutePath, tempPath.absolutePath, false)
                finalPath.readText()
            }
            basePath.writeText(parsedConfig)
            val runtimeConfig = if (runtimeOptionsJson.isNullOrBlank()) {
                parsedConfig
            } else {
                Mobile.buildConfig(runtimeOptionsJson, parsedConfig)
            }
            finalPath.writeText(runtimeConfig)
            AndroidRuntimeState.markProfileStaged(
                finalPath.absolutePath,
                runtimeOptionsJson,
                basePath.absolutePath,
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
        val enabled = call.argument<Boolean>("enabled") ?: false
        val stagedConfigPath = AndroidRuntimeState.stagedConfigPath()
        val stagedBaseConfigPath = AndroidRuntimeState.stagedBaseConfigPath()
        val runtimeOptionsJson = AndroidRuntimeState.stagedRuntimeOptionsJson()
        if (stagedConfigPath.isNullOrBlank()) {
            return mapOf(
                "applied" to false,
                "effectiveAt" to "none",
                "fallbackUsed" to false,
                "reason" to "no_staged_profile",
            )
        }
        if (runtimeOptionsJson.isNullOrBlank() || stagedBaseConfigPath.isNullOrBlank()) {
            return mapOf(
                "applied" to false,
                "effectiveAt" to "none",
                "fallbackUsed" to false,
                "reason" to "runtime_options_missing",
            )
        }
        return try {
            val options = JSONObject(runtimeOptionsJson)
            val warp = options.optJSONObject("warp") ?: JSONObject()
            warp.put("enable", enabled)
            if (!warp.has("id")) {
                warp.put("id", "p1")
            }
            if (!warp.has("mode")) {
                warp.put("mode", "proxy_over_warp")
            }
            options.put("warp", warp)
            val nextOptions = options.toString()
            val baseConfig = File(stagedBaseConfigPath).readText()
            val runtimeConfig = Mobile.buildConfig(nextOptions, baseConfig)
            File(stagedConfigPath).writeText(runtimeConfig)
            AndroidRuntimeState.markRuntimeOptionsUpdated(nextOptions)
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

    private fun pushToken(): Map<String, Any?> {
        return mapOf(
            "token" to "",
            "provider" to "poll",
        )
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
        private const val METHOD_CONNECT = "runtimeEngine.connect"
        private const val METHOD_DISCONNECT = "runtimeEngine.disconnect"
        private const val METHOD_APPLY_WARP = "runtimeEngine.applyWarp"
        private const val METHOD_LIVE_STATS = "runtimeEngine.liveStats"
        private const val METHOD_PUSH_TOKEN = "runtimeEngine.pushToken"
        private const val METHOD_LIST_INSTALLED_APPS = "runtimeEngine.listInstalledApps"
    }
}
