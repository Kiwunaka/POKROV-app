package space.pokrov.pokrov_android_shell

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import space.pokrov.core.libbox.CommandServer
import space.pokrov.core.libbox.CommandServerHandler
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.OverrideOptions
import space.pokrov.core.libbox.SystemProxyStatus
import space.pokrov.core.libbox.RuntimeProbeCancellation
import java.util.concurrent.Executors

/** Owns the selected local carrier for other clients. It never establishes a VPN. */
class PokrovMtsBridgeService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private var network: AndroidTransportNetworkContext? = null
    private var server: CommandServer? = null
    private var serverStarted = false

    override fun onCreate() {
        super.onCreate()
        synchronized(lock) { owner = this }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Подключение для других приложений", NotificationManager.IMPORTANCE_LOW))
        }
        val stop = PendingIntent.getService(
            this, 0, Intent(this, PokrovMtsBridgeService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_pokrov_system)
            .setContentTitle("POKROV для Hiddify и Happ")
            .setContentText("Подключение запущено")
            .setOngoing(true)
            .addAction(0, "Остановить", stop)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            executor.execute { stopBridge() }
            return START_NOT_STICKY
        }
        val request = intent?.getLongExtra(EXTRA_GENERATION, -1L) ?: -1L
        val board = intent?.getStringExtra(EXTRA_BOARD).orEmpty()
        val key = intent?.getStringExtra(EXTRA_KEY).orEmpty()
        executor.execute {
            var verification: CommandServer? = null
            synchronized(lock) {
                if (request != generation || state != "starting" ||
                    PokrovRuntimeVpnService.isTunEstablished() || AndroidRuntimeState.isConnectionPending()) {
                    if (request == generation) state = "error"
                    if (state != "starting") stopSelfResult(startId)
                    return@synchronized
                }
                try {
                    AndroidSystemCertificates.prepare(applicationContext)
                    val context = AndroidTransportNetworkContext(applicationContext)
                    network = context
                    fun currentPlatform(): AndroidCandidateProbePlatform {
                        val current = context.candidateNetwork()
                        return AndroidCandidateProbePlatform(
                            current.network ?: error("uplink_unavailable"),
                            current.links ?: error("uplink_unavailable"),
                        ) { request != generation }
                    }
                    val platform = AndroidApiBootstrapPlatform(currentPlatform(), ::currentPlatform)
                    val handler = object : CommandServerHandler {
                        override fun serviceStop() { executor.execute { stopBridge() } }
                        override fun serviceReload() = Unit
                        override fun getSystemProxyStatus(): SystemProxyStatus =
                            SystemProxyStatus().apply { setAvailable(false); setEnabled(false) }
                        override fun setSystemProxyEnabled(enabled: Boolean) = Unit
                        override fun writeDebugMessage(message: String) = Unit
                    }
                    val next = Libbox.newCommandServer(handler, platform)
                    next.setVkCaptchaHandler(PokrovVkCaptchaHost.handler { id, token ->
                        next.submitVkCaptchaResult(id, token)
                    })
                    server = next
                    val vkConfig = pendingVkConfig
                    pendingVkConfig = null
                    next.startOrReloadService(vkConfig ?: bridgeConfig(board, key), OverrideOptions())
                    serverStarted = true
                    if (vkConfig == null) state = "running" else verification = next
                } catch (_: Throwable) {
                    closeResources()
                    state = "error"
                    stopSelf()
                }
            }
            verification?.let { next ->
                val ready = runCatching {
                    next.prepareVkBridge()
                    next.probeRuntimeEgress("vk-check", 15000, object : RuntimeProbeCancellation {
                        override fun isCancelled(): Boolean = request != generation
                    })
                }.getOrDefault(false)
                synchronized(lock) {
                    if (request == generation && server === next) {
                        if (ready) state = "running" else {
                            closeResources()
                            state = "error"
                            stopSelf()
                        }
                    }
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun closeResources(): Boolean {
        val closed = if (serverStarted) runCatching { server?.closeService() }.isSuccess else true
        val ownerClosed = runCatching { server?.close() }.isSuccess
        serverStarted = false
        server = null
        runCatching { network?.close() }
        network = null
        if (!closed || !ownerClosed) closeFailed = true
        return !closeFailed
    }

    override fun onDestroy() {
        executor.execute {
            synchronized(lock) {
                if (owner === this) {
                    generation++
                    val closed = closeResources()
                    owner = null
                    if (!closed) state = "error"
                    else if (state != "error") state = "stopped"
                }
            }
        }
        executor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "pokrov_mts_bridge"
        private const val NOTIFICATION_ID = 9202
        private const val ACTION_START = "space.pokrov.mts.START"
        private const val ACTION_STOP = "space.pokrov.mts.STOP"
        private const val EXTRA_GENERATION = "generation"
        private const val EXTRA_BOARD = "board"
        private const val EXTRA_KEY = "key"
        private val lock = Any()
        @Volatile private var generation = 0L
        @Volatile private var state = "stopped"
        private var owner: PokrovMtsBridgeService? = null
        private var closeFailed = false
        private var pendingVkConfig: String? = null

        fun status(): String = state

        fun startBridge(context: Context, board: String, key: String): Boolean = synchronized(lock) {
            if (closeFailed || owner != null || state == "starting" || state == "running" ||
                PokrovRuntimeVpnService.isTunEstablished() || AndroidRuntimeState.isConnectionPending()) return false
            generation++
            pendingVkConfig = null
            state = "starting"
            val intent = Intent(context, PokrovMtsBridgeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_GENERATION, generation)
                putExtra(EXTRA_BOARD, board)
                putExtra(EXTRA_KEY, key)
            }
            try {
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (_: Throwable) {
                state = "error"
                false
            }
        }

        fun stopBridge(): Boolean =
            synchronized(lock) {
                generation++
                pendingVkConfig = null
                val service = owner
                val closed = service?.closeResources() ?: !closeFailed
                state = if (closed) "stopped" else "error"
                service?.stopSelf()
                closed
            }

        fun startVkBridge(context: Context, config: String): Boolean = synchronized(lock) {
            if (closeFailed || owner != null || state == "starting" || state == "running" ||
                PokrovRuntimeVpnService.isTunEstablished() || AndroidRuntimeState.isConnectionPending()) return false
            generation++
            pendingVkConfig = config
            state = "starting"
            val intent = Intent(context, PokrovMtsBridgeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_GENERATION, generation)
            }
            try {
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (_: Throwable) {
                pendingVkConfig = null
                state = "error"
                false
            }
        }

        private fun bridgeConfig(board: String, key: String): String = JSONObject()
            .put("log", JSONObject().put("disabled", true))
            .put("dns", JSONObject().put("servers", JSONArray().put(
                JSONObject().put("type", "udp").put("tag", "bootstrap")
                    .put("server", "77.88.8.8").put("server_port", 53)))
                .put("final", "bootstrap"))
            .put("inbounds", JSONArray().put(JSONObject()
                .put("type", "direct").put("listen", "127.0.0.1").put("listen_port", 9002)
                .put("network", "tcp").put("override_address", "127.0.0.1").put("override_port", 12543)))
            .put("outbounds", JSONArray().put(JSONObject().put("type", "mts").put("tag", "mts")
                .put("board_url", board).put("public_key", key).put("network", "tcp")
                .put("domain_resolver", JSONObject().put("server", "bootstrap"))
                .put("connect_timeout", "20s")))
            .put("route", JSONObject().put("final", "mts").put("auto_detect_interface", true))
            .toString()
    }
}
