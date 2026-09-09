package space.pokrov.pokrov_android_shell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.graphics.Color
import android.os.Handler
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
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
import java.net.ConnectException
import java.net.NetworkInterface as JavaNetworkInterface
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PokrovRuntimeVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    private var commandServer: CommandServer? = null
    private var activeConfigContent: String? = null
    private var activeVariantConfigContent: String? = null
    private var activeTun: ParcelFileDescriptor? = null
    private val dnsFailureTokenGate = AndroidDnsFailureTokenGate()
    private val runtimeExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val healthGeneration = AtomicLong(0L)
    private val runtimeSessionGeneration = AtomicLong(0L)
    private val serviceCommandGeneration = AtomicLong(0L)
    private val lifecycleActive = AtomicBoolean(true)
    @Volatile
    private var activeRuntimeSession: AndroidLifecycleTaskScope? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activeCoreEgressProbeRequired: Boolean = true
    private var activeCoreRunId: String? = null

    override fun onCreate() {
        super.onCreate()
        AndroidOperationalRuntime.start(this)
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.CREATED,
        )
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android starts always-on VPN without our explicit START command.
        // Reuse only the previously confirmed, digest-bound profile; the normal
        // start path below still validates its contents before creating a TUN.
        val commandIntent = if (intent?.action == null || intent.action == SERVICE_INTERFACE) {
            if (isTunEstablished() || AndroidRuntimeState.isConnectionPending()) {
                return START_NOT_STICKY
            }
            val profile = AndroidRuntimeProfileStore.restoreIntoRuntimeState(this)
                ?.takeIf { it.canStartFromQuickSettings() }
            Intent(this, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_START
                profile?.let {
                    putExtra(EXTRA_CONFIG_PATH, it.configPath)
                    putExtra(EXTRA_ROUTE_MODE, it.routeMode)
                    putExtra(EXTRA_PROFILE_DIGEST, it.configDigest)
                }
            }
        } else {
            intent
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED &&
            AndroidNotificationPermissionStore.wasAsked(this)
        ) {
            AndroidRuntimeState.markSystemNotificationWarning()
        }
        when (commandIntent.action) {
            ACTION_STOP -> {
                AndroidOperationalJournal.record(
                    AndroidOperationalEvent.VPN_SERVICE,
                    AndroidOperationalOutcome.STOP_REQUESTED,
                    activeRuntimeSession?.generation,
                )
                val commandGeneration = serviceCommandGeneration.incrementAndGet()
                val tileGeneration = commandIntent.getLongExtra(
                    PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION,
                    NO_TILE_TRANSITION_GENERATION,
                ).takeIf { it != NO_TILE_TRANSITION_GENERATION }
                runtimeExecutor.execute {
                    stopRuntime(
                        message = "POKROV выключен на этом устройстве.",
                        stopReason = "user_requested",
                        tileGeneration = tileGeneration,
                        commandGeneration = commandGeneration,
                    )
                    mainHandler.post {
                        if (serviceCommandGeneration.get() == commandGeneration) {
                            stopSelf()
                        }
                    }
                }
            }
            ACTION_START -> {
                AndroidOperationalJournal.record(
                    AndroidOperationalEvent.VPN_SERVICE,
                    AndroidOperationalOutcome.START_REQUESTED,
                )
                serviceCommandGeneration.incrementAndGet()
                try {
                    // Context.startForegroundService() requires every start path,
                    // including a fail-closed stale-profile path, to promote the
                    // service before it may stop itself.
                    beginForegroundRuntime()
                } catch (_: Throwable) {
                    AndroidOperationalJournal.record(
                        AndroidOperationalEvent.VPN_SERVICE,
                        AndroidOperationalOutcome.FAILED,
                    )
                    AndroidRuntimeState.markFailure(
                        kind = "foreground_start_failed",
                        message = AndroidRuntimeSafety.publicFailureMessage(
                            "foreground_start_failed",
                        ),
                    )
                    stopSelf()
                    return START_NOT_STICKY
                }
                val configPath = commandIntent.getStringExtra(EXTRA_CONFIG_PATH)
                val routeMode = commandIntent.getStringExtra(EXTRA_ROUTE_MODE).orEmpty()
                val expectedDigest = commandIntent.getStringExtra(EXTRA_PROFILE_DIGEST).orEmpty()
                val tileGeneration = commandIntent.getLongExtra(
                    PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION,
                    NO_TILE_TRANSITION_GENERATION,
                ).takeIf { it != NO_TILE_TRANSITION_GENERATION }
                if (configPath.isNullOrBlank()) {
                    AndroidOperationalJournal.record(
                        AndroidOperationalEvent.VPN_SERVICE,
                        AndroidOperationalOutcome.FAILED,
                    )
                    AndroidRuntimeState.markFailure(
                        kind = "missing_staged_config",
                        message = "На этом устройстве не хватает настроек подключения POKROV.",
                    )
                    PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                    stopSelf()
                } else if (configPath != AndroidRuntimeState.stagedConfigPath()) {
                    AndroidOperationalJournal.record(
                        AndroidOperationalEvent.VPN_SERVICE,
                        AndroidOperationalOutcome.FAILED,
                    )
                    AndroidRuntimeState.markFailure(
                        kind = "stale_staged_config",
                        message = AndroidRuntimeSafety.publicFailureMessage("stale_staged_config"),
                    )
                    PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                    stopSelf()
                } else {
                    try {
                        AndroidRuntimeState.markConnectionPending()
                        runtimeExecutor.execute {
                            startRuntime(configPath, tileGeneration, routeMode, expectedDigest)
                        }
                    } catch (_: Throwable) {
                        AndroidOperationalJournal.record(
                            AndroidOperationalEvent.VPN_SERVICE,
                            AndroidOperationalOutcome.FAILED,
                        )
                        AndroidRuntimeState.markFailure(
                            kind = "foreground_start_failed",
                            message = AndroidRuntimeSafety.publicFailureMessage(
                                "foreground_start_failed",
                            ),
                        )
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
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.DESTROYED,
            activeRuntimeSession?.generation,
        )
        lifecycleActive.set(false)
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
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
        super.onDestroy()
    }

    override fun onRevoke() {
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.REVOKED,
            activeRuntimeSession?.generation,
        )
        runtimeExecutor.execute {
            stopRuntime(
                message = "Разрешение Android было отозвано, поэтому POKROV выключен на этом устройстве.",
                stopReason = "vpn_permission_revoked",
            )
            mainHandler.post { stopSelf() }
        }
        super.onRevoke()
    }

    private fun replaceRuntimeSession(): AndroidLifecycleTaskScope {
        cancelRuntimeSession()
        healthGeneration.incrementAndGet()
        val scope = AndroidLifecycleTaskScope(
            generation = runtimeSessionGeneration.incrementAndGet(),
            threadNamePrefix = "pokrov-vpn-session",
            parallelism = 2,
        )
        activeRuntimeSession = scope
        AndroidRuntimeState.beginTunnelTrafficSession(scope.generation)
        return scope
    }

    private fun cancelRuntimeSession() {
        val scope = activeRuntimeSession
        activeRuntimeSession = null
        scope?.close()
        if (scope != null) {
            AndroidRuntimeState.endTunnelTrafficSession(scope.generation)
        }
    }

    private fun ownsRuntimeSession(scope: AndroidLifecycleTaskScope): Boolean =
        lifecycleActive.get() && activeRuntimeSession === scope && scope.isActive()

    private fun startTunnelTrafficMonitor(scope: AndroidLifecycleTaskScope) {
        val monitor = AndroidTunnelTrafficClient(
            scope = scope,
            onSnapshot = { snapshot ->
                if (ownsRuntimeSession(scope)) {
                    AndroidRuntimeState.updateTunnelTraffic(scope.generation, snapshot)
                }
            },
        )
        if (!monitor.start()) {
            AndroidRuntimeState.updateTunnelTraffic(
                scope.generation,
                AndroidTunnelTrafficSnapshot.unavailable,
            )
        }
    }

    private fun startRuntime(
        configPath: String, tileGeneration: Long?, routeMode: String, expectedDigest: String,
    ) {
        val persistedProfile = AndroidRuntimeProfileStore.load(this)
        val stagedContent = runCatching { File(configPath).readText() }.getOrNull()
        if (stagedContent == null || !runtimeProfileMatchesIntent(
                persistedProfile, expectedDigest, configPath, routeMode, stagedContent,
            )) {
            AndroidRuntimeState.markFailure(
                kind = "profile_identity_mismatch",
                message = AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch"),
            )
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            if (activeTun == null) stopSelf()
            return
        }
        // Pin the verified immutable bytes before replacing any live session.
        val rawContent = stagedContent.removePrefix("\uFEFF")
        markServiceStarting()
        val session = replaceRuntimeSession()
        AndroidRuntimeState.bindActiveProfile(expectedDigest)
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.SESSION_STARTED,
            session.generation,
        )
        // A new runtime owns a new TUN/probe lifecycle before it asks Core to
        // establish one, so an older probe can no longer fail-close it.
        healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        runCatching { activeTun?.close() }
        activeTun = null
        activeCoreEgressProbeRequired = coreEgressProbeRequiredForRuntime(
            persistedProfile,
            configPath,
        )
        AndroidRuntimeState.updateCoreEgressRequirement(activeCoreEgressProbeRequired)
        activeSelectedAppsMode = routeMode == ROUTE_MODE_SELECTED_APPS
        val initialized = AndroidRuntimeState.initialize(this)
        if (!initialized) {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.VPN_SERVICE,
                AndroidOperationalOutcome.FAILED,
                session.generation,
            )
            AndroidRuntimeState.markFailure(
                kind = "runtime_initialization_failed",
                message = AndroidRuntimeSafety.publicFailureMessage("runtime_initialization_failed"),
            )
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            stopSelf()
            return
        }

        try {
            if (rawContent.isBlank()) {
                throw IllegalStateException("Staged runtime config is missing or empty.")
            }
            val runtimeConfig = JSONObject(rawContent).apply { remove("_meta") }
            // This app package is excluded from its own VpnService TUN below.
            // Keep Core interface auto-detection off: AWG requests platform
            // socket protection directly, while ordinary transports must not
            // select the VPN interface and loop back into the TUN.
            val route = runtimeConfig.optJSONObject("route") ?: JSONObject().also {
                runtimeConfig.put("route", it)
            }
            route.put("auto_detect_interface", false)
            val inbounds = runtimeConfig.optJSONArray("inbounds") ?: JSONArray().also {
                runtimeConfig.put("inbounds", it)
            }
            val platformMtuCeiling = activePlatformInterfaceMtu()
            val tunInboundIndexes = (0 until inbounds.length()).filter { index ->
                inbounds.optJSONObject(index)?.optString("type") == "tun"
            }
            tunInboundIndexes.forEach { index ->
                val tunInbound = inbounds.getJSONObject(index)
                tunInbound.put(
                    "mtu",
                    AndroidTunMtuPolicy.select(
                        requested = tunInbound.opt("mtu"),
                        platformInterfaceMtu = platformMtuCeiling,
                    ),
                )
            }
            val hasTunInbound = tunInboundIndexes.isNotEmpty()
            if (!hasTunInbound) {
                if (routeMode != ROUTE_MODE_DEVICE) {
                    throw IllegalStateException(
                        "A scoped app route requires a freshly materialized TUN profile.",
                    )
                }
                inbounds.put(
                    JSONObject()
                        .put("type", "tun")
                        .put("tag", "tun-in")
                        .put(
                            "mtu",
                            AndroidTunMtuPolicy.select(
                                requested = null,
                                platformInterfaceMtu = platformMtuCeiling,
                            ),
                        )
                        .put("auto_route", true)
                        .put("strict_route", true)
                        .put("endpoint_independent_nat", true)
                        .put("stack", "mixed")
                        .put("sniff", true)
                        .put("inet4_address", "172.19.0.1/28")
                        .put("inet6_address", "fdfe:dcba:9876::1/126")
                        .put("domain_strategy", "prefer_ipv4")
                        .put("exclude_package", JSONArray().put(packageName)),
                )
            }
            val endpoints = runtimeConfig.optJSONArray("endpoints")
            val hasWarpEndpoint = endpoints != null && (0 until endpoints.length()).any { index ->
                endpoints.optJSONObject(index)?.optString("type") == "warp"
            }
            runtimeConfig.optJSONObject("experimental")
                ?.optJSONObject("cache_file")
                ?.let { cacheFile ->
                    if (hasWarpEndpoint) {
                        cacheFile.put("path", "pokrov-cache.db")
                    } else {
                        runtimeConfig.optJSONObject("experimental")?.remove("cache_file")
                    }
                }
            val outbounds = runtimeConfig.optJSONArray("outbounds")
            fun outboundByTag(tag: String): JSONObject? {
                if (tag.isBlank() || outbounds == null) {
                    return null
                }
                for (index in 0 until outbounds.length()) {
                    val outbound = outbounds.optJSONObject(index) ?: continue
                    if (outbound.optString("tag") == tag) {
                        return outbound
                    }
                }
                return null
            }
            fun endpointByTag(tag: String): JSONObject? {
                if (tag.isBlank() || endpoints == null) {
                    return null
                }
                for (index in 0 until endpoints.length()) {
                    val endpoint = endpoints.optJSONObject(index) ?: continue
                    if (endpoint.optString("tag") == tag) {
                        return endpoint
                    }
                }
                return null
            }
            fun selectedConcreteOutbound(initialTag: String): JSONObject? {
                var tag = initialTag
                repeat(6) {
                    val outbound = outboundByTag(tag) ?: return null
                    val type = outbound.optString("type")
                    if (type != "selector" && type != "urltest") {
                        return outbound
                    }
                    tag = outbound.optString("default").ifBlank {
                        outbound.optJSONArray("outbounds")?.optString(0).orEmpty()
                    }
                    if (tag.isBlank()) {
                        return null
                    }
                }
                return null
            }
            val finalTag = runtimeConfig.optJSONObject("route")?.optString("final").orEmpty()
            val selectedOutbound = selectedConcreteOutbound(finalTag)
            val endpointHops = mutableListOf<Pair<String, JSONObject>>()
            selectedOutbound?.let { endpointHops += "selected" to it }
            var detourTag = selectedOutbound?.optString("detour").orEmpty()
            repeat(4) { index ->
                if (detourTag.isBlank()) {
                    return@repeat
                }
                val detourOutbound = outboundByTag(detourTag) ?: return@repeat
                endpointHops += "detour${index + 1}" to detourOutbound
                detourTag = detourOutbound.optString("detour")
            }
            var rootEndpointPreflightCategory: String? = null
            endpointHops.forEachIndexed { index, (_, endpoint) ->
                val endpointServer = endpoint.optString("server").trim()
                val endpointPort = endpoint.optInt("server_port")
                if (endpointServer.isBlank() || endpointPort !in 1..65535) {
                    if (index == endpointHops.lastIndex) {
                        rootEndpointPreflightCategory = "endpoint_invalid"
                    }
                    return@forEachIndexed
                }
                val preflight = preflightSelectedEndpoint(endpointServer, endpointPort)
                if (index == endpointHops.lastIndex) {
                    rootEndpointPreflightCategory = preflight.category
                }
            }
            if (!offlineEmergencyRootPreflightAccepted(
                    coreEgressProbeRequired = activeCoreEgressProbeRequired,
                    rootCategory = rootEndpointPreflightCategory,
                )
            ) {
                val failureKind = "emergency_endpoint_unreachable"
                val failureMessage = AndroidRuntimeSafety.publicFailureMessage(failureKind)
                AndroidRuntimeState.markFailure(
                    kind = failureKind,
                    message = failureMessage,
                )
                cleanupFailedStartup()
                activeTileStartGeneration = null
                PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
                stopSelf()
                return
            }
            val content = runtimeConfig.toString()
            AndroidDefaultNetworkMonitor.ensureStarted(this)
            runCatching { commandServer?.closeService() }
            runCatching { commandServer?.close() }
            commandServer = null
            activeConfigContent = null
            activeVariantConfigContent = null
            val nextServer = Libbox.newCommandServer(this, this)
            commandServer = nextServer
            activeCoreRunId = AndroidCoreOperationalEvents.beginRun(
                nextServer,
                session.generation,
            )
            nextServer.start()
            activeConfigContent = content
            activeVariantConfigContent = rawContent
            nextServer.startOrReloadService(content, OverrideOptions())
            startTunnelTrafficMonitor(session)
            activeTileStartGeneration = tileGeneration
            // Staging belongs to the bridge/store. A delayed Core start must
            // not overwrite a newer staged identity with its older profile.
        } catch (error: Throwable) {
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.VPN_SERVICE,
                AndroidOperationalOutcome.FAILED,
                session.generation,
            )
            AndroidRuntimeState.markFailure(
                kind = "runtime_service_start_failed",
                message = AndroidRuntimeSafety.publicFailureMessage(
                    "runtime_service_start_failed",
                ),
            )
            cleanupFailedStartup()
            activeTileStartGeneration = null
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            stopSelf()
        }
    }

    private fun preflightSelectedEndpoint(server: String, port: Int): EndpointPreflightResult {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork
            ?: return EndpointPreflightResult("network_unavailable")
        val capabilities = connectivityManager.getNetworkCapabilities(network)
            ?: return EndpointPreflightResult("capabilities_unavailable")
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) {
            return EndpointPreflightResult("active_network_is_vpn")
        }
        return try {
            val address = network.getAllByName(server).firstOrNull()
                ?: return EndpointPreflightResult("dns_unresolved")
            Socket().use { socket ->
                network.bindSocket(socket)
                socket.connect(
                    InetSocketAddress(address, port),
                    ENDPOINT_PREFLIGHT_TIMEOUT_MILLIS,
                )
            }
            EndpointPreflightResult("reachable")
        } catch (_: UnknownHostException) {
            EndpointPreflightResult("dns_unresolved")
        } catch (_: SocketTimeoutException) {
            EndpointPreflightResult("timeout")
        } catch (_: ConnectException) {
            EndpointPreflightResult("connect_error")
        } catch (_: SecurityException) {
            EndpointPreflightResult("security_error")
        } catch (_: IOException) {
            EndpointPreflightResult("io_error")
        } catch (_: Throwable) {
            EndpointPreflightResult("runtime_error")
        }
    }

    private fun stopRuntime(
        message: String,
        stopReason: String,
        tileGeneration: Long? = null,
        failureKind: String? = null,
        commandGeneration: Long? = null,
    ) {
        val stoppedGeneration = activeRuntimeSession?.generation
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
        releaseDnsFailureToken()
        AndroidRuntimeState.updateCoreEgressValidation(null)
        markServiceStopped()
        try {
            commandServer?.closeService()
        } catch (_: Throwable) {
        }
        runCatching { commandServer?.close() }
        commandServer = null
        activeCoreRunId = null
        activeConfigContent = null
        activeVariantConfigContent = null
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
        if (ownsLatestRuntimeServiceCommand(commandGeneration, serviceCommandGeneration.get())) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.STOPPED,
            stoppedGeneration,
        )
    }

    private fun buildNotification(content: AndroidRuntimeNotificationContent): Notification {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Подключение POKROV",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
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

        val publicVersion = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(content.title)
            .setContentText(content.text)
            .setSmallIcon(R.drawable.ic_pokrov_system)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .build()

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(content.title)
            .setContentText(content.text)
            .setSmallIcon(R.drawable.ic_pokrov_system)
            .setColor(Color.rgb(28, 145, 94))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .apply {
                setStyle(NotificationCompat.BigTextStyle().bigText(content.text))
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
        val runtimeSnapshot = AndroidRuntimeState.snapshot()
        val content = androidRuntimeNotificationContent(
            androidRuntimeNotificationStateForEgress(
                validationRequired = activeCoreEgressProbeRequired,
                validated = runtimeSnapshot["core_egress_validated"] as? Boolean,
            ),
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(
            NOTIFICATION_ID,
            buildNotification(
                content,
            ),
        )
    }

    private fun beginForegroundRuntime() {
        val notification = buildNotification(
            androidRuntimeNotificationContent(
                AndroidRuntimeNotificationState.CONNECTING,
            ),
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
        val protected = protect(fd)
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.UPLINK_SOCKET,
            if (protected) {
                AndroidOperationalOutcome.GRANTED
            } else {
                AndroidOperationalOutcome.DENIED
            },
            activeRuntimeSession?.generation,
        )
        if (!protected) {
            error("android: failed to protect uplink socket")
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

    private fun activePlatformInterfaceMtu(): Int? = runCatching {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return@runCatching null
        val interfaceName = connectivityManager.getLinkProperties(network)
            ?.interfaceName
            ?.takeIf(String::isNotBlank)
            ?: return@runCatching null
        JavaNetworkInterface.getByName(interfaceName)?.mtu
    }.getOrNull()

    override fun includeAllNetworks(): Boolean = false

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) {
            error("android: missing vpn permission")
        }
        val session = activeRuntimeSession
            ?.takeIf(::ownsRuntimeSession)
            ?: error("android: inactive runtime session")
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

        val mtu = AndroidTunMtuPolicy.select(
            requested = options.getMTU(),
            platformInterfaceMtu = activePlatformInterfaceMtu(),
        )
        builder.setMtu(mtu)

        var hasIpv4Address = false
        var hasIpv6Address = false
        var hasIpv4Route = false
        var hasIpv6Route = false
        var hasIpv4DefaultRoute = false
        var hasIpv6DefaultRoute = false
        var ipv4RouteCount = 0
        var ipv6RouteCount = 0
        var includePackageCount = 0
        var excludePackageCount = 0

        consumePrefixes(options.getInet4Address()) { prefix ->
            builder.addAddress(prefix.address(), prefix.prefix())
            hasIpv4Address = true
        }
        consumePrefixes(options.getInet6Address()) { prefix ->
            builder.addAddress(prefix.address(), prefix.prefix())
            hasIpv6Address = true
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
                }
                consumePrefixes(options.getInet6RouteExcludeAddress()) { prefix ->
                    builder.excludeRoute(IpPrefixCompat(prefix))
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
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.TUN_ESTABLISHED,
            session.generation,
        )
        val dnsFailureToken = dnsFailureTokenGate.activate()
        AndroidLocalResolver.activateRuntime(dnsFailureToken)
        registerDnsFailureTarget(this, dnsFailureToken)
        val runtimeMessage = "POKROV подключен на этом устройстве."
        markTunEstablished(runtimeMessage)
        AndroidRuntimeState.markRunning(runtimeMessage)
        PokrovQuickSettingsTileService.completeRuntimeTransition(
            this,
            activeTileStartGeneration,
        )
        activeTileStartGeneration = null
        scheduleCoreEgressProbe(session, tunGeneration)
        return tun.fd
    }

    private fun scheduleCoreEgressProbe(
        session: AndroidLifecycleTaskScope,
        generation: Long,
    ) {
        val content = activeConfigContent ?: return
        val variantConfigContent = activeVariantConfigContent
        AndroidRuntimeState.updateCoreEgressValidation(null)
        updateRuntimeNotification()
        if (!activeCoreEgressProbeRequired) {
            return
        }
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.CORE_EGRESS_PROBE,
            AndroidOperationalOutcome.REQUIRED,
            generation,
        )
        val target = AndroidCoreEgressProbe.finalTarget(content)
        if (target == null) {
            handleCoreEgressProbeResult(
                probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                generation = generation,
            )
            return
        }
        val probeServer = commandServer
        val watchdog = Runnable {
            AndroidRuntimeDispatchPolicy.dispatch(
                executor = runtimeExecutor,
                shouldRun = {
                    ownsRuntimeSession(session) &&
                        healthGeneration.get() == generation &&
                        activeTun != null
                },
            ) {
                handleCoreEgressProbeResult(
                    probeResult = AndroidCoreEgressProbeResult.TIMED_OUT,
                    generation = generation,
                    keepRuntimeOnFailure = target.keepRuntimeOnFailure,
                )
            }
        }
        mainHandler.postDelayed(watchdog, CORE_EGRESS_HARD_TIMEOUT_MILLIS)
        session.onCancel { mainHandler.removeCallbacks(watchdog) }
        if (!session.execute {
            try {
                var result = AndroidCoreEgressProbe.probe(target, probeServer)
                var completedAttempts = 1
                while (
                    AndroidCoreEgressRetryPolicy.shouldRetry(
                        target,
                        result,
                        completedAttempts,
                    ) &&
                    ownsRuntimeSession(session) &&
                    healthGeneration.get() == generation
                ) {
                    Thread.sleep(
                        if (target.kind == AndroidCoreEgressProbeTargetKind.ENDPOINT) {
                            CORE_ENDPOINT_EGRESS_RETRY_DELAY_MILLIS
                        } else {
                            CORE_EGRESS_RETRY_DELAY_MILLIS
                        },
                    )
                    if (ownsRuntimeSession(session) && healthGeneration.get() == generation) {
                        result = AndroidCoreEgressProbe.probe(target, probeServer)
                        completedAttempts += 1
                    }
                }
                if (
                    result == AndroidCoreEgressProbeResult.FAILED &&
                    ownsRuntimeSession(session) &&
                    healthGeneration.get() == generation
                ) {
                    AndroidVariantAvailabilityProbe
                        .captureBeforeFailClosed(variantConfigContent.orEmpty())
                }
                mainHandler.removeCallbacks(watchdog)
                AndroidRuntimeDispatchPolicy.dispatch(
                    executor = runtimeExecutor,
                    shouldRun = {
                        ownsRuntimeSession(session) && healthGeneration.get() == generation
                    },
                ) {
                    handleCoreEgressProbeResult(
                        probeResult = result,
                        generation = generation,
                        keepRuntimeOnFailure = target.keepRuntimeOnFailure,
                    )
                }
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            } catch (_: Throwable) {
                AndroidRuntimeDispatchPolicy.dispatch(
                    executor = runtimeExecutor,
                    shouldRun = {
                        ownsRuntimeSession(session) &&
                            healthGeneration.get() == generation
                    },
                ) {
                    handleCoreEgressProbeResult(
                        probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                        generation = generation,
                        keepRuntimeOnFailure = target.keepRuntimeOnFailure,
                    )
                }
            } finally {
                mainHandler.removeCallbacks(watchdog)
            }
        }) {
            mainHandler.removeCallbacks(watchdog)
            AndroidRuntimeDispatchPolicy.dispatch(
                executor = runtimeExecutor,
                shouldRun = {
                    ownsRuntimeSession(session) && healthGeneration.get() == generation
                },
            ) {
                handleCoreEgressProbeResult(
                    probeResult = AndroidCoreEgressProbeResult.UNAVAILABLE,
                    generation = generation,
                    keepRuntimeOnFailure = target.keepRuntimeOnFailure,
                )
            }
        }
    }

    private fun cleanupFailedStartup() {
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
        releaseDnsFailureToken()
        runCatching { commandServer?.closeService() }
        runCatching { commandServer?.close() }
        commandServer = null
        activeCoreRunId = null
        activeConfigContent = null
        activeVariantConfigContent = null
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
        keepRuntimeOnFailure: Boolean = false,
    ) {
        if (!lifecycleActive.get()) {
            return
        }
        val activeGeneration = healthGeneration.get()
        if (generation != activeGeneration || activeTun == null) {
            return
        }
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.CORE_EGRESS_PROBE,
            when (probeResult) {
                AndroidCoreEgressProbeResult.HEALTHY -> AndroidOperationalOutcome.VERIFIED
                AndroidCoreEgressProbeResult.FAILED -> AndroidOperationalOutcome.FAILED
                AndroidCoreEgressProbeResult.UNAVAILABLE,
                AndroidCoreEgressProbeResult.TIMED_OUT,
                -> AndroidOperationalOutcome.STALLED
            },
            generation,
        )
        if (keepRuntimeOnFailure && probeResult != AndroidCoreEgressProbeResult.HEALTHY) {
            val failureKind = if (probeResult == AndroidCoreEgressProbeResult.FAILED) {
                "core_egress_probe_failed"
            } else {
                "core_egress_probe_unavailable"
            }
            AndroidRuntimeState.updateCoreEgressValidation(false)
            AndroidRuntimeState.markDegraded(
                failureKind = failureKind,
                message = AndroidRuntimeSafety.publicFailureMessage(failureKind),
            )
            updateRuntimeNotification()
            return
        }
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
                updateRuntimeNotification()
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
                // A Wi-Fi/cellular handover can invalidate one in-flight Android
                // resolver request before the replacement default network is
                // published. Keep the TUN up (which remains fail-closed), discard
                // stale Core transports, and let the next lookup use the new
                // uplink. Stopping VpnService here would expose all applications
                // to the ordinary network precisely during the handover.
                runCatching { commandServer?.resetNetwork() }
            }
        }
    }

    private fun reloadActiveRuntimeAfterDefaultNetworkChange() {
        val session = activeRuntimeSession ?: return
        runCatching {
            runtimeExecutor.execute {
                if (!ownsRuntimeSession(session) || activeTun == null) {
                    return@execute
                }
                val server = commandServer ?: return@execute
                val content = activeConfigContent ?: return@execute
                val previousTun = activeTun
                healthGeneration.incrementAndGet()
                runCatching {
                    val runId = activeCoreRunId ?: return@runCatching
                    AndroidCoreOperationalEvents.beginAttempt(
                        server,
                        runId,
                        session.generation,
                    )
                    server.startOrReloadService(content, OverrideOptions())
                }.onSuccess {
                    if (activeTun !== previousTun) {
                        runCatching { previousTun?.close() }
                    }
                }.onFailure {
                    AndroidRuntimeState.markDegraded(
                        failureKind = "default_network_unavailable",
                        message = AndroidRuntimeSafety.publicFailureMessage(
                            "default_network_unavailable",
                        ),
                    )
                }
            }
        }
    }

    override fun readWIFIState(): WIFIState? = null

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        AndroidDefaultNetworkMonitor.start(this, listener) {
            reloadActiveRuntimeAfterDefaultNetworkChange()
        }
    }

    override fun underNetworkExtension(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        val enabled = AndroidPlatformRuntimeBridge.supportFlags(Build.VERSION.SDK_INT)
            .usePlatformAutoDetectInterfaceControl
        return enabled
    }

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

    override fun setSystemProxyEnabled(enabled: Boolean) = Unit

    override fun serviceReload() {
        val session = activeRuntimeSession ?: return
        runtimeExecutor.execute {
            if (!ownsRuntimeSession(session)) {
                return@execute
            }
            val content = activeConfigContent ?: return@execute
            commandServer?.startOrReloadService(content, OverrideOptions())
        }
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
        // Release operation discards arbitrary upstream lines. The sole
        // exception is Core's bounded, closed AWG diagnostic contract, which
        // is parsed again here before entering the safe runtime snapshot.
        val diagnostic = AndroidRuntimeLogClassifier.parseAwgSafeDiagnostic(message) ?: return
        AndroidRuntimeState.recordAwgSafeDiagnostic(diagnostic)
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
        private const val NOTIFICATION_CHANNEL_ID = "pokrov-runtime-private-v2"
        private const val NOTIFICATION_ID = 1407
        private const val CORE_EGRESS_RETRY_DELAY_MILLIS = 250L
        private const val CORE_ENDPOINT_EGRESS_RETRY_DELAY_MILLIS = 750L
        private const val CORE_EGRESS_HARD_TIMEOUT_MILLIS = 55_000L
        private const val ENDPOINT_PREFLIGHT_TIMEOUT_MILLIS = 5_000
        private const val ROUTE_MODE_DEVICE = "device"
        private const val ROUTE_MODE_SELECTED_APPS = "selected_apps"
        private const val ROUTE_MODE_EXCLUDED_APPS = "excluded_apps"
        const val ACTION_START = "space.pokrov.runtime.START"
        const val ACTION_STOP = "space.pokrov.runtime.STOP"
        const val ACTION_REFRESH_NOTIFICATION = "space.pokrov.runtime.REFRESH_NOTIFICATION"
        const val EXTRA_CONFIG_PATH = "extra_config_path"
        const val EXTRA_ROUTE_MODE = "extra_route_mode"
        const val EXTRA_PROFILE_DIGEST = "extra_profile_digest"
        private const val NO_TILE_TRANSITION_GENERATION = Long.MIN_VALUE
        @Volatile
        private var tunEstablished: Boolean = false
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
            profileDigest: String,
            tileGeneration: Long? = null,
        ) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CONFIG_PATH, configPath)
                putExtra(EXTRA_ROUTE_MODE, routeMode)
                putExtra(EXTRA_PROFILE_DIGEST, profileDigest)
                tileGeneration?.let {
                    putExtra(PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION, it)
                }
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context, tileGeneration: Long? = null) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_STOP
                tileGeneration?.let {
                    putExtra(PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION, it)
                }
            }
            context.startService(intent)
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

    private data class EndpointPreflightResult(val category: String)
}

internal fun offlineEmergencyRootPreflightAccepted(
    coreEgressProbeRequired: Boolean,
    rootCategory: String?,
): Boolean = coreEgressProbeRequired || rootCategory == "reachable"
