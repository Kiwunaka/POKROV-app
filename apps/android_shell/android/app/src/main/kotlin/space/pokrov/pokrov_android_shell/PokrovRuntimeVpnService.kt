package space.pokrov.pokrov_android_shell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.VpnService
import android.os.Handler
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.RoutePrefixIterator
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface as JavaNetworkInterface
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PokrovRuntimeVpnService : VpnService(), PlatformInterface {
    private var boxService: BoxService? = null
    private var activeTun: ParcelFileDescriptor? = null
    private val runtimeExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(LOG_TAG, "Received STOP for Android runtime service.")
                runtimeExecutor.execute {
                    stopRuntime(
                        message = "Android runtime service stopped cleanly.",
                        stopReason = "user_requested",
                    )
                    mainHandler.post { stopSelf() }
                }
            }
            ACTION_START -> {
                val configPath = intent.getStringExtra(EXTRA_CONFIG_PATH)
                if (configPath.isNullOrBlank()) {
                    AndroidRuntimeState.markFailure(
                        kind = "missing_staged_config",
                        message = "Android runtime start is missing a staged config path.",
                    )
                    Log.e(LOG_TAG, "Android runtime start is missing a staged config path.")
                    stopSelf()
                } else {
                    try {
                        Log.i(LOG_TAG, "Received START for Android runtime service with configPath=$configPath")
                        markServiceStarting()
                        beginForegroundRuntime()
                        runtimeExecutor.execute {
                            startRuntime(configPath)
                        }
                    } catch (error: Throwable) {
                        AndroidRuntimeState.markFailure(
                            kind = "foreground_start_failed",
                            message = "Android runtime foreground start failed: ${error.message ?: error.javaClass.simpleName}",
                        )
                        Log.e(LOG_TAG, "Android foreground start failed.", error)
                        stopSelf()
                    }
                }
            }
            else -> Unit
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (boxService != null || activeTun != null) {
            runtimeExecutor.execute {
                stopRuntime(
                    message = "Android runtime service stopped.",
                    stopReason = "service_destroyed",
                )
            }
        }
        runtimeExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRevoke() {
        runtimeExecutor.execute {
            stopRuntime(
                message = "Android runtime VPN permission was revoked.",
                stopReason = "vpn_permission_revoked",
            )
            mainHandler.post { stopSelf() }
        }
        super.onRevoke()
    }

    private fun startRuntime(configPath: String) {
        val initialized = AndroidRuntimeState.initialize(this)
        if (!initialized) {
            Log.e(LOG_TAG, "Android runtime initialize() failed before service start.")
            stopSelf()
            return
        }

        try {
            val content = File(configPath)
                .takeIf { it.exists() }
                ?.readText()
                ?.removePrefix("\uFEFF")
            if (content.isNullOrBlank()) {
                throw IllegalStateException("Staged runtime config is missing or empty.")
            }
            Log.i(LOG_TAG, "Starting Android runtime using staged config $configPath")
            AndroidDefaultNetworkMonitor.ensureStarted(this)
            Libbox.registerLocalDNSTransport(AndroidLocalResolver as LocalDNSTransport)
            boxService?.close()
            boxService = Libbox.newService(content, this)
            boxService?.start()
            AndroidRuntimeState.markProfileStaged(configPath)
            Log.i(LOG_TAG, "Android runtime service start requested successfully; waiting for tun establishment.")
        } catch (error: Throwable) {
            AndroidRuntimeState.markFailure(
                kind = "runtime_service_start_failed",
                message = "Android runtime service failed to start: ${error.message ?: error.javaClass.simpleName}",
            )
            Log.e(LOG_TAG, "Android runtime service failed to start.", error)
            stopSelf()
        }
    }

    private fun stopRuntime(message: String, stopReason: String) {
        Log.i(LOG_TAG, "Stopping Android runtime service: $message")
        markServiceStopped()
        try {
            boxService?.close()
        } catch (_: Throwable) {
        }
        boxService = null
        runCatching { Libbox.registerLocalDNSTransport(null) }
        AndroidDefaultNetworkMonitor.stop(null)
        try {
            activeTun?.close()
        } catch (_: Throwable) {
        }
        activeTun = null
        AndroidRuntimeState.markStopped(message = message, stopReason = stopReason)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(contentText: String, title: String = "POKROV runtime"): Notification {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "POKROV Runtime",
                NotificationManager.IMPORTANCE_LOW,
            )
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_STOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Disconnect",
                    stopIntent,
                ).build(),
            )
            .apply {
                if (pendingIntent != null) {
                    setContentIntent(pendingIntent)
                }
            }
            .build()
    }

    private fun beginForegroundRuntime() {
        val notification = buildNotification(
            contentText = "Starting runtime service...",
            title = "POKROV starting",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
            return
        }

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        if (!protect(fd)) {
            Log.w(LOG_TAG, "Failed to protect Android control socket fd=$fd from VPN capture.")
        }
    }

    override fun clearDNSCache() {
        // No host-side DNS cache layer is owned by this seed.
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        AndroidDefaultNetworkMonitor.stop(listener)
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return -1
        }
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val uid = connectivityManager.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )
        return if (uid == Process.INVALID_UID) {
            -1
        } else {
            uid
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val iterator = JavaNetworkInterface.getNetworkInterfaces()
        val interfaces = mutableListOf<io.nekohasekai.libbox.NetworkInterface>()
        while (iterator.hasMoreElements()) {
            val resolvedInterface = iterator.nextElement()
            runCatching {
                io.nekohasekai.libbox.NetworkInterface().apply {
                    setIndex(resolvedInterface.index)
                    setMTU(runCatching { resolvedInterface.mtu }.getOrDefault(0))
                    setName(resolvedInterface.name ?: "")
                    setAddresses(
                        LibboxStringIterator(
                            resolvedInterface.interfaceAddresses
                                .mapNotNull interfaceAddressMap@{ interfaceAddress ->
                                    val address = interfaceAddress.address
                                        ?: return@interfaceAddressMap null
                                    AndroidPlatformRuntimeBridge.toLibboxPrefix(
                                        address,
                                        interfaceAddress.networkPrefixLength,
                                    )
                                },
                        ),
                    )
                }
            }.getOrNull()?.let(interfaces::add)
        }
        return LibboxNetworkInterfaceIterator(interfaces)
    }

    override fun includeAllNetworks(): Boolean = false

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) {
            error("android: missing vpn permission")
        }

        val builder = Builder()
            .setSession("sing-box")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val mtu = options.getMTU()
        if (mtu > 0) {
            builder.setMtu(mtu)
        }

        var hasIpv4Address = false
        var hasIpv6Address = false
        var hasIpv4Route = false
        var hasIpv6Route = false
        var hasIpv4DefaultRoute = false
        var hasIpv6DefaultRoute = false
        var ipv4AddressCount = 0
        var ipv6AddressCount = 0
        var ipv4RouteCount = 0
        var ipv6RouteCount = 0
        var ipv4ExcludeRouteCount = 0
        var ipv6ExcludeRouteCount = 0
        var includePackageCount = 0
        var excludePackageCount = 0

        consumePrefixes(options.getInet4Address()) { prefix ->
            builder.addAddress(prefix.address(), prefix.prefix())
            hasIpv4Address = true
            ipv4AddressCount += 1
        }
        consumePrefixes(options.getInet6Address()) { prefix ->
            builder.addAddress(prefix.address(), prefix.prefix())
            hasIpv6Address = true
            ipv6AddressCount += 1
        }
        if (options.getAutoRoute()) {
            val dnsServerAddress = runCatching { options.getDNSServerAddress() }.getOrNull()
            dnsServerAddress
                ?.takeIf { it.isNotBlank() }
                ?.let(builder::addDnsServer)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                consumePrefixes(options.getInet4RouteAddress()) { prefix ->
                    builder.addRoute(IpPrefixCompat(prefix))
                    hasIpv4Route = true
                    if (isDefaultIpv4Route(prefix)) {
                        hasIpv4DefaultRoute = true
                    }
                    ipv4RouteCount += 1
                }
                consumePrefixes(options.getInet6RouteAddress()) { prefix ->
                    builder.addRoute(IpPrefixCompat(prefix))
                    hasIpv6Route = true
                    if (isDefaultIpv6Route(prefix)) {
                        hasIpv6DefaultRoute = true
                    }
                    ipv6RouteCount += 1
                }
                consumePrefixes(options.getInet4RouteExcludeAddress()) { prefix ->
                    builder.excludeRoute(IpPrefixCompat(prefix))
                    ipv4ExcludeRouteCount += 1
                }
                consumePrefixes(options.getInet6RouteExcludeAddress()) { prefix ->
                    builder.excludeRoute(IpPrefixCompat(prefix))
                    ipv6ExcludeRouteCount += 1
                }
            } else {
                consumePrefixes(options.getInet4RouteRange()) { prefix ->
                    builder.addRoute(prefix.address(), prefix.prefix())
                    hasIpv4Route = true
                    if (isDefaultIpv4Route(prefix)) {
                        hasIpv4DefaultRoute = true
                    }
                    ipv4RouteCount += 1
                }
                consumePrefixes(options.getInet6RouteRange()) { prefix ->
                    builder.addRoute(prefix.address(), prefix.prefix())
                    hasIpv6Route = true
                    if (isDefaultIpv6Route(prefix)) {
                        hasIpv6DefaultRoute = true
                    }
                    ipv6RouteCount += 1
                }
            }

            val routePlan = AndroidTunRoutePlanner.plan(
                autoRoute = true,
                hasIpv4Address = hasIpv4Address,
                hasIpv6Address = hasIpv6Address,
                hasIpv4Route = hasIpv4Route,
                hasIpv6Route = hasIpv6Route,
                hasIpv4DefaultRoute = hasIpv4DefaultRoute,
                hasIpv6DefaultRoute = hasIpv6DefaultRoute,
            )
            if (routePlan.addDefaultIpv4Route) {
                builder.addRoute("0.0.0.0", 0)
                hasIpv4Route = true
                ipv4RouteCount += 1
            }
            if (routePlan.addDefaultIpv6Route) {
                builder.addRoute("::", 0)
                hasIpv6Route = true
                ipv6RouteCount += 1
            }

            consumeStrings(options.getIncludePackage()) { packageName ->
                runCatching { builder.addAllowedApplication(packageName) }
                includePackageCount += 1
            }
            consumeStrings(options.getExcludePackage()) { packageName ->
                runCatching { builder.addDisallowedApplication(packageName) }
                excludePackageCount += 1
            }

            Log.i(
                LOG_TAG,
                "openTun autoRoute=${options.getAutoRoute()} dns=${dnsServerAddress ?: "<none>"} " +
                    "ipv4Addr=$ipv4AddressCount ipv6Addr=$ipv6AddressCount " +
                    "ipv4Routes=$ipv4RouteCount ipv6Routes=$ipv6RouteCount " +
                    "ipv4Default=$hasIpv4DefaultRoute ipv6Default=$hasIpv6DefaultRoute " +
                    "ipv4Excludes=$ipv4ExcludeRouteCount ipv6Excludes=$ipv6ExcludeRouteCount " +
                    "allowIpv4=${routePlan.allowIpv4} allowIpv6=${routePlan.allowIpv6} " +
                    "defaultIpv4=${routePlan.addDefaultIpv4Route} defaultIpv6=${routePlan.addDefaultIpv6Route} " +
                    "includePkgs=$includePackageCount excludePkgs=$excludePackageCount",
            )
        }
        AndroidRuntimeState.recordTunConfiguration(
            ipv4RouteCount = ipv4RouteCount,
            ipv6RouteCount = ipv6RouteCount,
            includePackageCount = includePackageCount,
            excludePackageCount = excludePackageCount,
        )

        activeTun?.close()
        val tun = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null.")
        activeTun = tun
        val runtimeMessage =
            "Android tun established. dns=${runCatching { options.getDNSServerAddress() }.getOrNull() ?: "<none>"} " +
                "ipv4Routes=$ipv4RouteCount ipv6Routes=$ipv6RouteCount " +
                "defaultIpv4=$hasIpv4DefaultRoute defaultIpv6=$hasIpv6DefaultRoute"
        markTunEstablished(runtimeMessage)
        AndroidRuntimeState.markRunning(runtimeMessage)
        Log.i(LOG_TAG, runtimeMessage)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            NOTIFICATION_ID,
            buildNotification(
                contentText = "Runtime service is running.",
                title = "POKROV connected",
            ),
        )
        return tun.fd
    }

    override fun packageNameByUid(uid: Int): String {
        return packageManager.getPackagesForUid(uid)?.firstOrNull().orEmpty()
    }

    override fun readWIFIState(): WIFIState? = null

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        AndroidDefaultNetworkMonitor.start(this, listener)
    }

    override fun uidByPackageName(packageName: String): Int {
        return packageManager.getApplicationInfo(packageName, 0).uid
    }

    override fun underNetworkExtension(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean =
        AndroidPlatformRuntimeBridge.supportFlags(Build.VERSION.SDK_INT)
            .usePlatformAutoDetectInterfaceControl

    override fun usePlatformDefaultInterfaceMonitor(): Boolean =
        AndroidPlatformRuntimeBridge.supportFlags(Build.VERSION.SDK_INT)
            .usePlatformDefaultInterfaceMonitor

    override fun usePlatformInterfaceGetter(): Boolean =
        AndroidPlatformRuntimeBridge.supportFlags(Build.VERSION.SDK_INT)
            .usePlatformInterfaceGetter

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun writeLog(message: String) {
        Log.d(LOG_TAG, message)
    }

    private fun consumeStrings(iterator: StringIterator?, block: (String) -> Unit) {
        if (iterator == null) {
            return
        }
        while (iterator.hasNext()) {
            val value = iterator.next()
            if (value.isNotBlank()) {
                block(value)
            }
        }
    }

    private fun consumePrefixes(iterator: RoutePrefixIterator?, block: (RoutePrefix) -> Unit) {
        if (iterator == null) {
            return
        }
        while (iterator.hasNext()) {
            block(iterator.next())
        }
    }

    private fun isDefaultIpv4Route(prefix: RoutePrefix): Boolean {
        return prefix.prefix() == 0 && prefix.address() == "0.0.0.0"
    }

    private fun isDefaultIpv6Route(prefix: RoutePrefix): Boolean {
        return prefix.prefix() == 0 && prefix.address() == "::"
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun IpPrefixCompat(prefix: RoutePrefix): android.net.IpPrefix {
        return android.net.IpPrefix(
            InetAddress.getByName(prefix.address()),
            prefix.prefix(),
        )
    }

    private class LibboxStringIterator(
        private val values: List<String>,
    ) : StringIterator {
        private var index = 0

        override fun hasNext(): Boolean = index < values.size

        override fun next(): String = values[index++]
    }

    private class LibboxNetworkInterfaceIterator(
        private val values: List<io.nekohasekai.libbox.NetworkInterface>,
    ) : NetworkInterfaceIterator {
        private var index = 0

        override fun hasNext(): Boolean = index < values.size

        override fun next(): io.nekohasekai.libbox.NetworkInterface = values[index++]
    }

    companion object {
        private const val LOG_TAG = "PokrovRuntimeVpn"
        private const val NOTIFICATION_CHANNEL_ID = "pokrov-runtime"
        private const val NOTIFICATION_ID = 1407
        const val ACTION_START = "space.pokrov.runtime.START"
        const val ACTION_STOP = "space.pokrov.runtime.STOP"
        const val EXTRA_CONFIG_PATH = "extra_config_path"
        @Volatile
        private var tunEstablished: Boolean = false
        @Volatile
        private var currentRuntimeMessage: String? = null

        fun isTunEstablished(): Boolean = tunEstablished

        fun latestRuntimeMessage(): String? = currentRuntimeMessage

        private fun markServiceStarting() {
            tunEstablished = false
            currentRuntimeMessage = "Android runtime service is starting."
        }

        private fun markTunEstablished(message: String) {
            tunEstablished = true
            currentRuntimeMessage = message
        }

        private fun markServiceStopped() {
            tunEstablished = false
            currentRuntimeMessage = null
        }

        fun start(context: Context, configPath: String) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CONFIG_PATH, configPath)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
