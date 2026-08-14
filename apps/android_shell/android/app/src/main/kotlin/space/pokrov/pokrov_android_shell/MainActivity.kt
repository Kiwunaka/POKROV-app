package space.pokrov.pokrov_android_shell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var runtimeChannel: MethodChannel? = null
    private var acquisitionLinksChannel: MethodChannel? = null
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
        acquisitionLinksChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACQUISITION_LINKS_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUri" -> result.success(acquisitionUri(intent))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        PokrovQuickSettingsTileService.ensureActiveModeRegistration(this)
        PokrovQuickSettingsTileService.requestRefresh(this)
        runtimeHostBridge?.handleDebugIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        runtimeHostBridge?.handleDebugIntent(intent)
        acquisitionUri(intent)?.let { uri ->
            acquisitionLinksChannel?.invokeMethod("uriChanged", uri)
        }
    }

    @Deprecated("Uses the platform VPN permission callback for the seed runtime lane.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        runtimeHostBridge?.onActivityResult(requestCode, resultCode)
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        runtimeHostBridge?.onRequestPermissionsResult(requestCode, permissions, grantResults)
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        runtimeChannel?.setMethodCallHandler(null)
        runtimeChannel = null
        acquisitionLinksChannel?.setMethodCallHandler(null)
        acquisitionLinksChannel = null
        runtimeHostBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun acquisitionUri(intent: android.content.Intent?): String? {
        val uri = intent?.data ?: return null
        if (intent.action != android.content.Intent.ACTION_VIEW ||
            !uri.scheme.equals("pokrov", ignoreCase = true) ||
            !uri.host.equals("acquisition", ignoreCase = true) ||
            uri.path != "/continue"
        ) {
            return null
        }
        return uri.toString().takeIf { it.length <= 512 }
    }

    private companion object {
        const val ACQUISITION_LINKS_CHANNEL_NAME = "space.pokrov/acquisition-links"
    }
}
