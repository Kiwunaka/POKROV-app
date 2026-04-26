package space.pokrov.pokrov_android_shell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var runtimeChannel: MethodChannel? = null
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
        runtimeHostBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
