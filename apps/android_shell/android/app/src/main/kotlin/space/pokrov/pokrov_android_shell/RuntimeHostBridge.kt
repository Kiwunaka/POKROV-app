package space.pokrov.pokrov_android_shell

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.VpnService
import java.io.File
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.mobile.Mobile

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
                    message = "VPN permission was granted, but no staged config is available.",
                )
                return
            }
            runCatching {
                PokrovRuntimeVpnService.start(activity, stagedConfigPath)
            }.onFailure { error ->
                AndroidRuntimeState.markFailure(
                    kind = "runtime_start_after_permission_failed",
                    message = "Android runtime start failed after VPN permission: ${error.message ?: error.javaClass.simpleName}",
                )
            }
            return
        }

        AndroidRuntimeState.markFailure(
            kind = "vpn_permission_denied",
            message = "VPN permission was denied. The runtime service was not started.",
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
                    message = "Missing profileName for host staging.",
                )
                return AndroidRuntimeState.snapshot()
            }
        val configPayload = call.argument<String>("configPayload")
            ?: run {
                AndroidRuntimeState.markFailure(
                    kind = "missing_config_payload",
                    message = "Missing configPayload for host staging.",
                )
                return AndroidRuntimeState.snapshot()
            }
        val materializedForRuntime = call.argument<Boolean>("materializedForRuntime") ?: false

        val tempPath = File(runtimeEnvironment.tempDirectory, "$profileName.seed.json")
        val finalPath = File(runtimeEnvironment.configDirectory, "$profileName.json")

        return try {
            Mobile.touch()
            if (materializedForRuntime) {
                finalPath.writeText(configPayload)
            } else {
                tempPath.writeText(configPayload)
                Mobile.parse(finalPath.absolutePath, tempPath.absolutePath, false)
            }
            AndroidRuntimeState.markProfileStaged(finalPath.absolutePath)
            AndroidRuntimeState.snapshot()
        } catch (error: Throwable) {
            AndroidRuntimeState.markFailure(
                kind = "profile_staging_failed",
                message = "Android managed profile staging failed: ${error.message ?: error.javaClass.simpleName}",
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
                message = "Stage a managed profile before starting the Android runtime service.",
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
                message = "Android runtime start failed: ${error.message ?: error.javaClass.simpleName}",
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
                message = "Android runtime stop failed: ${error.message ?: error.javaClass.simpleName}",
            )
        }
        return AndroidRuntimeState.snapshot()
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
    }
}
