package space.pokrov.pokrov_android_shell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
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
import java.net.NetworkInterface as JavaNetworkInterface
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.io.File
import java.time.Duration
import java.time.Instant
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PokrovRuntimeVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    private var commandServer: CommandServer? = null
    private var activeConfigContent: String? = null
    private var activeVariantConfigContent: String? = null
    @Volatile private var activeCatalogAppBinding: AndroidCatalogAppBinding? = null
    @Volatile private var activeCatalogAppRequired = false
    private var activeTun: ParcelFileDescriptor? = null
    private val dnsFailureTokenGate = AndroidDnsFailureTokenGate()
    private val runtimeExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val healthGeneration = AtomicLong(0L)
    @Volatile private var pendingCoreEgressProbeGeneration: Long? = null
    private val runtimeSessionGeneration = AtomicLong(0L)
    private val serviceCommandGeneration = AtomicLong(0L)
    private val serviceCommandLock = Any()
    @Volatile private var activeServiceCommandGeneration = 0L
    @Volatile private var activeStartupProfileDigest: String? = null
    @Volatile private var activeStartupCommitted = false
    @Volatile private var activeCoreStartCompleted = false
    @Volatile private var activeConnectRequestId: String? = null
    @Volatile private var activeConnectDeadline: AndroidConnectDeadline? = null
    @Volatile private var activePromotedUntilElapsed: Long? = null
    @Volatile private var activePromotedLeaseRef: String? = null
    private var acceptedConnectRequestId: String? = null
    private val endingBoundSessions = mutableSetOf<AndroidLifecycleTaskScope>()
    private var boundCoreServiceClosed = false
    private var boundCleanupConfirmed = false
    private val lifecycleActive = AtomicBoolean(true)
    @Volatile
    private var activeRuntimeSession: AndroidLifecycleTaskScope? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activeCoreEgressProbeRequired: Boolean = true
    private var activeCoreRunId: String? = null
    private var catalogAppExpiry: Runnable? = null
    private val catalogPackageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val name = intent?.data?.schemeSpecificPart ?: return
            activeCatalogAppBinding?.takeIf { it.affectsPackage(name) }?.let {
                invalidateCatalogAppBinding(it, "catalog_app_identity_changed")
            }
        }
    }
    private val catalogTimeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != Intent.ACTION_TIME_CHANGED) return
            activeCatalogAppBinding?.takeIf { !it.isValid() }?.let {
                invalidateCatalogAppBinding(it, "catalog_app_scope_expired")
            }
        }
    }

    private fun armCatalogAppExpiry(binding: AndroidCatalogAppBinding?) {
        synchronized(serviceCommandLock) {
            catalogAppExpiry?.let { mainHandler.removeCallbacks(it) }
            catalogAppExpiry = null
            if (binding == null || !lifecycleActive.get()) return
            val expiry = Runnable { invalidateCatalogAppBinding(binding, "catalog_app_scope_expired") }
            catalogAppExpiry = expiry
            mainHandler.postDelayed(expiry, binding.remainingMillis())
        }
    }

    private fun invalidateCatalogAppBinding(binding: AndroidCatalogAppBinding, stopReason: String) {
        val (commandGeneration, scope) = synchronized(serviceCommandLock) {
            if (!activeCatalogAppRequired || activeCatalogAppBinding !== binding ||
                !binding.invalidate()) return
            healthGeneration.incrementAndGet()
            val tun = activeTun
            if (tun != null) runCatching { tun.close() }.onSuccess {
                if (activeTun === tun) activeTun = null
            }
            AndroidRuntimeState.markFailure("profile_identity_mismatch",
                AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch"))
            serviceCommandGeneration.get() to activeRuntimeSession
        }
        runCatching { scope?.close() }
        runCatching { updateRuntimeNotification(AndroidRuntimeNotificationState.FAILED) }
        runCatching {
            runtimeExecutor.execute {
                if (ownsServiceCommand(commandGeneration) && activeCatalogAppBinding === binding) {
                    stopRuntime(
                        message = AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch"),
                        stopReason = stopReason,
                        failureKind = "profile_identity_mismatch",
                        commandGeneration = commandGeneration,
                    )
                    mainHandler.post {
                        if (ownsServiceCommand(commandGeneration)) stopSelf()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val packageFilter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }
        ContextCompat.registerReceiver(this, catalogPackageReceiver, packageFilter,
            ContextCompat.RECEIVER_NOT_EXPORTED)
        ContextCompat.registerReceiver(this, catalogTimeReceiver,
            IntentFilter(Intent.ACTION_TIME_CHANGED), ContextCompat.RECEIVER_NOT_EXPORTED)
        runtimeOwner = this
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
                val cancelledRequest = commandIntent.getStringExtra(EXTRA_CANCEL_CONNECT_REQUEST)
                if (cancelledRequest != null && (cancelledRequest != acceptedConnectRequestId ||
                    !AndroidConnectRequestOwner.ownsCancellation(cancelledRequest))) {
                    // Cancellation may arrive before its START intent, or after
                    // a replacement. The process owner rejects the former when
                    // START arrives; neither case may stop a different attempt.
                    if (serviceCommandGeneration.get() == 0L) stopSelfResult(startId)
                    return START_NOT_STICKY
                }
                if (cancelledRequest == null) AndroidConnectRequestOwner.invalidate()
                AndroidOperationalJournal.record(
                    AndroidOperationalEvent.VPN_SERVICE,
                    AndroidOperationalOutcome.STOP_REQUESTED,
                    activeRuntimeSession?.generation,
                )
                val commandGeneration = advanceServiceCommand()
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
                val connectRequestId = commandIntent.getStringExtra(EXTRA_CONNECT_REQUEST)
                val expectedCoreModuleSha256 = commandIntent.getStringExtra(EXTRA_CORE_MODULE_SHA256)
                val expectedDigest = commandIntent.getStringExtra(EXTRA_PROFILE_DIGEST).orEmpty()
                // A bound attempt cannot replace another service command or
                // lend its cleanup authority to an ordinary/Quick Settings start.
                if (AndroidConnectRequestOwner.blocksStart(connectRequestId) ||
                    (expectedCoreModuleSha256 != null && serviceCommandGeneration.get() != 0L)) {
                    runCatching { beginForegroundRuntime() }
                    if (serviceCommandGeneration.get() == 0L) stopSelfResult(startId)
                    return START_NOT_STICKY
                }
                val deadline = if (expectedCoreModuleSha256 == null) null else AndroidConnectDeadline(
                    commandIntent.getStringExtra(EXTRA_CONNECT_BOOT_REF).orEmpty(),
                    commandIntent.getLongExtra(EXTRA_CONNECT_STARTED_MS, -1L),
                    commandIntent.getLongExtra(EXTRA_CONNECT_DEADLINE_MS, -1L))
                if ((expectedCoreModuleSha256 != null && connectRequestId == null) ||
                    (connectRequestId != null && !AndroidConnectRequestOwner.ownsStart(
                        connectRequestId, expectedCoreModuleSha256, expectedDigest, deadline))) {
                    // Satisfy the foreground-service start contract even when
                    // an already-cancelled request was delivered late.
                    runCatching { beginForegroundRuntime() }
                    if (connectRequestId != null && AndroidConnectRequestOwner.expire(connectRequestId)) {
                        AndroidRuntimeState.markFailure("connect_deadline",
                            AndroidRuntimeSafety.publicFailureMessage("connect_deadline"))
                    }
                    if (serviceCommandGeneration.get() == 0L) stopSelfResult(startId)
                    return START_NOT_STICKY
                }
                if (connectRequestId != null && !AndroidConnectRequestOwner.admitService(connectRequestId, this)) {
                    runCatching { beginForegroundRuntime() }
                    if (serviceCommandGeneration.get() == 0L) stopSelfResult(startId)
                    return START_NOT_STICKY
                }
                acceptedConnectRequestId = connectRequestId
                AndroidOperationalJournal.record(
                    AndroidOperationalEvent.VPN_SERVICE,
                    AndroidOperationalOutcome.START_REQUESTED,
                )
                val commandGeneration = advanceServiceCommand()
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
                            startRuntime(configPath, tileGeneration, routeMode, expectedDigest,
                                commandGeneration, connectRequestId, expectedCoreModuleSha256, deadline)
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
        synchronized(serviceCommandLock) { lifecycleActive.set(false) }
        armCatalogAppExpiry(null)
        unregisterReceiver(catalogPackageReceiver)
        unregisterReceiver(catalogTimeReceiver)
        if (runtimeOwner === this) runtimeOwner = null
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.DESTROYED,
            activeRuntimeSession?.generation,
        )
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
        releaseDnsFailureToken()
        val boundRequest = acceptedConnectRequestId?.takeIf { AndroidConnectRequestOwner.serviceFor(it) === this }
        if (commandServer != null || activeTun != null || boundRequest != null) {
            runtimeExecutor.execute {
                stopRuntime(
                    message = "POKROV выключен на этом устройстве.",
                    stopReason = "service_destroyed",
                )
                if (boundRequest != null && boundCleanupConfirmed && boundResourcesClosed()) {
                    AndroidConnectRequestOwner.serviceStopped(boundRequest, this)
                    runtimeExecutor.shutdown()
                }
            }
        }
        // Failed bound cleanup retains the serial executor and exact service
        // reference for an explicit retry, even after Android destroys the service.
        if (boundRequest == null) runtimeExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRevoke() {
        AndroidConnectRequestOwner.invalidate()
        AndroidOperationalJournal.record(
            AndroidOperationalEvent.VPN_SERVICE,
            AndroidOperationalOutcome.REVOKED,
            activeRuntimeSession?.generation,
        )
        val commandGeneration = advanceServiceCommand()
        runtimeExecutor.execute {
            stopRuntime(
                message = "Разрешение Android было отозвано, поэтому POKROV выключен на этом устройстве.",
                stopReason = "vpn_permission_revoked",
                commandGeneration = commandGeneration,
            )
            mainHandler.post {
                if (ownsServiceCommand(commandGeneration)) stopSelf()
            }
        }
        super.onRevoke()
    }

    private fun advanceServiceCommand(): Long {
        val (generation, previous) = synchronized(serviceCommandLock) {
            serviceCommandGeneration.incrementAndGet() to activeRuntimeSession
        }
        // Fence publication before interrupting child work. Do not hold the
        // publication lock while invoking native/network cancellation hooks.
        previous?.close()
        return generation
    }

    private fun ownsServiceCommand(generation: Long): Boolean =
        lifecycleActive.get() && serviceCommandGeneration.get() == generation

    private fun replaceRuntimeSession(commandGeneration: Long, profileDigest: String,
        connectRequestId: String?, deadline: AndroidConnectDeadline?): AndroidLifecycleTaskScope {
        cancelRuntimeSession()
        healthGeneration.incrementAndGet()
        val scope = AndroidLifecycleTaskScope(
            generation = runtimeSessionGeneration.incrementAndGet(),
            threadNamePrefix = "pokrov-vpn-session",
            parallelism = 2,
        )
        activeServiceCommandGeneration = commandGeneration
        activeStartupProfileDigest = profileDigest
        activeStartupCommitted = false
        activeCoreStartCompleted = false
        activeConnectRequestId = connectRequestId
        activeConnectDeadline = deadline
        activePromotedUntilElapsed = null
        activePromotedLeaseRef = null
        activeRuntimeSession = scope
        AndroidRuntimeState.beginTunnelTrafficSession(scope.generation)
        if (deadline != null) watchConnectDeadline(scope, commandGeneration, deadline)
        return scope
    }

    private fun cancelRuntimeSession() {
        val scope = synchronized(serviceCommandLock) {
            activeRuntimeSession.also {
                if (it != null && AndroidConnectRequestOwner.ownsService(this)) endingBoundSessions.add(it)
                activeRuntimeSession = null
                activeCoreStartCompleted = false
                activeConnectDeadline = null
                activePromotedUntilElapsed = null
                activePromotedLeaseRef = null
            }
        }
        scope?.close()
        if (scope != null) {
            AndroidRuntimeState.endTunnelTrafficSession(scope.generation)
        }
    }

    internal fun hasCompletedBoundStart(request: String, profile: String): Boolean {
        val session = activeRuntimeSession ?: return false
        return runtimeOwner === this && activeConnectRequestId == request &&
            activeStartupProfileDigest == profile && activeStartupCommitted && activeCoreStartCompleted &&
            ownsRuntimeSession(session)
    }

    private fun ownsRuntimeSession(scope: AndroidLifecycleTaskScope): Boolean =
        ownsServiceCommand(activeServiceCommandGeneration) &&
            activeConnectDeadline?.isCurrent() != false &&
            (activePromotedUntilElapsed == null ||
                android.os.SystemClock.elapsedRealtime() < activePromotedUntilElapsed!!) &&
            (activeConnectDeadline == null || activeConnectRequestId?.let(AndroidConnectRequestOwner::owns) == true) &&
            activeRuntimeSession === scope && scope.isActive() &&
            (activeStartupCommitted || (AndroidRuntimeState.isStagedProfileCurrent(activeStartupProfileDigest) &&
                activeConnectRequestId.let { it == null || AndroidConnectRequestOwner.owns(it) }))

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
        commandGeneration: Long,
        connectRequestId: String?,
        expectedCoreModuleSha256: String?,
        deadline: AndroidConnectDeadline?,
    ) {
        fun ownsRequest(): Boolean = ownsServiceCommand(commandGeneration) &&
            (connectRequestId == null || AndroidConnectRequestOwner.ownsStart(
                connectRequestId, expectedCoreModuleSha256, expectedDigest, deadline))
        fun stopExpiredRequest() {
            if (!ownsServiceCommand(commandGeneration) || connectRequestId == null ||
                !AndroidConnectRequestOwner.expire(connectRequestId)) return
            stopRuntime(message = AndroidRuntimeSafety.publicFailureMessage("connect_deadline"),
                stopReason = "connect_deadline", failureKind = "connect_deadline",
                tileGeneration = tileGeneration, commandGeneration = commandGeneration)
            mainHandler.post { if (ownsServiceCommand(commandGeneration)) stopSelf() }
        }
        if (!ownsRequest()) { stopExpiredRequest(); return }
        val coreMatches = expectedCoreModuleSha256 == null ||
            AndroidRuntimeState.matchesCoreModuleSha256(expectedCoreModuleSha256)
        if (!ownsRequest()) { stopExpiredRequest(); return }
        if (!coreMatches) {
            AndroidRuntimeState.markFailure("core_identity_mismatch",
                AndroidRuntimeSafety.publicFailureMessage("core_identity_mismatch"))
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            if (activeTun == null) stopSelf()
            return
        }
        val persistedProfile = AndroidRuntimeProfileStore.load(this)
        val stagedContent = runCatching { File(configPath).readText() }.getOrNull()
        if (!ownsRequest()) { stopExpiredRequest(); return }
        val missingBoundOwner = persistedProfile?.requiresBoundConnect == true &&
            (connectRequestId == null || expectedCoreModuleSha256 == null || deadline == null)
        val catalogAppBinding = if (persistedProfile?.catalogAppIdentityRequired == true)
            AndroidCatalogAppBinding.forProfile(expectedDigest) else null
        if (missingBoundOwner || stagedContent == null || !runtimeProfileMatchesIntent(
                persistedProfile, expectedDigest, configPath, routeMode, stagedContent,
            ) || (persistedProfile?.catalogAppIdentityRequired == true && catalogAppBinding == null)) {
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
        val session = replaceRuntimeSession(commandGeneration, expectedDigest, connectRequestId, deadline)
        if (!ownsRuntimeSession(session)) {
            cleanupSupersededStartup(commandGeneration, tileGeneration)
            return
        }
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
        activeCatalogAppRequired = persistedProfile?.catalogAppIdentityRequired == true
        activeCatalogAppBinding = catalogAppBinding
        armCatalogAppExpiry(catalogAppBinding)
        val initialized = AndroidRuntimeState.initialize(this)
        if (!ownsRuntimeSession(session)) {
            cleanupSupersededStartup(commandGeneration, tileGeneration)
            return
        }
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
            if (expectedCoreModuleSha256 != null &&
                !AndroidRuntimeState.matchesCoreModuleSha256(expectedCoreModuleSha256)) {
                throw CoreIdentityMismatch()
            }
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
            val protectedTag = AndroidCoreEgressProbe.protectedTargetTag(runtimeConfig).orEmpty()
            val selectedOutbound = selectedConcreteOutbound(protectedTag)
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
            // ATS owns a separate bounded proof ladder. The legacy direct
            // endpoint preflight has no diagnostic-byte reservation and the
            // selected outbound is a lease gate, not a raw server endpoint.
            if (persistedProfile?.requiresBoundConnect != true) endpointHops.forEachIndexed { index, (_, endpoint) ->
                if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
                val endpointServer = endpoint.optString("server").trim()
                val endpointPort = endpoint.optInt("server_port")
                if (endpointServer.isBlank() || endpointPort !in 1..65535) {
                    if (index == endpointHops.lastIndex) {
                        rootEndpointPreflightCategory = "endpoint_invalid"
                    }
                    return@forEachIndexed
                }
                val preflight = AndroidStartupEndpointProbe.run(
                    context = this, scope = session, ownsSession = { ownsRuntimeSession(session) },
                    server = endpointServer, port = endpointPort,
                    timeoutMillis = ENDPOINT_PREFLIGHT_TIMEOUT_MILLIS,
                )
                if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
                if (index == endpointHops.lastIndex) {
                    rootEndpointPreflightCategory = preflight
                }
            }
            if (persistedProfile?.requiresBoundConnect != true && !offlineEmergencyRootPreflightAccepted(
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
            runCatching { commandServer?.closeService() }
            runCatching { commandServer?.close() }
            commandServer = null
            activeConfigContent = null
            activeVariantConfigContent = null
            if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
            // Closing the previous Core can unregister its monitor. Capture
            // this attempt's uplink only after that old lifecycle has ended.
            AndroidDefaultNetworkMonitor.ensureStarted(this)
            if (expectedCoreModuleSha256 != null) {
                val networkGeneration = AndroidDefaultNetworkMonitor.contextGeneration()
                if (connectRequestId == null || networkGeneration == null ||
                    !AndroidConnectRequestOwner.bindNetwork(connectRequestId, this, networkGeneration)) {
                    connectRequestId?.let(AndroidConnectRequestOwner::cancel)
                    throw SupersededRuntimeStart()
                }
            }
            val handler = object : CommandServerHandler by this@PokrovRuntimeVpnService {
                override fun serviceReload() = reloadRuntime(session)
                override fun serviceStop() = stopRuntimeFromCore(session)
                override fun writeDebugMessage(message: String) {
                    if (ownsRuntimeSession(session)) this@PokrovRuntimeVpnService.writeDebugMessage(message)
                }
            }
            val platform = object : PlatformInterface by this@PokrovRuntimeVpnService {
                override fun openTun(options: TunOptions): Int = openTunForSession(options, session)
                override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
                    if (ownsRuntimeSession(session)) {
                        AndroidDefaultNetworkMonitor.start(this@PokrovRuntimeVpnService, listener) {
                            if (ownsRuntimeSession(session)) reloadActiveRuntimeAfterDefaultNetworkChange()
                        }
                    }
                }
            }
            val nextServer = Libbox.newCommandServer(handler, platform)
            commandServer = nextServer
            boundCoreServiceClosed = false
            activeCoreRunId = AndroidCoreOperationalEvents.beginRun(
                nextServer,
                session.generation,
            )
            nextServer.start()
            if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
            activeConfigContent = content
            activeVariantConfigContent = rawContent
            activeTileStartGeneration = tileGeneration
            if (expectedCoreModuleSha256 != null &&
                !AndroidRuntimeState.matchesCoreModuleSha256(expectedCoreModuleSha256)) {
                throw CoreIdentityMismatch()
            }
            if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
            nextServer.startOrReloadService(content, OverrideOptions())
            if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
            activeCoreStartCompleted = true
            schedulePendingCoreEgressProbe(session)
            startTunnelTrafficMonitor(session)
            // Staging belongs to the bridge/store. A delayed Core start must
            // not overwrite a newer staged identity with its older profile.
        } catch (error: Throwable) {
            pendingCoreEgressProbeGeneration = null
            if (error is SupersededRuntimeStart || !ownsRuntimeSession(session)) {
                // The serial owner still owns only this attempt's resources;
                // the queued replacement/stop owns user-visible completion.
                cleanupSupersededStartup(commandGeneration, tileGeneration)
                return
            }
            AndroidOperationalJournal.record(
                AndroidOperationalEvent.VPN_SERVICE,
                AndroidOperationalOutcome.FAILED,
                session.generation,
            )
            val failureKind = if (error is CoreIdentityMismatch) "core_identity_mismatch" else "runtime_service_start_failed"
            AndroidRuntimeState.markFailure(
                kind = failureKind,
                message = AndroidRuntimeSafety.publicFailureMessage(
                    failureKind,
                ),
            )
            cleanupFailedStartup()
            activeTileStartGeneration = null
            PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
            stopSelf()
        }
    }

    private class CoreIdentityMismatch : IllegalStateException()

    private fun watchConnectDeadline(session: AndroidLifecycleTaskScope, commandGeneration: Long,
        deadline: AndroidConnectDeadline) {
        val watchdog = object : Runnable {
            override fun run() {
                if (activeRuntimeSession !== session || activeConnectDeadline !== deadline ||
                    !ownsServiceCommand(commandGeneration) || !session.isActive()) return
                if (deadline.isCurrent()) {
                    mainHandler.postDelayed(this, 100L)
                    return
                }
                // Fence callbacks and cancel owned children before queuing native
                // teardown. Deadline expiry is never a healthy-flow promotion.
                val stopGeneration = advanceServiceCommand()
                runtimeExecutor.execute {
                    if (!ownsServiceCommand(stopGeneration)) return@execute
                    stopRuntime(message = AndroidRuntimeSafety.publicFailureMessage("connect_deadline"),
                        stopReason = "connect_deadline", failureKind = "connect_deadline",
                        commandGeneration = stopGeneration)
                    mainHandler.post {
                        if (ownsServiceCommand(stopGeneration)) stopSelf()
                    }
                }
            }
        }
        session.onCancel { mainHandler.removeCallbacks(watchdog) }
        mainHandler.post(watchdog)
    }

    internal fun promoteBoundTransportLease(request: String, profile: String, lease: String,
        issuedAt: String, newFlowsUntil: String, activeFlowsUntil: String,
        completion: (Boolean) -> Unit) {
        try {
            runtimeExecutor.execute {
                val session = activeRuntimeSession
                val generation = activeServiceCommandGeneration
                val content = activeConfigContent
                val valid = session != null && hasCompletedBoundStart(request, profile) &&
                    activeConnectDeadline != null && content != null &&
                    matchesBoundTransportLease(content, lease, issuedAt, newFlowsUntil, activeFlowsUntil)
                val coreConfirmed = valid && runCatching {
                    val server = commandServer ?: return@runCatching false
                    CommandServer::class.java.getMethod("confirmATSLease", String::class.java,
                        String::class.java, String::class.java, String::class.java)
                        .invoke(server, lease, issuedAt, newFlowsUntil, activeFlowsUntil) as? Boolean == true
                }.getOrDefault(false)
                val activeUntil = runCatching { Instant.parse(activeFlowsUntil) }.getOrNull()
                val remaining = if (activeUntil == null) 0L else
                    Duration.between(Instant.now(), activeUntil).toMillis()
                val elapsed = android.os.SystemClock.elapsedRealtime()
                val promoted = coreConfirmed && remaining > 0L && remaining <= 3_600_000L &&
                    ownsServiceCommand(generation) &&
                    AndroidConnectRequestOwner.promote(request, this, profile, elapsed + remaining)
                if (promoted) {
                    activePromotedUntilElapsed = elapsed + remaining
                    activePromotedLeaseRef = lease
                    activeConnectDeadline = null
                    AndroidRuntimeState.updateCoreEgressValidation(true)
                    watchPromotedLeaseDeadline(session!!, generation, elapsed + remaining)
                } else if (coreConfirmed && ownsServiceCommand(generation)) {
                    stopRuntime(message = AndroidRuntimeSafety.publicFailureMessage("connect_deadline"),
                        stopReason = "transport_lease_handoff_unconfirmed",
                        failureKind = "connect_deadline", commandGeneration = generation)
                    mainHandler.post { if (ownsServiceCommand(generation)) stopSelf() }
                }
                mainHandler.post { completion(promoted) }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) { completion(false) }
    }

    internal fun revokeBoundTransportLease(request: String, profile: String, lease: String,
        terminateActive: Boolean, completion: (Boolean) -> Unit) {
        try {
            runtimeExecutor.execute {
                val generation = activeServiceCommandGeneration
                val current = activePromotedLeaseRef == lease && activePromotedUntilElapsed != null &&
                    hasCompletedBoundStart(request, profile) &&
                    AndroidConnectRequestOwner.owns(request) && ownsServiceCommand(generation)
                if (!current) { mainHandler.post { completion(false) }; return@execute }
                AndroidRuntimeState.updateCoreEgressValidation(false)
                val revoked = runCatching {
                    val server = commandServer ?: return@runCatching false
                    CommandServer::class.java.getMethod("revokeATSLease", String::class.java,
                        Boolean::class.javaPrimitiveType!!)
                        .invoke(server, lease, terminateActive) as? Boolean == true
                }.getOrDefault(false)
                val terminalOwnerSettled = !terminateActive ||
                    (revoked && ownsServiceCommand(generation) &&
                        AndroidConnectRequestOwner.markTransportLeaseTerminated(request, this, profile))
                if (!revoked || !ownsServiceCommand(generation) || !terminalOwnerSettled) {
                    // A lost Core receipt can hide an accepted revocation.
                    if (ownsServiceCommand(generation)) {
                        stopRuntime(message = AndroidRuntimeSafety.publicFailureMessage("connect_deadline"),
                            stopReason = "transport_lease_revocation_unconfirmed",
                            failureKind = "connect_deadline", commandGeneration = generation)
                        mainHandler.post { if (ownsServiceCommand(generation)) stopSelf() }
                    }
                    mainHandler.post { completion(false) }
                    return@execute
                }
                mainHandler.post { completion(true) }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) { completion(false) }
    }

    private fun matchesBoundTransportLease(content: String, lease: String, issuedAt: String,
        newFlowsUntil: String, activeFlowsUntil: String): Boolean {
      return try {
        val issued = Instant.parse(issuedAt)
        val newUntil = Instant.parse(newFlowsUntil)
        val activeUntil = Instant.parse(activeFlowsUntil)
        val now = Instant.now()
        if (!Regex("lease_[a-f0-9]{32}").matches(lease) ||
            listOf(issuedAt, newFlowsUntil, activeFlowsUntil).any {
                !Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z").matches(it)
            } || now.isBefore(issued) || !now.isBefore(newUntil) ||
            !newUntil.isAfter(issued) || activeUntil.isBefore(newUntil) ||
            Duration.between(issued, newUntil) > Duration.ofMinutes(10) ||
            Duration.between(issued, activeUntil) > Duration.ofHours(1)) return false
        val outbounds = JSONObject(content).optJSONArray("outbounds") ?: return false
        var gateCount = 0
        var upstreamCount = 0
        for (index in 0 until outbounds.length()) {
            val outbound = outbounds.optJSONObject(index) ?: return false
            if (outbound.optString("tag") == "pokrov-ats") {
                if (outbound.optString("type") != "pokrov-ats-lease" ||
                    outbound.optString("upstream_tag") != "pokrov-ats-upstream" ||
                    outbound.optString("lease_id") != lease || outbound.optString("issued_at") != issuedAt ||
                    outbound.optString("new_flows_until") != newFlowsUntil ||
                    outbound.optString("active_flows_until") != activeFlowsUntil) return false
                gateCount++
            }
            if (outbound.optString("tag") == "pokrov-ats-upstream") {
                if (outbound.optString("type") != "vless") return false
                upstreamCount++
            }
        }
        gateCount == 1 && upstreamCount == 1
      } catch (_: Exception) { false }
    }

    private fun watchPromotedLeaseDeadline(session: AndroidLifecycleTaskScope, generation: Long,
        expiresElapsed: Long) {
        val watchdog = object : Runnable {
            override fun run() {
                if (activeRuntimeSession !== session || activePromotedUntilElapsed != expiresElapsed ||
                    !ownsServiceCommand(generation) || !session.isActive()) return
                val remaining = expiresElapsed - android.os.SystemClock.elapsedRealtime()
                if (remaining > 0L) { mainHandler.postDelayed(this, remaining); return }
                val stopGeneration = advanceServiceCommand()
                runtimeExecutor.execute {
                    if (!ownsServiceCommand(stopGeneration)) return@execute
                    stopRuntime(message = AndroidRuntimeSafety.publicFailureMessage("connect_deadline"),
                        stopReason = "transport_lease_expired", failureKind = "connect_deadline",
                        commandGeneration = stopGeneration)
                    mainHandler.post { if (ownsServiceCommand(stopGeneration)) stopSelf() }
                }
            }
        }
        session.onCancel { mainHandler.removeCallbacks(watchdog) }
        mainHandler.post(watchdog)
    }

    private fun stopRuntime(
        message: String,
        stopReason: String,
        tileGeneration: Long? = null,
        failureKind: String? = null,
        commandGeneration: Long? = null,
    ) {
        val stoppedGeneration = activeRuntimeSession?.generation
        if (AndroidConnectRequestOwner.ownsService(this) && !closeBoundResources()) {
            reportBoundCleanupFailure()
            return
        }
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
        activeCatalogAppBinding = null
        activeCatalogAppRequired = false
        armCatalogAppExpiry(null)
        AndroidDefaultNetworkMonitor.stop(null)
        try {
            activeTun?.close()
        } catch (_: Throwable) {
        }
        activeTun = null
        if (failureKind == null) {
            AndroidRuntimeState.markStopped(message = message, stopReason = stopReason)
        } else if (failureKind == "connect_deadline") {
            // Exhausted attempt time is not a dataplane-failure revocation and
            // must not clear a concurrently staged profile from durable storage.
            AndroidRuntimeState.markStopped(message = message, stopReason = stopReason)
            AndroidRuntimeState.markFailure(kind = failureKind, message = message)
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

    private fun updateRuntimeNotification(overrideState: AndroidRuntimeNotificationState? = null) {
        val runtimeSnapshot = AndroidRuntimeState.snapshot()
        val content = androidRuntimeNotificationContent(
            overrideState ?: androidRuntimeNotificationStateForEgress(
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
            // A shared UID cannot identify which package owns this connection.
            // Keep the UID for explicit UID rules, but never let an arbitrary
            // first package authorize a package-specific route or DNS rule.
            val packageName = packageManager.getPackagesForUid(uid)
                ?.distinct()?.singleOrNull().orEmpty()
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
        val session = activeRuntimeSession ?: error("android: inactive runtime session")
        return openTunForSession(options, session)
    }

    private fun openTunForSession(options: TunOptions, session: AndroidLifecycleTaskScope): Int {
        if (prepare(this) != null) {
            error("android: missing vpn permission")
        }
        if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()

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
                throw IllegalStateException("Invalid or conflicting application routing scope.")
            }
            packagePlan.allowedPackages.forEach { allowedPackage ->
                try {
                    builder.addAllowedApplication(allowedPackage)
                } catch (_: Exception) {
                    throw IllegalStateException("Selected application scope changed.")
                }
                includePackageCount += 1
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
                try {
                    builder.addDisallowedApplication(disallowedPackage)
                } catch (_: Exception) {
                    throw IllegalStateException("Excluded application scope changed.")
                }
                excludePackageCount += 1
            }
            if (activeCatalogAppRequired) {
                val selected = if (activeSelectedAppsMode) packagePlan.allowedPackages.toSet()
                    else packagePlan.disallowedPackages.filter { it != packageName }.toSet()
                if (activeCatalogAppBinding?.verifies(this, selected) != true) {
                    throw IllegalStateException("Catalog application scope changed.")
                }
            }
        }
        if (!ownsRuntimeSession(session)) throw SupersededRuntimeStart()
        val tun = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null.")
        // A failed establish leaves the old TUN and its health callbacks intact.
        // Fence old callbacks before publishing the successful replacement.
        val tunGeneration = healthGeneration.incrementAndGet()
        releaseDnsFailureToken()
        var replacedTun: ParcelFileDescriptor? = null
        synchronized(serviceCommandLock) {
            // Staging/invalidation uses this same state monitor. The first
            // successful TUN publication must still belong to its staged digest.
            // Request cancellation shares the publication boundary as well;
            // its accepted reply cannot precede a stale initial commit.
            synchronized(AndroidConnectRequestOwner) {
                synchronized(AndroidRuntimeState) {
                    if (!ownsRuntimeSession(session) ||
                        (activeCatalogAppRequired && activeCatalogAppBinding?.isValid() != true)) {
                        runCatching { tun.close() }
                        throw SupersededRuntimeStart()
                    }
                    replacedTun = activeTun
                    activeTun = tun
                    activeStartupCommitted = true
                    AndroidRuntimeState.recordTunConfiguration(
                        ipv4RouteCount = ipv4RouteCount,
                        ipv6RouteCount = ipv6RouteCount,
                        includePackageCount = includePackageCount,
                        excludePackageCount = excludePackageCount,
                    )
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
                }
            }
        }
        runCatching { replacedTun?.close() }
        PokrovQuickSettingsTileService.completeRuntimeTransition(
            this,
            activeTileStartGeneration,
        )
        activeTileStartGeneration = null
        // Core opens the TUN before startOrReloadService marks it STARTED.
        // Probe only after that call returns, or Core reports unavailable.
        pendingCoreEgressProbeGeneration = tunGeneration
        return tun.fd
    }

    private fun schedulePendingCoreEgressProbe(session: AndroidLifecycleTaskScope) {
        val generation = pendingCoreEgressProbeGeneration ?: return
        pendingCoreEgressProbeGeneration = null
        if (ownsRuntimeSession(session) && healthGeneration.get() == generation && activeTun != null) {
            scheduleCoreEgressProbe(session, generation)
        }
    }

    private fun scheduleCoreEgressProbe(
        session: AndroidLifecycleTaskScope,
        generation: Long,
    ) {
        if (!ownsRuntimeSession(session)) return
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
                    result.isCompletedFailure &&
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

    private fun cleanupSupersededStartup(commandGeneration: Long, tileGeneration: Long?) {
        cleanupFailedStartup()
        activeTileStartGeneration = null
        PokrovQuickSettingsTileService.completeRuntimeTransition(this, tileGeneration)
        mainHandler.post {
            // A staging invalidation can cancel a pending start without sending
            // STOP. Retire that foreground service, but never a newer command.
            if (ownsServiceCommand(commandGeneration)) {
                AndroidRuntimeState.cancelPendingConnection()
                stopSelf()
            }
        }
    }

    private fun cleanupFailedStartup() {
        if (AndroidConnectRequestOwner.ownsService(this)) {
            if (!closeBoundResources()) reportBoundCleanupFailure()
            return
        }
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
        releaseDnsFailureToken()
        runCatching { commandServer?.closeService() }
        runCatching { commandServer?.close() }
        commandServer = null
        activeCoreRunId = null
        activeConfigContent = null
        activeVariantConfigContent = null
        activeCatalogAppBinding = null
        activeCatalogAppRequired = false
        armCatalogAppExpiry(null)
        AndroidDefaultNetworkMonitor.stop(null)
        runCatching { activeTun?.close() }
        activeTun = null
        markServiceStopped()
    }

    private fun reportBoundCleanupFailure() {
        AndroidRuntimeState.markConnectionPending()
        AndroidRuntimeState.markDegraded("runtime_stop_failed",
            AndroidRuntimeSafety.publicFailureMessage("runtime_stop_failed"))
    }

    private fun boundResourcesClosed(): Boolean = commandServer == null && activeTun == null &&
        synchronized(serviceCommandLock) { endingBoundSessions.isEmpty() && activeRuntimeSession == null }

    // Only called by the serial runtime executor after any startup invocation.
    // Keep every failed resource handle for an exact retry instead of reporting stopped.
    private fun closeBoundResources(): Boolean {
        boundCleanupConfirmed = false
        healthGeneration.incrementAndGet()
        cancelRuntimeSession()
        var closed = true
        try { releaseDnsFailureToken() } catch (_: Throwable) { closed = false }
        val server = commandServer
        if (server != null) {
            try {
                if (!boundCoreServiceClosed) {
                    server.closeService()
                    boundCoreServiceClosed = true
                }
                server.close()
                commandServer = null
            } catch (_: Throwable) { closed = false }
        }
        try { AndroidDefaultNetworkMonitor.stop(null) } catch (_: Throwable) { closed = false }
        try { activeTun?.close(); activeTun = null } catch (_: Throwable) { closed = false }
        val scopes = synchronized(serviceCommandLock) { endingBoundSessions.toList() }
        for (scope in scopes) {
            if (scope.awaitClosed(30_000L)) synchronized(serviceCommandLock) { endingBoundSessions.remove(scope) }
            else closed = false
        }
        if (!closed || !boundResourcesClosed()) return false
        activeCoreRunId = null
        activeConfigContent = null
        activeVariantConfigContent = null
        activeCatalogAppBinding = null
        activeCatalogAppRequired = false
        armCatalogAppExpiry(null)
        markServiceStopped()
        boundCleanupConfirmed = true
        return true
    }

    internal fun cancelAndConfirmConnectStopped(request: String, stopReason: String = "user_requested",
        completion: (Boolean) -> Unit) {
        if (AndroidConnectRequestOwner.serviceFor(request) !== this ||
            !AndroidConnectRequestOwner.ownsCancellation(request)) { completion(false); return }
        // Fence native callbacks immediately; the cleanup itself remains serial.
        val commandGeneration = advanceServiceCommand()
        try {
            runtimeExecutor.execute {
                if (AndroidConnectRequestOwner.isStopped(request)) { completion(true); return@execute }
                if (AndroidConnectRequestOwner.serviceFor(request) !== this) { completion(false); return@execute }
                val completed = runCatching {
                    stopRuntime(message = "POKROV выключен на этом устройстве.", stopReason = stopReason,
                        commandGeneration = commandGeneration)
                }.isSuccess
                val settled = completed && boundCleanupConfirmed && boundResourcesClosed() &&
                    AndroidConnectRequestOwner.serviceStopped(request, this)
                if (settled) {
                    if (!lifecycleActive.get()) runtimeExecutor.shutdown()
                    else mainHandler.post { if (ownsServiceCommand(commandGeneration)) stopSelf() }
                }
                completion(settled)
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
            completion(AndroidConnectRequestOwner.isStopped(request))
        }
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
                AndroidCoreEgressProbeResult.FAILED,
                AndroidCoreEgressProbeResult.CONNECT_FAILED,
                AndroidCoreEgressProbeResult.TLS_FAILED,
                -> AndroidOperationalOutcome.FAILED
                AndroidCoreEgressProbeResult.UNAVAILABLE,
                AndroidCoreEgressProbeResult.TIMED_OUT,
                -> AndroidOperationalOutcome.STALLED
            },
            generation,
        )
        if (keepRuntimeOnFailure && probeResult != AndroidCoreEgressProbeResult.HEALTHY) {
            val failureKind = probeResult.failureKind()
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

        val failureKind = probeResult.failureKind()
        val failureMessage = AndroidRuntimeSafety.publicFailureMessage(failureKind)
        AndroidRuntimeState.updateCoreEgressValidation(false)
        stopRuntime(
            message = failureMessage,
            stopReason = if (probeResult.isCompletedFailure) {
                "core_egress_probe_failed"
            } else {
                "core_egress_probe_unavailable"
            },
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
                if (cancelBoundRuntimeForReload(session)) return@execute
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
                    schedulePendingCoreEgressProbe(session)
                }.onSuccess {
                    if (activeTun !== previousTun) {
                        runCatching { previousTun?.close() }
                    }
                }.onFailure {
                    pendingCoreEgressProbeGeneration = null
                    if (ownsRuntimeSession(session)) AndroidRuntimeState.markDegraded(
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
        reloadRuntime(session)
    }

    private fun reloadRuntime(session: AndroidLifecycleTaskScope) {
        runtimeExecutor.execute {
            if (!ownsRuntimeSession(session)) {
                return@execute
            }
            if (cancelBoundRuntimeForReload(session)) return@execute
            val content = activeConfigContent ?: return@execute
            val server = commandServer ?: return@execute
            try {
                server.startOrReloadService(content, OverrideOptions())
                schedulePendingCoreEgressProbe(session)
            } catch (error: Throwable) {
                pendingCoreEgressProbeGeneration = null
                throw error
            }
        }
    }

    private fun cancelBoundRuntimeForReload(session: AndroidLifecycleTaskScope): Boolean {
        if (activeRuntimeSession !== session || activeConnectDeadline == null) return false
        val request = activeConnectRequestId ?: return true
        if (AndroidConnectRequestOwner.cancel(request)) {
            cancelAndConfirmConnectStopped(request, stopReason = "bound_runtime_reload") {}
        }
        return true // a new Core instance needs a new bound attempt and proof
    }

    override fun serviceStop() {
        val session = activeRuntimeSession ?: return
        stopRuntimeFromCore(session)
    }

    private fun stopRuntimeFromCore(session: AndroidLifecycleTaskScope) {
        runtimeExecutor.execute {
            if (!ownsRuntimeSession(session)) return@execute
            val commandGeneration = activeServiceCommandGeneration
            stopRuntime(
                message = "POKROV выключен на этом устройстве.",
                stopReason = "command_server_requested",
                commandGeneration = commandGeneration,
            )
            mainHandler.post {
                if (ownsServiceCommand(commandGeneration)) stopSelf()
            }
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
        @Volatile private var runtimeOwner: PokrovRuntimeVpnService? = null

        fun promoteBoundTransportLease(request: String, profile: String, lease: String,
            issuedAt: String, newFlowsUntil: String, activeFlowsUntil: String,
            completion: (Boolean) -> Unit) {
            val owner = AndroidConnectRequestOwner.serviceFor(request)
            if (owner == null || runtimeOwner !== owner) { completion(false); return }
            owner.promoteBoundTransportLease(request, profile, lease, issuedAt,
                newFlowsUntil, activeFlowsUntil, completion)
        }

        fun revokeBoundTransportLease(request: String, profile: String, lease: String,
            terminateActive: Boolean, completion: (Boolean) -> Unit) {
            val owner = AndroidConnectRequestOwner.serviceFor(request)
            if (owner == null || runtimeOwner !== owner) { completion(false); return }
            owner.revokeBoundTransportLease(request, profile, lease, terminateActive, completion)
        }

        fun readSmartAccessLeases(profileDigest: String, reply: (String?) -> Unit) {
            if (!Regex("^[a-f0-9]{64}$").matches(profileDigest)) { reply(null); return }
            val owner = runtimeOwner ?: run { reply(null); return }
            val session = owner.activeRuntimeSession ?: run { reply(null); return }
            val generation = owner.serviceCommandGeneration.get()
            fun current() = runtimeOwner === owner && owner.ownsRuntimeSession(session) &&
                owner.serviceCommandGeneration.get() == generation &&
                owner.activeStartupProfileDigest == profileDigest && owner.activeStartupCommitted
            try {
                owner.runtimeExecutor.execute {
                    val server = owner.commandServer
                    val encoded = if (!current() || server == null) null else try {
                        CommandServer::class.java.getMethod("readSmartAccessLeases").invoke(server) as? String
                    } catch (_: ReflectiveOperationException) { null }
                      catch (_: LinkageError) { null }
                    val bounded = encoded?.takeIf { it.toByteArray(Charsets.UTF_8).size <= 65536 }
                    owner.mainHandler.post { reply(if (current()) bounded else null) }
                }
            } catch (_: java.util.concurrent.RejectedExecutionException) { reply(null) }
        }

        fun configureSmartAccessRuntimeControl(profileDigest: String, configJson: String, renewal: Boolean = false,
            connectRequestId: String? = null, reply: (Boolean?) -> Unit) {
            // This sensitive command never enters the saved profile or logs.
            val bound = try {
                if (configJson.toByteArray(Charsets.UTF_8).size > 16384) false else {
                    val config = JSONObject(configJson)
                    val platform = if (renewal) config.optJSONObject("lease")?.optString("platform") else config.optString("platform")
                    config.optString("profile_digest") == profileDigest && platform == "android"
                }
            } catch (_: org.json.JSONException) { false }
            if (!bound) { reply(null); return }
            restrictRuntimeProfile(profileDigest, reply, invalidateBefore = true, connectRequestId = connectRequestId) { server ->
                val method = if (renewal) "configureSmartAccessRenewal" else "configureSmartAccessRuntimeControl"
                CommandServer::class.java.getMethod(method, String::class.java, String::class.java)
                    .invoke(server, profileDigest, configJson) as? Boolean
            }
        }

        fun renewSmartAccessLease(profileDigest: String, expectedLeaseId: String, nextLeaseId: String,
                                  issuedAt: String, newFlowsUntil: String, activeFlowsUntil: String,
                                  reply: (Boolean?) -> Unit) {
            val id = Regex("^[a-f0-9]{32}$")
            val utc = Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
            if (!id.matches(expectedLeaseId) || !id.matches(nextLeaseId) ||
                !utc.matches(issuedAt) || !utc.matches(newFlowsUntil) || !utc.matches(activeFlowsUntil)) {
                reply(null)
                return
            }
            restrictRuntimeProfile(profileDigest, reply, invalidateBefore = true) { server ->
                CommandServer::class.java.getMethod("renewSmartAccessLease",
                    String::class.java, String::class.java, String::class.java, String::class.java, String::class.java)
                    .invoke(server, expectedLeaseId, nextLeaseId, issuedAt, newFlowsUntil, activeFlowsUntil) as? Boolean
            }
        }

        fun revokeSmartAccessLease(profileDigest: String, leaseId: String,
                                   terminateActive: Boolean, reply: (Boolean?) -> Unit) {
            if (!Regex("^[a-f0-9]{32}$").matches(leaseId)) { reply(null); return }
            restrictRuntimeProfile(profileDigest, reply) { server ->
                CommandServer::class.java.getMethod("revokeSmartAccessLease",
                    String::class.java, java.lang.Boolean.TYPE).invoke(server, leaseId, terminateActive) as? Boolean
            }
        }

        fun revokeRoutingCatalog(profileDigest: String, reply: (Boolean?) -> Unit) {
            restrictRuntimeProfile(profileDigest, reply) { server ->
                CommandServer::class.java.getMethod("revokeRoutingCatalog").invoke(server) as? Boolean
            }
        }

        fun revokeRoutingCatalogService(profileDigest: String, serviceId: String, reply: (Boolean?) -> Unit) {
            if (!Regex("^[a-z0-9][a-z0-9._-]{0,63}$").matches(serviceId)) {
                reply(null)
                return
            }
            restrictRuntimeProfile(profileDigest, reply) { server ->
                CommandServer::class.java.getMethod("revokeRoutingCatalogService", String::class.java)
                    .invoke(server, serviceId) as? Boolean
            }
        }

        fun revokeSmartAccessPolicy(profileDigest: String, terminateActive: Boolean, reply: (Boolean?) -> Unit) {
            restrictRuntimeProfile(profileDigest, reply) { server ->
                CommandServer::class.java.getMethod("revokeSmartAccessPolicy", java.lang.Boolean.TYPE)
                    .invoke(server, terminateActive) as? Boolean
            }
        }

        private fun restrictRuntimeProfile(profileDigest: String, reply: (Boolean?) -> Unit,
                                           invalidateBefore: Boolean = false,
                                           connectRequestId: String? = null,
                                           revoke: (CommandServer) -> Boolean?) {
            if (!Regex("^[a-f0-9]{64}$").matches(profileDigest)) { reply(null); return }
            val owner = runtimeOwner ?: run { reply(null); return }
            val session = owner.activeRuntimeSession ?: run { reply(null); return }
            val generation = owner.serviceCommandGeneration.get()
            fun ownsConnect(): Boolean = connectRequestId == null ||
                (owner.activeConnectRequestId == connectRequestId &&
                    AndroidConnectRequestOwner.serviceFor(connectRequestId) === owner &&
                    AndroidConnectRequestOwner.owns(connectRequestId))
            try {
                owner.runtimeExecutor.execute {
                    val server = owner.commandServer
                    val current = runtimeOwner === owner && owner.ownsRuntimeSession(session) &&
                        owner.serviceCommandGeneration.get() == generation &&
                        owner.activeStartupProfileDigest == profileDigest && owner.activeStartupCommitted && ownsConnect()
                    // Renewal or background restrictions can make the saved
                    // bytes obsolete without a later UI callback. Persist reuse
                    // invalidation before enabling either native operation.
                    val reuseInvalidated = current && server != null && (!invalidateBefore ||
                        AndroidRuntimeProfileStore.invalidateMatchingProfile(owner, profileDigest))
                    val revoked = if (!reuseInvalidated || server == null || !ownsConnect()) null else try {
                        revoke(server)
                    } catch (_: ReflectiveOperationException) { null }
                      catch (_: LinkageError) { null }
                    val result = if (revoked == true && !invalidateBefore) {
                        // The live Core already tightened admission. Prevent a
                        // later tile/service restart from recreating withdrawn rules
                        // from the same staged bytes after the UI disappears.
                        if (AndroidRuntimeProfileStore.invalidateMatchingProfile(owner, profileDigest)) true else null
                    } else revoked
                    owner.mainHandler.post {
                        reply(if (runtimeOwner === owner && owner.ownsRuntimeSession(session) &&
                            owner.serviceCommandGeneration.get() == generation &&
                            owner.activeStartupProfileDigest == profileDigest && owner.activeStartupCommitted && ownsConnect()) result else null)
                    }
                }
            } catch (_: java.util.concurrent.RejectedExecutionException) { reply(null) }
        }

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
        private const val EXTRA_CORE_MODULE_SHA256 = "extra_core_module_sha256"
        private const val EXTRA_CONNECT_BOOT_REF = "extra_connect_boot_ref"
        private const val EXTRA_CONNECT_STARTED_MS = "extra_connect_started_ms"
        private const val EXTRA_CONNECT_DEADLINE_MS = "extra_connect_deadline_ms"
        private const val EXTRA_CONNECT_REQUEST = "extra_connect_request"
        private const val EXTRA_CANCEL_CONNECT_REQUEST = "extra_cancel_connect_request"
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

        internal fun start(
            context: Context,
            configPath: String,
            routeMode: String,
            profileDigest: String,
            tileGeneration: Long? = null,
            connectRequestId: String? = null,
            expectedCoreModuleSha256: String? = null,
            deadline: AndroidConnectDeadline? = null,
        ) {
            val intent = Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CONFIG_PATH, configPath)
                putExtra(EXTRA_ROUTE_MODE, routeMode)
                putExtra(EXTRA_PROFILE_DIGEST, profileDigest)
                connectRequestId?.let { putExtra(EXTRA_CONNECT_REQUEST, it) }
                expectedCoreModuleSha256?.let { putExtra(EXTRA_CORE_MODULE_SHA256, it) }
                deadline?.let {
                    putExtra(EXTRA_CONNECT_BOOT_REF, it.bootRef)
                    putExtra(EXTRA_CONNECT_STARTED_MS, it.startedElapsedMs)
                    putExtra(EXTRA_CONNECT_DEADLINE_MS, it.expiresElapsedMs)
                }
                tileGeneration?.let {
                    putExtra(PokrovQuickSettingsTileService.EXTRA_TILE_TRANSITION_GENERATION, it)
                }
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun cancelConnectRequest(context: Context, requestId: String) {
            context.startService(Intent(context, PokrovRuntimeVpnService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_CANCEL_CONNECT_REQUEST, requestId)
            })
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

    private class SupersededRuntimeStart : IllegalStateException("Runtime start superseded.")

}

internal fun offlineEmergencyRootPreflightAccepted(
    coreEgressProbeRequired: Boolean,
    rootCategory: String?,
): Boolean = coreEgressProbeRequired || rootCategory == "reachable"
