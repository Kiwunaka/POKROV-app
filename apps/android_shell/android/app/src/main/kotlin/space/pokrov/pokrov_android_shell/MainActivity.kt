package space.pokrov.pokrov_android_shell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var runtimeChannel: MethodChannel? = null
    private var acquisitionLinksChannel: MethodChannel? = null
    private var supportExportChannel: MethodChannel? = null
    private var runtimeHostBridge: RuntimeHostBridge? = null
    private var pendingSupportExport: PendingSupportExport? = null

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
        supportExportChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SUPPORT_EXPORT_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "saveEncryptedBundle") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSupportExport != null) {
                    result.error("support_export_busy", "Another export is active.", null)
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                val name = arguments?.get("name") as? String
                val bytes = arguments?.get("bytes") as? ByteArray
                if (name == null ||
                    !SUPPORT_EXPORT_NAME.matches(name) ||
                    bytes == null ||
                    bytes.isEmpty() ||
                    bytes.size > MAXIMUM_SUPPORT_EXPORT_BYTES ||
                    !isEncryptedSupportEnvelope(bytes, name.removeSuffix(".pokrov-support"))
                ) {
                    result.error("support_export_invalid", "Encrypted support bundle is invalid.", null)
                    return@setMethodCallHandler
                }
                pendingSupportExport = PendingSupportExport(name, bytes.copyOf(), result)
                val intent = android.content.Intent(android.content.Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(android.content.Intent.CATEGORY_OPENABLE)
                    type = "application/vnd.pokrov.support-bundle+json"
                    putExtra(android.content.Intent.EXTRA_TITLE, name)
                }
                try {
                    startActivityForResult(intent, SUPPORT_EXPORT_REQUEST_CODE)
                } catch (_: android.content.ActivityNotFoundException) {
                    pendingSupportExport?.bytes?.fill(0)
                    pendingSupportExport = null
                    result.error("support_export_unavailable", "No document provider is available.", null)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        PokrovQuickSettingsTileService.ensureActiveModeRegistration(this)
        PokrovQuickSettingsTileService.requestRefresh(this)
        runtimeHostBridge?.resumePendingUpdateInstall()
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
        if (requestCode == SUPPORT_EXPORT_REQUEST_CODE) {
            val pending = pendingSupportExport
            pendingSupportExport = null
            if (pending == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            val uri = data?.data
            if (resultCode != android.app.Activity.RESULT_OK || uri == null) {
                pending.bytes.fill(0)
                pending.result.success(null)
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            try {
                contentResolver.openOutputStream(uri, "w").use { output ->
                    requireNotNull(output) { "document provider returned no stream" }
                    output.write(pending.bytes)
                    output.flush()
                }
                pending.result.success(uri.toString())
            } catch (_: Exception) {
                pending.result.error("support_export_failed", "Encrypted export failed.", null)
            } finally {
                pending.bytes.fill(0)
            }
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
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
        supportExportChannel?.setMethodCallHandler(null)
        supportExportChannel = null
        pendingSupportExport?.bytes?.fill(0)
        pendingSupportExport?.result?.error(
            "support_export_cancelled",
            "The application closed before export completed.",
            null,
        )
        pendingSupportExport = null
        runtimeHostBridge?.close()
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

    private fun isEncryptedSupportEnvelope(bytes: ByteArray, diagnosticId: String): Boolean {
        return try {
            val value = JSONObject(bytes.toString(Charsets.UTF_8))
            val expected = setOf(
                "algorithm",
                "bundle_sha256",
                "ciphertext_b64",
                "diagnostic_id",
                "ephemeral_public_key_b64",
                "mac_b64",
                "manifest_sha256",
                "nonce_b64",
                "recipient_key_id",
                "schema_version",
            )
            val actual = value.keys().asSequence().toSet()
            actual == expected &&
                value.optInt("schema_version", -1) == 1 &&
                value.optString("algorithm") == "X25519-HKDF-SHA256-AES-256-GCM" &&
                value.optString("diagnostic_id") == diagnosticId &&
                value.optString("ciphertext_b64").isNotBlank()
        } catch (_: Exception) {
            false
        }
    }

    private data class PendingSupportExport(
        val name: String,
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    private companion object {
        const val ACQUISITION_LINKS_CHANNEL_NAME = "space.pokrov/acquisition-links"
        const val SUPPORT_EXPORT_CHANNEL_NAME = "space.pokrov/support-export"
        const val SUPPORT_EXPORT_REQUEST_CODE = 7403
        const val MAXIMUM_SUPPORT_EXPORT_BYTES = 2_621_440
        val SUPPORT_EXPORT_NAME = Regex("^diag-[0-9a-f]{24}\\.pokrov-support$")
    }
}
