package space.pokrov.pokrov_android_shell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.VpnService
import android.graphics.Color
import android.os.Handler
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import space.pokrov.core.libbox.CommandServer
import space.pokrov.core.libbox.CommandServerHandler
import space.pokrov.core.libbox.ConnectionOwner
import space.pokrov.core.libbox.InterfaceUpdateListener
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.LocalDNSTransport
import space.pokrov.core.libbox.NetworkInterfaceIterator
import space.pokrov.core.libbox.Notification as LibboxNotification
import space.pokrov.core.libbox.OverrideOptions
import space.pokrov.core.libbox.PlatformInterface
import space.pokrov.core.libbox.RoutePrefix
import space.pokrov.core.libbox.RoutePrefixIterator
import space.pokrov.core.libbox.StringIterator
import space.pokrov.core.libbox.SystemProxyStatus
import space.pokrov.core.libbox.TunOptions
import space.pokrov.core.libbox.WIFIState
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface as JavaNetworkInterface
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PokrovRuntimeVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    private var commandServer: CommandServer? = null
    private var activeConfigContent: String? = null
    private var activeTun: ParcelFileDescriptor? = null
    private val dnsFailureTokenGate = AndroidDnsFailureTokenGate()
    private val runtimeExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val healthExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val healthGeneration = AtomicLong(0L)
    private val lifecycleActive = AtomicBoolean(true)
    private val runtimeLogLimiter = AndroidRuntimeLogLimiter()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentRouteMode: String = ""
    private var previousTrafficRxBytes: Long = TrafficStats.UNSUPPORTED.toLong()
    private var previousTrafficTxBytes: Long = TrafficStats.UNSUPPORTED.toLong()
    private var previousTrafficSampleAt: Long = 0L
    private val notificationUpdater = object : Runnable {
        override fun run() {
            if (!lifecycleActive.get() || !isTunEstablished()) {
                return
            }
            updateRuntimeNotification()
            mainHandler.postDelayed(this, NOTIFICATION_REFRESH_MILLIS)
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED &&
            AndroidNotificationPermissionStore.wasAsked(this)
        ) {
            AndroidRuntimeState.markSystemNotificationWarning()
        }
        when (intent?.action) {
            ACTION_STOP -> {
                val tileGeneration = intent.getLongExtra(
                    PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION,
                    NO_TILE_TRANSITION_GENERATION,
                ).takeIf { it != NO_TILE_TRANSITION_GENERATION }
                Log.i(LOG_TAG, "Received STOP for Android runtime service.")
                runtimeExecutor.execute {
                    stopRuntime(
                        message = "POKROV выключен на этом устройстве.",
                        stopReason = "user_requested",
                        tileGeneration = tileGeneration,
                    )
                    mainHandler.post { stopSelf() }
                }
            }
            ACTION_START -> {
                val configPath = intent.getStringExtra(EXTRA_CONFIG_PATH)
                val routeMode = intent.getStringExtra(EXTRA_ROUTE_MODE).orEmpty()
                currentRouteMode = routeMode
                val tileGeneration = intent.getLongExtra(
                    PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION,
                    NO_TILE_TRANSITION_GENERATION,
                ).takeIf { it != NO_TILE_TRANSITION_GENERATION }
                if (configPath.isNullOrBlank()) {
                    AndroidRuntimeState.markFailure(
                        kind = "missing_staged_config",
                        message = "На этом устройстве не хватает настроек подключения POKROV.",
                    )
                    Log.e(LOG_TAG, "Android runtime start is missing a staged config path.")
                    PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                    stopSelf()
                } else if (configPath != AndroidRuntimeState.stagedConfigPath()) {
                    AndroidRuntimeState.markFailure(
                        kind = "stale_staged_config",
                        message = AndroidRuntimeSafety.publicFailureMessage("stale_staged_config"),
                    )
                    Log.e(LOG_TAG, "Android runtime start rejected a stale staged config.")
                    PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                    stopSelf()
                } else {
                    try {
                        Log.i(LOG_TAG, "Received START for Android runtime service.")
                        markServiceStarting()
                        AndroidRuntimeState.markConnectionPending()
                        beginForegroundRuntime()
                        runtimeExecutor.execute {
                            startRuntime(configPath, tileGeneration, routeMode)
                        }
                    } catch (_: Throwable) {
                        AndroidRuntimeState.markFailure(
                            kind = "foreground_start_failed",
                            message = AndroidRuntimeSafety.publicFailureMessage(
                                "foreground_start_failed",
                            ),
                        )
                        Log.e(LOG_TAG, "Android runtime foreground start failed.")
                        PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                        stopSelf()
                    }
                }
            }
            ACTION_REFRESH_NOTIFICATION -> {
                if (isTunEstablished()) {
                    updateRuntimeNotification()
                } else {
                    stopSelf()
                }
            }
            else -> Unit
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        lifecycleActive.set(false)
        mainHandler.removeCallbacks(notificationUpdater)
        healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        if (commandServer != null || activeTun != null) {
            runtimeExecutor.execute {
                stopRuntime(
                    message = "POKROV выключен на этом устройстве.",
                    stopReason = "service_destroyed",
                )
            }
        }
        runtimeExecutor.shutdown()
        healthExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun onRevoke() {
        runtimeExecutor.execute {
            stopRuntime(
                message = "Разрешение Android было отозвано, поэтому POKROV выключен на этом устройстве.",
                stopReason = "vpn_permission_revoked",
            )
            mainHandler.post { stopSelf() }
        }
        super.onRevoke()
    }

    private fun startRuntime(configPath: String, tileGeneration: Long?, routeMode: String) {
        // A new runtime owns a new TUN/probe lifecycle before it asks Core to
        // establish one, so an older probe can no longer fail-close it.
        healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        runCatching { activeTun?.close() }
        activeTun = null
        runtimeLogLimiter.reset()
        activeSelectedAppsMode = routeMode == ROUTE_MODE_SELECTED_APPS
        val initialized = AndroidRuntimeState.initialize(this)
        if (!initialized) {
            AndroidRuntimeState.markFailure(
                kind = "runtime_initialization_failed",
                message = AndroidRuntimeSafety.publicFailureMessage("runtime_initialization_failed"),
            )
            Log.e(LOG_TAG, "Android runtime initialize() failed before service start.")
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
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
            Log.i(LOG_TAG, "Starting Android runtime using a staged config.")
            AndroidDefaultNetworkMonitor.ensureStarted(this)
            runCatching { commandServer?.closeService() }
            runCatching { commandServer?.close() }
            commandServer = null
            activeConfigContent = null
            val nextServer = Libbox.newCommandServer(this, this)
            commandServer = nextServer
            nextServer.start()
            activeConfigContent = content
            nextServer.startOrReloadService(content, OverrideOptions())
            activeTileStartGeneration = tileGeneration
            AndroidRuntimeState.markProfileStaged(
                configPath,
                preserveConnectionPending = true,
            )
            Log.i(LOG_TAG, "Android runtime service start requested successfully; waiting for tun establishment.")
        } catch (_: Throwable) {
            AndroidRuntimeState.markFailure(
                kind = "runtime_service_start_failed",
                message = AndroidRuntimeSafety.publicFailureMessage(
                    "runtime_service_start_failed",
                ),
            )
            Log.e(LOG_TAG, "Android runtime service failed to start.")
            cleanupFailedStartup()
            activeTileStartGeneration = null
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            stopSelf()
        }
    }

    private fun stopRuntime(
        message: String,
        stopReason: String,
        tileGeneration: Long? = null,
        failureKind: String? = null,
    ) {
        Log.i(LOG_TAG, "Stopping Android runtime service.")
        healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        AndroidRuntimeState.updateCoreEgressValidation(null)
        markServiceStopped()
        mainHandler.removeCallbacks(notificationUpdater)
        resetTrafficSample()
        PokrovQuickSettingsTileService.requestRefresh(this)
        try {
            commandServer?.closeService()
        } catch (_: Throwable) {
        }
        runCatching { commandServer?.close() }
        commandServer = null
        activeConfigContent = null
        AndroidDefaultNetworkMonitor.stop(null)
        try {
            activeTun?.close()
        } catch (_: Throwable) {
        }
        activeTun = null
        if (failureKind == null) {
            AndroidRuntimeState.markStopped(message = message, stopReason = stopReason)
        } else {
            AndroidRuntimeProfileStore.failClosedAfterCoreEgressFailure(
                context = applicationContext,
                failureKind = failureKind,
                message = message,
                stopReason = stopReason,
            )
        }
        activeTileStartGeneration = null
        PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(contentText: String, title: String = "POKROV на этом устройстве"): Notification {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Подключение POKROV",
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
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setSmallIcon(R.drawable.ic_pokrov_system)
            .setColor(Color.rgb(28, 145, 94))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .apply {
                if (pendingIntent != null) {
                    setContentIntent(pendingIntent)
                    addAction(
                        NotificationCompat.Action.Builder(
                            android.R.drawable.ic_menu_view,
                            "Открыть",
                            pendingIntent,
                        ).build(),
                    )
                }
            }
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Отключить",
                    stopIntent,
                ).build(),
            )
            .build()
    }

    private fun updateRuntimeNotification() {
        val profile = AndroidRuntimeProfileStore.load(this)
        val preferences = AndroidSystemSurfacePreferencesStore.load(this)
        val country = profile?.displayCountry
            ?.takeIf { preferences.showCountry }
            ?.trim()
            .orEmpty()
        val routeMode = profile?.displayRouteMode.orEmpty().ifBlank { currentRouteMode }
        val details = mutableListOf("Защита включена")
        if (preferences.showRouteMode) {
            details += notificationRouteLabel(routeMode)
        }
        if (preferences.showSpeed) {
            details += sampleTrafficSpeed()
        } else {
            resetTrafficSample()
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(
            NOTIFICATION_ID,
            buildNotification(
                contentText = details.joinToString(" · "),
                title = if (country.isEmpty()) "POKROV включен" else "POKROV · $country",
            ),
        )
    }

    private fun sampleTrafficSpeed(): String {
        val now = SystemClock.elapsedRealtime()
        val rx = TrafficStats.getUidRxBytes(Process.myUid())
        val tx = TrafficStats.getUidTxBytes(Process.myUid())
        val elapsed = now - previousTrafficSampleAt
        val hasPrevious = previousTrafficSampleAt > 0L &&
            previousTrafficRxBytes >= 0L &&
            previousTrafficTxBytes >= 0L &&
            elapsed > 0L
        val text = if (hasPrevious) {
            val down = ((rx - previousTrafficRxBytes).coerceAtLeast(0L) * 1000L) / elapsed
            val up = ((tx - previousTrafficTxBytes).coerceAtLeast(0L) * 1000L) / elapsed
            "↓ ${formatTrafficRate(down)}  ↑ ${formatTrafficRate(up)}"
        } else {
            "Скорость: измеряем…"
        }
        previousTrafficRxBytes = rx
        previousTrafficTxBytes = tx
        previousTrafficSampleAt = now
        return text
    }

    private fun resetTrafficSample() {
        previousTrafficRxBytes = TrafficStats.UNSUPPORTED.toLong()
        previousTrafficTxBytes = TrafficStats.UNSUPPORTED.toLong()
        previousTrafficSampleAt = 0L
    }

    private fun notificationRouteLabel(routeMode: String): String = when (routeMode) {
        "allExceptRu" -> "РФ напрямую"
        "selectedApps", ROUTE_MODE_SELECTED_APPS -> "Выбранные приложения"
        "excludedApps", ROUTE_MODE_EXCLUDED_APPS -> "Выбранные напрямую"
        "fullTunnel" -> "Весь трафик через VPN"
        else -> "VPN для устройства"
    }

    private fun beginForegroundRuntime() {
        val notification = buildNotification(
            contentText = "Готовим POKROV на этом устройстве...",
            title = "POKROV готовит подключение",
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
        } else if (protectedSocketEvidence.compareAndSet(false, true)) {
            Log.i(LOG_TAG, "Protected the Android runtime uplink from VPN capture.")
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
    ): ConnectionOwner {
        val owner = ConnectionOwner()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            owner.setUserId(-1)
            return owner
        }
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val uid = connectivityManager.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )
        owner.setUserId(if (uid == Process.INVALID_UID) -1 else uid)
        if (uid != Process.INVALID_UID) {
            val packageName = packageManager.getPackagesForUid(uid)?.firstOrNull().orEmpty()
            owner.setAndroidPackageName(packageName)
            owner.setUserName(packageName)
        }
        return owner
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val iterator = JavaNetworkInterface.getNetworkInterfaces()
        val interfaces = mutableListOf<space.pokrov.core.libbox.NetworkInterface>()
        while (iterator.hasMoreElements()) {
            val resolvedInterface = iterator.nextElement()
            runCatching {
                space.pokrov.core.libbox.NetworkInterface().apply {
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
        // Release the prior DNS callback before replacing the TUN. It must not
        // be able to fail-close the replacement while establish() is pending.
        val tunGeneration = healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        runCatching { activeTun?.close() }
        activeTun = null

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
            val dnsServerAddress =
                runCatching { options.getDNSServerAddress().getValue() }.getOrNull()
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

            val requestedIncludes = mutableListOf<String>()
            consumeStrings(options.getIncludePackage()) { requestedIncludes += it }
            val requestedExcludes = mutableListOf<String>()
            consumeStrings(options.getExcludePackage()) { requestedExcludes += it }
            val packagePlan = AndroidTunPackagePlanner.plan(
                appPackage = this@PokrovRuntimeVpnService.packageName,
                includedPackages = requestedIncludes,
                excludedPackages = requestedExcludes,
                selectedAppsMode = activeSelectedAppsMode,
            )
            if (!packagePlan.isValid) {
                throw IllegalStateException("Selected-apps routing requires a non-empty allow-list.")
            }
            packagePlan.allowedPackages.forEach { allowedPackage ->
                if (runCatching { builder.addAllowedApplication(allowedPackage) }.isSuccess) {
                    includePackageCount += 1
                }
            }
            if (!AndroidTunPackagePlanner.hasRequiredAppliedAllowList(
                    selectedAppsMode = activeSelectedAppsMode,
                    appliedAllowedPackageCount = includePackageCount,
                )
            ) {
                throw IllegalStateException(
                    "Selected-apps routing requires at least one available selected app.",
                )
            }
            packagePlan.disallowedPackages.forEach { disallowedPackage ->
                if (runCatching { builder.addDisallowedApplication(disallowedPackage) }.isSuccess) {
                    excludePackageCount += 1
                }
            }

            Log.i(
                LOG_TAG,
                "openTun autoRoute=${options.getAutoRoute()} " +
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

        val tun = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null.")
        activeTun = tun
        val dnsFailureToken = dnsFailureTokenGate.activate()
        AndroidLocalResolver.activateRuntime(dnsFailureToken)
        registerDnsFailureTarget(this, dnsFailureToken)
        val runtimeMessage = "POKROV подключен на этом устройстве."
        markTunEstablished(runtimeMessage)
        PokrovQuickSettingsTileService.requestRefresh(this)
        AndroidRuntimeState.markRunning(runtimeMessage)
        PokrovQuickSettingsTileService.completeRuntimeTransition(
            this,
            activeTileStartGeneration,
        )
        activeTileStartGeneration = null
        scheduleCoreEgressProbe(tunGeneration)
        Log.i(LOG_TAG, "Android tun established.")
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            NOTIFICATION_ID,
            buildNotification(contentText = "Защита включена"),
        )
        resetTrafficSample()
        mainHandler.removeCallbacks(notificationUpdater)
        notificationUpdater.run()
        return tun.fd
    }

    private fun scheduleCoreEgressProbe(generation: Long) {
        val content = activeConfigContent ?: return
        val groupTag = AndroidCoreEgressProbe.finalGroupTag(content)
        AndroidRuntimeState.updateCoreEgressValidation(null)
        if (groupTag == null) {
            handleCoreEgressProbeResult(
                probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                generation = generation,
            )
            return
        }
        runCatching {
            healthExecutor.execute {
                var result = AndroidCoreEgressProbe.probe(groupTag)
                if (
                    result == AndroidCoreEgressProbeResult.UNAVAILABLE &&
                    lifecycleActive.get() &&
                    healthGeneration.get() == generation
                ) {
                    Thread.sleep(CORE_EGRESS_RETRY_DELAY_MILLIS)
                    if (lifecycleActive.get() && healthGeneration.get() == generation) {
                        result = AndroidCoreEgressProbe.probe(groupTag)
                    }
                }
                AndroidRuntimeDispatchPolicy.dispatch(
                    executor = runtimeExecutor,
                    shouldRun = {
                        lifecycleActive.get() && healthGeneration.get() == generation
                    },
                ) {
                    handleCoreEgressProbeResult(probeResult = result, generation = generation)
                }
            }
        }.onFailure {
            AndroidRuntimeDispatchPolicy.dispatch(
                executor = runtimeExecutor,
                shouldRun = {
                    lifecycleActive.get() && healthGeneration.get() == generation
                },
            ) {
                handleCoreEgressProbeResult(
                    probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                    generation = generation,
                )
            }
        }
    }

    private fun cleanupFailedStartup() {
        healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        runCatching { commandServer?.closeService() }
        runCatching { commandServer?.close() }
        commandServer = null
        activeConfigContent = null
        AndroidDefaultNetworkMonitor.stop(null)
        runCatching { activeTun?.close() }
        activeTun = null
        markServiceStopped()
    }

    private fun releaseDnsFailureToken() {
        val token = dnsFailureTokenGate.release() ?: return
        AndroidLocalResolver.deactivateRuntime(token)
        unregisterDnsFailureTarget(this, token)
    }

    private fun handleCoreEgressProbeResult(
        probeResult: AndroidCoreEgressProbeResult,
        generation: Long,
    ) {
        if (!lifecycleActive.get()) {
            return
        }
        val activeGeneration = healthGeneration.get()
        if (!AndroidCoreEgressFailClosedPolicy.shouldStopRuntime(
                probeResult = probeResult,
                probeGeneration = generation,
                activeGeneration = activeGeneration,
                hasActiveTun = activeTun != null,
            )
        ) {
            if (generation == activeGeneration && activeTun != null) {
                AndroidRuntimeState.updateCoreEgressValidation(
                    probeResult == AndroidCoreEgressProbeResult.HEALTHY,
                )
                Log.i(
                    LOG_TAG,
                    "Android selected-outbound egress probe result=" +
                        if (probeResult == AndroidCoreEgressProbeResult.HEALTHY) {
                            "healthy"
                        } else {
                            "ignored"
                        },
                )
            }
            return
        }

        // Claim this generation before closing resources. A concurrent stop or
        // newer start invalidates the compare-and-set and leaves its runtime
        // untouched.
        if (!healthGeneration.compareAndSet(generation, generation + 1L) ||
            activeTun == null
        ) {
            return
        }

        val failureKind = if (probeResult == AndroidCoreEgressProbeResult.FAILED) {
            "core_egress_probe_failed"
        } else {
            "core_egress_probe_unavailable"
        }
        val failureMessage = AndroidRuntimeSafety.publicFailureMessage(failureKind)
        AndroidRuntimeState.updateCoreEgressValidation(false)
        Log.w(LOG_TAG, "Android selected-outbound egress probe did not pass; stopping runtime.")
        stopRuntime(
            message = failureMessage,
            stopReason = failureKind,
            failureKind = failureKind,
        )
        mainHandler.post { stopSelf() }
    }

    private fun scheduleDnsTransportFailure(token: Any, failureKind: String) {
        runCatching {
            runtimeExecutor.execute {
                if (!lifecycleActive.get() || !dnsFailureTokenGate.owns(token) || activeTun == null) {
                    return@execute
                }
                val failureMessage = AndroidRuntimeSafety.publicFailureMessage(failureKind)
                AndroidRuntimeState.markDnsTransportFailure(failureKind, failureMessage)
                Log.w(LOG_TAG, "Android DNS transport failed; stopping runtime.")
                stopRuntime(
                    message = failureMessage,
                    stopReason = failureKind,
                    failureKind = failureKind,
                )
                mainHandler.post { stopSelf() }
            }
        }
    }

    override fun readWIFIState(): WIFIState? = null

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        AndroidDefaultNetworkMonitor.start(this, listener)
    }

    override fun underNetworkExtension(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean =
        AndroidPlatformRuntimeBridge.supportFlags(Build.VERSION.SDK_INT)
            .usePlatformAutoDetectInterfaceControl

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun localDNSTransport(): LocalDNSTransport = AndroidLocalResolver

    override fun systemCertificates(): StringIterator = LibboxStringIterator(emptyList())

    override fun sendNotification(notification: LibboxNotification) {
        mainHandler.post {
            if (isTunEstablished()) {
                updateRuntimeNotification()
            }
        }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus =
        SystemProxyStatus().apply {
            setAvailable(false)
            setEnabled(false)
        }

    override fun setSystemProxyEnabled(enabled: Boolean) {
        if (enabled) {
            Log.w(LOG_TAG, "System proxy request ignored: Android runtime is TUN-only.")
        }
    }

    override fun serviceReload() {
        val content = activeConfigContent ?: return
        commandServer?.startOrReloadService(content, OverrideOptions())
    }

    override fun serviceStop() {
        runtimeExecutor.execute {
            stopRuntime(
                message = "POKROV выключен на этом устройстве.",
                stopReason = "command_server_requested",
            )
            mainHandler.post { stopSelf() }
        }
    }

    override fun writeDebugMessage(message: String) {
        val category = AndroidRuntimeLogClassifier.classify(message) ?: return
        if (AndroidRuntimeLogClassifier.affectsRuntimeHealth(category)) {
            AndroidRuntimeState.markDegraded(
                failureKind = category,
                message = AndroidRuntimeSafety.publicFailureMessage(category),
            )
        }
        val event = runtimeLogLimiter.record(category) ?: return
        val suppressed = if (event.suppressedSinceLastEmission > 0L) {
            " suppressed=${event.suppressedSinceLastEmission}"
        } else {
            ""
        }
        Log.w(LOG_TAG, "Android core runtime event category=${event.category}$suppressed")
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

        override fun len(): Int = values.size

        override fun next(): String = values[index++]
    }

    private class LibboxNetworkInterfaceIterator(
        private val values: List<space.pokrov.core.libbox.NetworkInterface>,
    ) : NetworkInterfaceIterator {
        private var index = 0

        override fun hasNext(): Boolean = index < values.size

        override fun next(): space.pokrov.core.libbox.NetworkInterface = values[index++]
    }

    companion object {
        private const val LOG_TAG = "PokrovRuntimeVpn"
        private const val NOTIFICATION_CHANNEL_ID = "pokrov-runtime"
        private const val NOTIFICATION_ID = 1407
        private const val CORE_EGRESS_RETRY_DELAY_MILLIS = 250L
        private const val NOTIFICATION_REFRESH_MILLIS = 3_000L
        private const val ROUTE_MODE_SELECTED_APPS = "selected_apps"
        private const val ROUTE_MODE_EXCLUDED_APPS = "excluded_apps"
        const val ACTION_START = "space.pokrov.runtime.START"
        const val ACTION_STOP = "space.pokrov.runtime.STOP"
        const val ACTION_REFRESH_NOTIFICATION = "space.pokrov.runtime.REFRESH_NOTIFICATION"
        const val EXTRA_CONFIG_PATH = "extra_config_path"
        const val EXTRA_ROUTE_MODE = "extra_route_mode"
        private const val NO_TILE_TRANSITION_GENERATION = Long.MIN_VALUE
        @Volatile
        private var tunEstablished: Boolean = false
        private val protectedSocketEvidence = AtomicBoolean(false)
        @Volatile
        private var currentRuntimeMessage: String? = null
        @Volatile
        private var activeTileStartGeneration: Long? = null
        @Volatile
        private var activeSelectedAppsMode: Boolean = false
        @Volatile
        private var activeDnsFailureTarget: DnsFailureTarget? = null

        private data class DnsFailureTarget(
            val service: PokrovRuntimeVpnService,
            val token: Any,
        )

        fun isTunEstablished(): Boolean = tunEstablished

        fun latestRuntimeMessage(): String? = currentRuntimeMessage

        internal fun reportDnsTransportFailure(token: Any, failureKind: String) {
            val target = activeDnsFailureTarget
            if (target?.token === token) {
                target.service.scheduleDnsTransportFailure(token, failureKind)
            }
        }

        private fun registerDnsFailureTarget(
            service: PokrovRuntimeVpnService,
            token: Any,
        ) {
            activeDnsFailureTarget = DnsFailureTarget(service, token)
        }

        private fun unregisterDnsFailureTarget(
            service: PokrovRuntimeVpnService,
            token: Any,
        ) {
            if (activeDnsFailureTarget?.let { it.service === service && it.token === token } == true) {
                activeDnsFailureTarget = null
            }
        }

        private fun markServiceStarting() {
            tunEstablished = false
            currentRuntimeMessage = "POKROV готовит подключение на этом устройстве."
        }

        private fun markTunEstablished(message: String) {
            tunEstablished = true
            currentRuntimeMessage = message
        }

        private fun markServiceStopped() {
            tunEstablished = false
            currentRuntimeMessage = null
        }

        fun start(
            context: Context,
            configPath: String,
            routeMode: String,
            tileGeneration: Long? = null,
        ) {
            protectedSocketEvidence.set(false)
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CONFIG_PATH, configPath)
                putExtra(EXTRA_ROUTE_MODE, routeMode)
                tileGeneration?.let {
                    putExtra(PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION, it)
                }
            }
            ContextCompat.startForegroundService(context, intent)
            PokrovQuickSettingsTileService.requestRefresh(context)
        }

        fun stop(context: Context, tileGeneration: Long? = null) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_STOP
                tileGeneration?.let {
                    putExtra(PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION, it)
                }
            }
            context.startService(intent)
            PokrovQuickSettingsTileService.requestRefresh(context)
        }

        fun refreshNotification(context: Context) {
            if (!isTunEstablished()) {
                return
            }
            context.startService(
                Intent(context, PokrovRuntimeVpnService::class.java).apply {
                    action = ACTION_REFRESH_NOTIFICATION
                },
            )
        }
    }
}

internal fun formatTrafficRate(bytesPerSecond: Long): String {
    val safe = bytesPerSecond.coerceAtLeast(0L)
    return when {
        safe < 1024L -> "$safe Б/с"
        safe < 1024L * 1024L -> "${safe / 1024L} КБ/с"
        else -> {
            val tenths = (safe * 10L) / (1024L * 1024L)
            "${tenths / 10L}.${tenths % 10L} МБ/с"
        }
    }
}
