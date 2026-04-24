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
        runtimeHostBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isAllowedExternalTarget(target: String): Boolean {
        val scheme = Uri.parse(target).scheme?.lowercase().orEmpty()
        return scheme == "http" || scheme == "https" || scheme == "tg" || scheme == "mailto"
    }

    companion object {
        private const val EXTERNAL_LINK_CHANNEL_NAME = "space.pokrov/external_link"
    }
}
