package space.pokrov.pokrov_android_shell

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var runtimeChannel: MethodChannel? = null
    private var externalLinkChannel: MethodChannel? = null
    private var appPickerChannel: MethodChannel? = null
    private var runtimeHostBridge: RuntimeHostBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        runtimeHostBridge = RuntimeHostBridge(this)
        val taskQueue = flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
        runtimeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RuntimeHostBridge.CHANNEL_NAME,
            StandardMethodCodec.INSTANCE,
            taskQueue,
        ).also { channel ->
            channel.setMethodCallHandler(runtimeHostBridge)
        }
        externalLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXTERNAL_LINK_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "openExternal") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val target = call.argument<String>("target")?.trim().orEmpty()
                if (!isAllowedExternalTarget(target)) {
                    result.success(false)
                    return@setMethodCallHandler
                }

                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                        addCategory(Intent.CATEGORY_BROWSABLE)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (_: IllegalArgumentException) {
                    result.success(false)
                }
            }
        }
        appPickerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_PICKER_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "listSelectableApps") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(listLaunchableApps())
            }
        }
    }

    override fun onResume() {
        super.onResume()
        runtimeHostBridge?.handleDebugIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        runtimeHostBridge?.handleDebugIntent(intent)
    }

    @Deprecated("Uses the platform VPN permission callback for the seed runtime lane.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        runtimeHostBridge?.onActivityResult(requestCode, resultCode)
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        runtimeChannel?.setMethodCallHandler(null)
        runtimeChannel = null
        externalLinkChannel?.setMethodCallHandler(null)
        externalLinkChannel = null
        appPickerChannel?.setMethodCallHandler(null)
        appPickerChannel = null
        runtimeHostBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isAllowedExternalTarget(target: String): Boolean {
        val uri = Uri.parse(target)
        val scheme = uri.scheme?.lowercase().orEmpty()
        if (scheme == "tg" || scheme == "mailto") {
            return true
        }
        if (scheme != "https") {
            return false
        }
        val host = uri.host?.lowercase().orEmpty()
        return host == "pokrov.space" || host.endsWith(".pokrov.space") || host == "t.me"
    }

    private fun listLaunchableApps(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        @Suppress("DEPRECATION")
        return packageManager.queryIntentActivities(intent, 0)
            .asSequence()
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName?.trim().orEmpty()
                if (packageName.isEmpty() || packageName == applicationContext.packageName) {
                    null
                } else {
                    mapOf(
                        "id" to packageName,
                        "name" to info.loadLabel(packageManager).toString(),
                        "source" to "installed",
                    )
                }
            }
            .distinctBy { it["id"] }
            .sortedBy { it["name"]?.lowercase().orEmpty() }
            .take(80)
            .toList()
    }

    companion object {
        private const val EXTERNAL_LINK_CHANNEL_NAME = "space.pokrov/external_link"
        private const val APP_PICKER_CHANNEL_NAME = "space.pokrov/app_picker"
    }
}
