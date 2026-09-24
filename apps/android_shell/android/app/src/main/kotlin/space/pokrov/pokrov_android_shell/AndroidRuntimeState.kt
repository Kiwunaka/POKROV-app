package space.pokrov.pokrov_android_shell

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.SetupOptions
import go.Seq
import java.io.File
import java.time.Instant
import java.util.zip.ZipFile

internal data class AndroidPackagedCoreLocation(
    val artifactDirectory: String,
    val coreBinaryPath: String,
)

internal object AndroidPackagedRuntimeLocator {
    private const val CORE_LIBRARY_NAME = "libpokrov-core.so"

    fun resolve(
        nativeLibraryDir: String?,
        apkPaths: List<String>,
        supportedAbis: List<String>,
    ): AndroidPackagedCoreLocation? {
        if (!nativeLibraryDir.isNullOrBlank()) {
            val extractedCore = File(nativeLibraryDir, CORE_LIBRARY_NAME)
            if (extractedCore.isFile) {
                return AndroidPackagedCoreLocation(
                    artifactDirectory = nativeLibraryDir,
                    coreBinaryPath = extractedCore.absolutePath,
                )
            }
        }

        for (apkPath in apkPaths.filter(String::isNotBlank).distinct()) {
            val apk = File(apkPath)
            if (!apk.isFile) {
                continue
            }
            val packagedEntry = runCatching {
                ZipFile(apk).use { zip ->
                    supportedAbis
                        .asSequence()
                        .map(String::trim)
                        .filter(String::isNotEmpty)
                        .map { abi -> "lib/$abi/$CORE_LIBRARY_NAME" }
                        .firstOrNull { entry -> zip.getEntry(entry) != null }
                }
            }.getOrNull()
            if (packagedEntry != null) {
                return AndroidPackagedCoreLocation(
                    artifactDirectory = apk.absolutePath,
                    coreBinaryPath = "${apk.absolutePath}!/$packagedEntry",
                )
            }
        }
        return null
    }
}

internal data class AndroidRuntimeEnvironment(
    val artifactDirectory: String,
    val coreBinaryPath: String,
    val baseDirectory: File,
    val workingDirectory: File,
    val tempDirectory: File,
    val configDirectory: File,
)

internal enum class AndroidRuntimePhase(val wireValue: String) {
    ARTIFACT_MISSING("artifactMissing"),
    ARTIFACT_READY("artifactReady"),
    INITIALIZED("initialized"),
    CONFIG_STAGED("configStaged"),
    RUNNING("running"),
}

internal object AndroidRuntimeState {
    private const val EGRESS_PROBE_DIAGNOSTIC_PREFIX = "egress_probe_"

    private var environment: AndroidRuntimeEnvironment? = null
    private var phase: AndroidRuntimePhase = AndroidRuntimePhase.ARTIFACT_MISSING
    private var stagedConfigPath: String? = null
    private var lastMessage = "POKROV has not checked this device yet."
    private var lastRunningMessage: String? = null
    private var runningSince: String? = null
    private var defaultNetworkInterface: String? = null
    private var defaultNetworkIndex: Int? = null
    private var dnsReady: Boolean = false
    private var vpnValidated: Boolean? = null
    private var coreEgressValidated: Boolean? = null
    private var stagedProfileDigest: String? = null
    private var stagedRequiresBoundConnect: Boolean = false
    private var activeProfileDigest: String? = null
    private var coreEgressValidationRequired: Boolean = true
    private var routingCatalogWindowVersion: Int = 0
    private var smartAccessLeaseVersion: Int = 0
    private var smartAccessRuntimeControlVersion: Int = 0
    private var routingCatalogControlVersion: Int = 0
    private var transportCapabilitiesJson: String? = null
    private var coreModuleSha256: String? = null
    private var lastFailureKind: String? = null
    private var lastStopReason: String? = null
    private var awgSafeDiagnosticCode: String? = null
    private var awgSafeDiagnosticOccurrence: Int? = null
    private var ipv4RouteCount: Int = 0
    private var ipv6RouteCount: Int = 0
    private var includePackageCount: Int = 0
    private var excludePackageCount: Int = 0
    private var systemNotificationWarning: Boolean = false
    private var connectionPending: Boolean = false
    private var tunnelTrafficGeneration: Long = 0L
    private var tunnelTrafficState: AndroidTunnelTrafficSampleState =
        AndroidTunnelTrafficSampleState.UNAVAILABLE
    private var tunnelUplinkBps: Long? = null
    private var tunnelDownlinkBps: Long? = null
    private var tunnelUplinkTotalBytes: Long? = null
    private var tunnelDownlinkTotalBytes: Long? = null

    @Synchronized
    fun resolveEnvironment(context: Context): AndroidRuntimeEnvironment? {
        val applicationInfo = context.applicationInfo
        val apkPaths = mutableListOf(applicationInfo.sourceDir)
        applicationInfo.splitSourceDirs?.let(apkPaths::addAll)
        val packagedCore = AndroidPackagedRuntimeLocator.resolve(
            nativeLibraryDir = applicationInfo.nativeLibraryDir,
            apkPaths = apkPaths,
            supportedAbis = Build.SUPPORTED_ABIS.toList(),
        )
        if (packagedCore == null) {
            environment = null
            phase = AndroidRuntimePhase.ARTIFACT_MISSING
            stagedConfigPath = null
            stagedProfileDigest = null
            stagedRequiresBoundConnect = false
            activeProfileDigest = null
            coreEgressValidated = null
            runningSince = null
            invalidateTunnelTrafficSession()
            lastMessage = "В этой сборке для Android нет модуля подключения."
            dnsReady = false
            defaultNetworkInterface = null
            defaultNetworkIndex = null
            return null
        }

        val baseDirectory = File(context.filesDir, "pokrov-runtime")
        val workingDirectory = File(baseDirectory, "working")
        val tempDirectory = File(baseDirectory, "temp")
        val configDirectory = File(workingDirectory, "configs")
        listOf(baseDirectory, workingDirectory, tempDirectory, configDirectory).forEach {
            if (!it.exists()) {
                it.mkdirs()
            }
        }

        val resolved = AndroidRuntimeEnvironment(
            artifactDirectory = packagedCore.artifactDirectory,
            coreBinaryPath = packagedCore.coreBinaryPath,
            baseDirectory = baseDirectory,
            workingDirectory = workingDirectory,
            tempDirectory = tempDirectory,
            configDirectory = configDirectory,
        )
        environment = resolved
        if (phase == AndroidRuntimePhase.ARTIFACT_MISSING) {
            phase = AndroidRuntimePhase.ARTIFACT_READY
            lastMessage = "POKROV found the packaged runtime and can get this device ready."
        }
        return resolved
    }

    @Synchronized
    fun initialize(context: Context): Boolean {
        routingCatalogWindowVersion = 0
        smartAccessLeaseVersion = 0
        smartAccessRuntimeControlVersion = 0
        routingCatalogControlVersion = 0
        transportCapabilitiesJson = null
        coreModuleSha256 = null
        val resolved = resolveEnvironment(context) ?: return false
        return try {
            Seq.setContext(context.applicationContext)
            Libbox.touch()
            Libbox.setup(
                SetupOptions().apply {
                    setBasePath(resolved.baseDirectory.absolutePath)
                    setWorkingPath(resolved.workingDirectory.absolutePath)
                    setTempPath(resolved.tempDirectory.absolutePath)
                    setFixAndroidStack(true)
                    // Debug builds classify native failures into fixed safe categories.
                    // Raw Core messages are never forwarded to logcat.
                    setDebug(
                        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0,
                    )
                    setLogMaxLines(3000)
                },
            )
            // The retained AAR has no catalog getter. Read the loaded binding
            // without advertising a source-only capability on that artifact.
            routingCatalogWindowVersion = readRoutingCatalogWindowVersion()
            smartAccessLeaseVersion = readSmartAccessLeaseVersion()
            routingCatalogControlVersion = readRoutingCatalogControlVersion()
            smartAccessRuntimeControlVersion = readSmartAccessRuntimeControlVersion()
            transportCapabilitiesJson = readTransportCapabilities()
            coreModuleSha256 = readCoreModuleSha256()
            phase = if (phase == AndroidRuntimePhase.RUNNING) {
                AndroidRuntimePhase.RUNNING
            } else {
                AndroidRuntimePhase.INITIALIZED
            }
            lastMessage = "POKROV подготовил устройство."
            true
        } catch (_: Throwable) {
            phase = AndroidRuntimePhase.ARTIFACT_READY
            connectionPending = false
            lastFailureKind = "runtime_initialization_failed"
            lastMessage = AndroidRuntimeSafety.publicFailureMessage(
                "runtime_initialization_failed",
            )
            false
        }
    }

    @Synchronized
    fun matchesCoreModuleSha256(expected: String): Boolean =
        expected.length == 64 && expected.all { it in '0'..'9' || it in 'a'..'f' } &&
            readCoreModuleSha256() == expected

    private fun readCoreModuleSha256(): String? = try {
        val value = Class.forName("space.pokrov.core.mobile.Mobile")
            .getMethod("coreModuleSHA256").invoke(null)
        (value as? String)?.takeIf { digest ->
            digest.length == 64 && digest.all { it in '0'..'9' || it in 'a'..'f' }
        }
    } catch (_: ReflectiveOperationException) {
        null
    } catch (_: LinkageError) {
        null
    }

    private fun readTransportCapabilities(): String? = try {
        val value = Libbox::class.java.getMethod("transportCapabilities").invoke(null)
        // The shared Dart decoder admits the closed feature schema. Keep the
        // bridge bounded and ASCII-only; never log the native return value.
        (value as? String)?.takeIf { it.length in 1..4096 && it.all { char -> char.code in 32..126 } }
    } catch (_: ReflectiveOperationException) {
        null
    } catch (_: LinkageError) {
        null
    }

    private fun readSmartAccessRuntimeControlVersion(): Int = try {
        val version = Libbox::class.java.getMethod("smartAccessRuntimeControlVersion").invoke(null)
        space.pokrov.core.libbox.CommandServer::class.java.getMethod("configureSmartAccessRuntimeControl", String::class.java, String::class.java)
        space.pokrov.core.libbox.CommandServer::class.java.getMethod("configureSmartAccessRenewal", String::class.java, String::class.java)
        Libbox::class.java.getMethod("readSmartAccessRestrictions")
        space.pokrov.core.libbox.CommandServer::class.java.getMethod("readSmartAccessLeases")
        Libbox::class.java.getMethod("acknowledgeSmartAccessRestrictions", String::class.java)
        if (version == 1 && routingCatalogControlVersion >= 2) 1 else 0
    } catch (_: ReflectiveOperationException) {
        0
    } catch (_: LinkageError) {
        0
    }

    private fun readRoutingCatalogControlVersion(): Int = try {
        val version = Libbox::class.java.getMethod("routingCatalogControlVersion").invoke(null)
        space.pokrov.core.libbox.CommandServer::class.java.getMethod("revokeRoutingCatalog")
        if (version == 2 || version == 3 || version == 4) {
            space.pokrov.core.libbox.CommandServer::class.java.getMethod("revokeSmartAccessPolicy", java.lang.Boolean.TYPE)
        }
        if (version == 3 || version == 4) {
            space.pokrov.core.libbox.CommandServer::class.java.getMethod("revokeRoutingCatalogService", String::class.java)
        }
        if (version == 4) {
            space.pokrov.core.libbox.CommandServer::class.java.getMethod("renewSmartAccessLease",
                String::class.java, String::class.java, String::class.java, String::class.java, String::class.java)
        }
        if (version is Int && version in 1..4 && routingCatalogWindowVersion == 1 &&
            (version == 1 || smartAccessLeaseVersion == 1)) version else 0
    } catch (_: ReflectiveOperationException) {
        0
    } catch (_: LinkageError) {
        0
    }

    private fun readSmartAccessLeaseVersion(): Int = try {
        val version = Libbox::class.java.getMethod("smartAccessLeaseVersion").invoke(null)
        space.pokrov.core.libbox.CommandServer::class.java.getMethod(
            "revokeSmartAccessLease", String::class.java, java.lang.Boolean.TYPE,
        )
        if (version is Int && version == 1 && routingCatalogWindowVersion == 1) 1 else 0
    } catch (_: ReflectiveOperationException) {
        0
    } catch (_: LinkageError) {
        0
    }

    private fun readRoutingCatalogWindowVersion(): Int = try {
        val version = Libbox::class.java.getMethod("routingCatalogWindowVersion").invoke(null)
        if (version is Int && version == 1) 1 else 0
    } catch (_: ReflectiveOperationException) {
        0
    } catch (_: LinkageError) {
        0
    }

    @Synchronized
    fun markProfileStaged(
        path: String,
        preserveConnectionPending: Boolean = false,
        profileDigest: String? = null,
        requiresBoundConnect: Boolean = false,
    ) {
        stagedConfigPath = path
        stagedProfileDigest = profileDigest?.takeIf(::isRuntimeProfileDigest)
        stagedRequiresBoundConnect = requiresBoundConnect
        if (activeProfileDigest != stagedProfileDigest) coreEgressValidated = null
        phase = AndroidRuntimePhase.CONFIG_STAGED
        if (!preserveConnectionPending) {
            connectionPending = false
        }
        if (!systemNotificationWarning) {
            lastFailureKind = null
        }
        lastStopReason = null
        lastMessage = if (systemNotificationWarning) {
            AndroidRuntimeSafety.publicFailureMessage("notification_permission_denied")
        } else {
            "POKROV подготовил профиль для этого устройства."
        }
    }

    /**
     * Drops a reusable profile pointer without touching a live TUN. The active
     * service owns its already-open configuration; after it stops there is no
     * staged profile for Quick Settings to restart.
     */
    @Synchronized
    fun invalidateStagedProfile(expectedDigest: String? = null) {
        if (expectedDigest != null && stagedProfileDigest != expectedDigest) return
        stagedConfigPath = null
        stagedProfileDigest = null
        stagedRequiresBoundConnect = false
        connectionPending = false
        if (phase != AndroidRuntimePhase.RUNNING) {
            phase = if (environment != null) {
                AndroidRuntimePhase.INITIALIZED
            } else {
                AndroidRuntimePhase.ARTIFACT_MISSING
            }
            lastMessage = "Настройки POKROV изменены. Перед подключением обновите профиль."
        }
    }

    @Synchronized
    fun markConnectionRequested() {
        connectionPending = true
        vpnValidated = null
        coreEgressValidated = null
        awgSafeDiagnosticCode = null
        awgSafeDiagnosticOccurrence = null
        invalidateTunnelTrafficSession()
    }

    @Synchronized
    fun recordAwgSafeDiagnostic(diagnostic: AndroidAwgSafeDiagnostic) {
        if (
            awgSafeDiagnosticCode?.startsWith(EGRESS_PROBE_DIAGNOSTIC_PREFIX) == true &&
            !diagnostic.code.startsWith(EGRESS_PROBE_DIAGNOSTIC_PREFIX)
        ) {
            return
        }
        awgSafeDiagnosticCode = diagnostic.code
        awgSafeDiagnosticOccurrence = diagnostic.occurrence
    }

    @Synchronized
    fun cancelPendingConnection() {
        connectionPending = false
    }

    @Synchronized
    fun isConnectionPending(): Boolean = connectionPending

    @Synchronized
    fun markPermissionRequested() {
        connectionPending = true
        lastMessage = if (systemNotificationWarning) {
            AndroidRuntimeSafety.publicFailureMessage("notification_permission_denied")
        } else {
            "Android просит разрешение, чтобы POKROV мог подключить это устройство."
        }
    }

    @Synchronized
    fun bindActiveProfile(profileDigest: String) {
        check(isRuntimeProfileDigest(profileDigest))
        activeProfileDigest = profileDigest
        coreEgressValidated = null
    }

    @Synchronized
    fun markRunning(message: String) {
        phase = AndroidRuntimePhase.RUNNING
        connectionPending = false
        lastStopReason = null
        if (runningSince.isNullOrBlank()) {
            runningSince = Instant.now().toString()
        }
        lastRunningMessage = message
        if (systemNotificationWarning) {
            lastFailureKind = "notification_permission_denied"
            lastMessage = AndroidRuntimeSafety.publicFailureMessage(
                "notification_permission_denied",
            )
        } else {
            lastFailureKind = null
            lastMessage = message
        }
    }

    @Synchronized
    fun markStopRequested(
        message: String = "Отключаем POKROV на этом устройстве...",
        stopReason: String = "user_requested",
    ) {
        activeProfileDigest = null
        connectionPending = false
        phase = when {
            stagedConfigPath != null -> AndroidRuntimePhase.CONFIG_STAGED
            environment != null -> AndroidRuntimePhase.INITIALIZED
            else -> AndroidRuntimePhase.ARTIFACT_MISSING
        }
        lastStopReason = stopReason
        runningSince = null
        vpnValidated = null
        coreEgressValidated = null
        invalidateTunnelTrafficSession()
        lastMessage = message
    }

    @Synchronized
    fun markStopped(
        message: String,
        stopReason: String = "service_stopped",
    ) {
        activeProfileDigest = null
        connectionPending = false
        phase = when {
            stagedConfigPath != null -> AndroidRuntimePhase.CONFIG_STAGED
            environment != null -> AndroidRuntimePhase.INITIALIZED
            else -> AndroidRuntimePhase.ARTIFACT_MISSING
        }
        lastStopReason = stopReason
        runningSince = null
        vpnValidated = null
        coreEgressValidated = null
        invalidateTunnelTrafficSession()
        if (message == "POKROV отключен на этом устройстве." && shouldPreserveFailureMessage()) {
            return
        }
        lastMessage = message
    }

    @Synchronized
    fun markStoppedAfterCoreEgressFailure(
        failureKind: String,
        message: String,
        stopReason: String,
    ) {
        activeProfileDigest = null
        connectionPending = false
        // This is a terminal dataplane failure, not an ordinary disconnect.
        // The profile must not remain staged for Quick Settings reuse.
        stagedConfigPath = null
        stagedProfileDigest = null
        stagedRequiresBoundConnect = false
        phase = when {
            environment != null -> AndroidRuntimePhase.INITIALIZED
            else -> AndroidRuntimePhase.ARTIFACT_MISSING
        }
        lastFailureKind = failureKind
        lastStopReason = stopReason
        runningSince = null
        vpnValidated = null
        coreEgressValidated = false
        invalidateTunnelTrafficSession()
        lastMessage = message
    }

    @Synchronized
    fun markFailure(message: String) {
        markFailure("runtime_failure", message)
    }

    @Synchronized
    fun markFailure(kind: String, message: String) {
        coreEgressValidated = null
        activeProfileDigest = null
        connectionPending = false
        runningSince = null
        invalidateTunnelTrafficSession()
        if (environment == null) {
            phase = AndroidRuntimePhase.ARTIFACT_MISSING
        } else if (stagedConfigPath != null) {
            phase = AndroidRuntimePhase.CONFIG_STAGED
        } else {
            phase = AndroidRuntimePhase.INITIALIZED
        }
        lastFailureKind = kind
        lastMessage = message
    }

    @Synchronized
    fun markDegraded(failureKind: String, message: String) {
        lastFailureKind = failureKind
        if (phase == AndroidRuntimePhase.RUNNING) {
            lastMessage = message
        }
    }

    @Synchronized
    fun markConnectionPending() {
        connectionPending = true
        if (phase != AndroidRuntimePhase.RUNNING && !systemNotificationWarning) {
            lastMessage = "POKROV готовит подключение на этом устройстве."
        }
    }

    @Synchronized
    fun markSystemNotificationWarning() {
        systemNotificationWarning = true
        lastFailureKind = "notification_permission_denied"
        lastMessage = AndroidRuntimeSafety.publicFailureMessage(
            "notification_permission_denied",
        )
    }

    @Synchronized
    fun clearSystemNotificationWarning() {
        if (!systemNotificationWarning) {
            return
        }
        systemNotificationWarning = false
        if (lastFailureKind == "notification_permission_denied") {
            lastFailureKind = null
        }
        if (phase == AndroidRuntimePhase.RUNNING && !lastRunningMessage.isNullOrBlank()) {
            lastMessage = lastRunningMessage!!
        }
    }

    @Synchronized
    fun recordFailureKind(kind: String) {
        lastFailureKind = kind
    }

    @Synchronized
    fun markDnsOperational() {
        if (isResolverFailureKind(lastFailureKind)) {
            lastFailureKind = null
        }
        if (dnsReady && phase == AndroidRuntimePhase.RUNNING && !lastRunningMessage.isNullOrBlank()) {
            lastMessage = lastRunningMessage!!
        }
    }

    @Synchronized
    fun updateDefaultNetwork(
        interfaceName: String?,
        interfaceIndex: Int?,
        dnsReady: Boolean,
    ) {
        defaultNetworkInterface = interfaceName
        defaultNetworkIndex = interfaceIndex
        this.dnsReady = dnsReady
        if (dnsReady && isDefaultNetworkFailureKind(lastFailureKind)) {
            lastFailureKind = null
        }
        if (dnsReady && phase == AndroidRuntimePhase.RUNNING && !lastRunningMessage.isNullOrBlank()) {
            lastMessage = lastRunningMessage!!
        }
    }

    @Synchronized
    fun markDnsTransportFailure(failureKind: String, message: String) {
        dnsReady = false
        lastFailureKind = failureKind
        if (phase == AndroidRuntimePhase.RUNNING) {
            lastMessage = message
        }
    }

    @Synchronized
    fun updateVpnValidation(validated: Boolean?) {
        vpnValidated = validated
        if (
            validated == true &&
                phase == AndroidRuntimePhase.RUNNING &&
                !lastRunningMessage.isNullOrBlank() &&
                lastFailureKind.isNullOrBlank()
        ) {
            lastMessage = lastRunningMessage!!
        }
    }

    @Synchronized
    fun updateCoreEgressValidation(validated: Boolean?) {
        coreEgressValidated = if (validated == true) {
            activeProfileDigest != null && activeProfileDigest == stagedProfileDigest
        } else validated
        if (validated == true && coreEgressValidated != true) {
            lastFailureKind = "profile_identity_mismatch"
            lastMessage = AndroidRuntimeSafety.publicFailureMessage("profile_identity_mismatch")
            return
        }
        if (
            validated == true &&
                phase == AndroidRuntimePhase.RUNNING &&
                !lastRunningMessage.isNullOrBlank() &&
                lastFailureKind.isNullOrBlank()
        ) {
            lastMessage = lastRunningMessage!!
        }
    }

    @Synchronized
    fun updateCoreEgressRequirement(required: Boolean) {
        coreEgressValidationRequired = required
        if (!required) {
            coreEgressValidated = null
        }
    }

    @Synchronized
    fun recordTunConfiguration(
        ipv4RouteCount: Int,
        ipv6RouteCount: Int,
        includePackageCount: Int,
        excludePackageCount: Int,
    ) {
        this.ipv4RouteCount = ipv4RouteCount
        this.ipv6RouteCount = ipv6RouteCount
        this.includePackageCount = includePackageCount
        this.excludePackageCount = excludePackageCount
    }

    @Synchronized
    fun beginTunnelTrafficSession(generation: Long) {
        tunnelTrafficGeneration = generation
        clearTunnelTrafficValues()
    }

    @Synchronized
    fun updateTunnelTraffic(
        generation: Long,
        snapshot: AndroidTunnelTrafficSnapshot,
    ) {
        if (generation != tunnelTrafficGeneration) {
            return
        }
        tunnelTrafficState = snapshot.state
        tunnelUplinkBps = snapshot.uplinkBps
        tunnelDownlinkBps = snapshot.downlinkBps
        tunnelUplinkTotalBytes = snapshot.uplinkTotalBytes
        tunnelDownlinkTotalBytes = snapshot.downlinkTotalBytes
    }

    @Synchronized
    fun endTunnelTrafficSession(generation: Long? = null) {
        if (generation != null && generation != tunnelTrafficGeneration) {
            return
        }
        tunnelTrafficGeneration += 1L
        clearTunnelTrafficValues()
    }

    private fun clearTunnelTrafficValues() {
        tunnelTrafficState = AndroidTunnelTrafficSampleState.UNAVAILABLE
        tunnelUplinkBps = null
        tunnelDownlinkBps = null
        tunnelUplinkTotalBytes = null
        tunnelDownlinkTotalBytes = null
    }

    private fun invalidateTunnelTrafficSession() {
        tunnelTrafficGeneration += 1L
        clearTunnelTrafficValues()
    }

    @Synchronized
    fun stagedConfigPath(): String? = stagedConfigPath

    @Synchronized
    fun isStagedProfileCurrent(profileDigest: String?): Boolean =
        profileDigest != null && stagedConfigPath != null && stagedProfileDigest == profileDigest

    @Synchronized
    fun liveStats(): Map<String, Any?> {
        val trafficAvailable = phase == AndroidRuntimePhase.RUNNING &&
            tunnelTrafficState != AndroidTunnelTrafficSampleState.UNAVAILABLE
        return mapOf(
            "available" to trafficAvailable,
            "counterState" to tunnelTrafficState.wireValue,
            "uplinkBps" to tunnelUplinkBps,
            "downlinkBps" to tunnelDownlinkBps,
            "uplinkTotalBytes" to tunnelUplinkTotalBytes,
            "downlinkTotalBytes" to tunnelDownlinkTotalBytes,
            "latencyMs" to null,
            "since" to runningSince,
            "serverCode" to "",
            "serverCountry" to "",
            "protocol" to if (stagedConfigPath.isNullOrBlank()) "" else "sing-box",
            "coreOperationalEvents" to AndroidCoreOperationalEvents.snapshot(),
        )
    }

    @Synchronized
    fun snapshotForBoundConnect(expectedCore: String, expectedProfile: String,
        startCompleted: Boolean): Map<String, Any?>? {
        if (coreModuleSha256 != expectedCore || (!startCompleted && stagedProfileDigest != expectedProfile)) return null
        val value = snapshot()
        if (phase != AndroidRuntimePhase.RUNNING) return value
        if (!startCompleted) {
            // TUN publication can precede Core Start returning. Do not let that
            // intermediate state, or an older running instance, finish this wait.
            val diagnostics = value.getValue("hostDiagnostics") as Map<*, *>
            return value + mapOf("connection_pending" to true, "effectiveProfileDigest" to null,
                "hostDiagnostics" to (diagnostics + mapOf("connection_pending" to true)))
        }
        if (activeProfileDigest != expectedProfile) return null
        // This is the identity of a running owned instance, not the legacy
        // egress oracle. Health fields keep their actual, possibly unknown state.
        return value + mapOf("effectiveProfileDigest" to activeProfileDigest)
    }

    @Synchronized
    fun snapshot(): Map<String, Any?> {
        val resolved = environment
        val canInitialize = resolved != null
        val canConnect = resolved != null && stagedConfigPath != null && !stagedRequiresBoundConnect
        val hostHealth = currentHostHealth()
        val dnsState = currentDnsState()
        val uplinkState = currentUplinkState()
        val diagnosticsSummary = currentDiagnosticsSummary(
            hostHealth = hostHealth,
            dnsState = dnsState,
            uplinkState = uplinkState,
        )
        val hostDiagnostics = mapOf(
            "health" to hostHealth,
            "dnsStatus" to dnsState,
            "uplinkStatus" to uplinkState,
            "summary" to diagnosticsSummary,
            "default_network_interface" to defaultNetworkInterface,
            "default_network_index" to defaultNetworkIndex,
            "dns_ready" to dnsReady,
            "vpn_validated" to vpnValidated,
            "core_egress_validated" to coreEgressValidated,
            "core_egress_validation_required" to coreEgressValidationRequired,
            "last_failure_kind" to lastFailureKind,
            "last_stop_reason" to lastStopReason,
            "safe_protocol_diagnostic_code" to awgSafeDiagnosticCode,
            "safe_protocol_diagnostic_occurrence" to awgSafeDiagnosticOccurrence,
            "ipv4_route_count" to ipv4RouteCount,
            "ipv6_route_count" to ipv6RouteCount,
            "include_package_count" to includePackageCount,
            "exclude_package_count" to excludePackageCount,
            "system_notification_warning" to systemNotificationWarning,
            "connection_pending" to connectionPending,
        )
        return mapOf(
            "phase" to phase.wireValue,
            "transportProofPending" to AndroidConnectRequestOwner.requiresTransportProof(),
            "transportLeaseActive" to AndroidConnectRequestOwner.hasPromotedTransportLease(),
            "routingCatalogWindowVersion" to routingCatalogWindowVersion,
            "smartAccessLeaseVersion" to smartAccessLeaseVersion,
            "smartAccessRuntimeControlVersion" to smartAccessRuntimeControlVersion,
            "routingCatalogControlVersion" to routingCatalogControlVersion,
            "transportCapabilitiesJson" to transportCapabilitiesJson,
            "coreModuleSha256" to coreModuleSha256,
            "artifactDirectory" to resolved?.artifactDirectory,
            "coreBinaryPath" to resolved?.coreBinaryPath,
            "helperBinaryPath" to null,
            "stagedConfigPath" to stagedConfigPath,
            "stagedProfileDigest" to stagedProfileDigest,
            "effectiveProfileDigest" to activeProfileDigest?.takeIf {
                phase == AndroidRuntimePhase.RUNNING && coreEgressValidated == true
            },
            "profileIdentityOrigin" to "android_private_stage_request_sha256",
            "supportsLiveConnect" to true,
            "canInitialize" to canInitialize,
            "canConnect" to canConnect,
            "hostHealth" to hostHealth,
            "dnsState" to dnsState,
            "uplinkState" to uplinkState,
            "hostDiagnosticsSummary" to diagnosticsSummary,
            "default_network_interface" to defaultNetworkInterface,
            "default_network_index" to defaultNetworkIndex,
            "dns_ready" to dnsReady,
            "vpn_validated" to vpnValidated,
            "core_egress_validated" to coreEgressValidated,
            "last_failure_kind" to lastFailureKind,
            "last_stop_reason" to lastStopReason,
            "safe_protocol_diagnostic_code" to awgSafeDiagnosticCode,
            "safe_protocol_diagnostic_occurrence" to awgSafeDiagnosticOccurrence,
            "ipv4_route_count" to ipv4RouteCount,
            "ipv6_route_count" to ipv6RouteCount,
            "include_package_count" to includePackageCount,
            "exclude_package_count" to excludePackageCount,
            "system_notification_warning" to systemNotificationWarning,
            "connection_pending" to connectionPending,
            "hostDiagnostics" to hostDiagnostics,
            "message" to lastMessage,
        )
    }

    @Synchronized
    fun reconcileActiveRuntime(
        tunEstablished: Boolean,
        runningMessage: String?,
    ) {
        if (!tunEstablished) {
            if (phase == AndroidRuntimePhase.RUNNING) {
                markStopped(
                    message = "POKROV отключен на этом устройстве.",
                    stopReason = "service_destroyed",
                )
            }
            return
        }
        phase = AndroidRuntimePhase.RUNNING
        connectionPending = false
        lastStopReason = null
        val resolvedMessage = when {
            !runningMessage.isNullOrBlank() -> runningMessage
            !lastRunningMessage.isNullOrBlank() -> lastRunningMessage!!
            else -> "POKROV включен на этом устройстве."
        }
        lastRunningMessage = resolvedMessage
        if (systemNotificationWarning) {
            lastFailureKind = "notification_permission_denied"
            lastMessage = AndroidRuntimeSafety.publicFailureMessage(
                "notification_permission_denied",
            )
            return
        }
        val normalizedMessage = lastMessage.lowercase()
        if (
            normalizedMessage.contains("staged") ||
                normalizedMessage.contains("setup step") ||
                normalizedMessage.contains("permission requested") ||
                normalizedMessage.contains("ready to connect") ||
                normalizedMessage.contains("not checked") ||
                normalizedMessage.contains("подготовил профиль") ||
                normalizedMessage.contains("подготовил устройство") ||
                normalizedMessage.contains("просит разрешение") ||
                normalizedMessage.contains("готов")
        ) {
            lastMessage = resolvedMessage
        }
    }

    private fun currentHostHealth(): String {
        if (phase != AndroidRuntimePhase.RUNNING) {
            return "unknown"
        }
        val dnsState = currentDnsState()
        val uplinkState = currentUplinkState()
        return when {
            dnsState == "degraded" -> "degraded"
            uplinkState == "degraded" -> "degraded"
            !lastFailureKind.isNullOrBlank() -> "degraded"
            coreEgressValidationRequired && coreEgressValidated == false -> "degraded"
            (!coreEgressValidationRequired || coreEgressValidated == true) &&
                dnsState == "healthy" && uplinkState == "healthy" ->
                "healthy"
            vpnValidated == false -> "degraded"
            else -> "unknown"
        }
    }

    private fun currentDnsState(): String {
        if (phase != AndroidRuntimePhase.RUNNING) {
            return "unknown"
        }
        return when {
            isDnsFailureKind(lastFailureKind) -> "degraded"
            dnsReady -> "healthy"
            else -> "degraded"
        }
    }

    private fun currentUplinkState(): String {
        if (phase != AndroidRuntimePhase.RUNNING) {
            return "unknown"
        }
        return when {
            isDefaultNetworkFailureKind(lastFailureKind) -> "degraded"
            !defaultNetworkInterface.isNullOrBlank() &&
                defaultNetworkIndex != null &&
                defaultNetworkIndex!! >= 0 -> "healthy"
            else -> "degraded"
        }
    }

    private fun currentDiagnosticsSummary(
        hostHealth: String,
        dnsState: String,
        uplinkState: String,
    ): String? {
        if (phase != AndroidRuntimePhase.RUNNING) {
            return null
        }

        val details = mutableListOf<String>()
        when {
            !defaultNetworkInterface.isNullOrBlank() && defaultNetworkIndex != null ->
                details += "Сеть готова"
            !defaultNetworkInterface.isNullOrBlank() ->
                details += "Сеть определяется"
            uplinkState == "degraded" ->
                details += "Сеть не определена"
        }

        details += if (dnsReady) "DNS готов" else "DNS ждет"
        if (vpnValidated == false) details += when (vpnValidated) {
            true -> "Интернет подтвержден"
            false -> "Интернет не подтвержден"
            null -> "Интернет проверяется"
        }
        if (coreEgressValidationRequired && coreEgressValidated == false) {
            details += "Выход в интернет не подтвержден"
        }
        details += "Правила v4=$ipv4RouteCount v6=$ipv6RouteCount"

        if (includePackageCount > 0 || excludePackageCount > 0) {
            details += "Приложения include=$includePackageCount exclude=$excludePackageCount"
        }
        if (!lastFailureKind.isNullOrBlank()) {
            details += "Последняя ошибка $lastFailureKind"
        }

        if (details.isEmpty()) {
            return when (hostHealth) {
                "healthy" -> "Диагностика Android без замечаний."
                "degraded" -> if (dnsState == "degraded" || uplinkState == "degraded") {
                    "Диагностика Android сообщает предупреждение."
                } else {
                    "Android завершает проверку после подключения."
                }
                else -> null
            }
        }
        return details.joinToString(" | ")
    }

    private fun isResolverFailureKind(value: String?): Boolean {
        val normalized = value?.lowercase() ?: return false
        return normalized.startsWith("resolver_") || normalized.startsWith("dns_")
    }

    private fun isDnsFailureKind(value: String?): Boolean {
        val normalized = value?.lowercase() ?: return false
        return normalized.startsWith("resolver_") ||
            normalized.startsWith("dns_") ||
            normalized.startsWith("default_network_")
    }

    private fun isDefaultNetworkFailureKind(value: String?): Boolean {
        val normalized = value?.lowercase() ?: return false
        return normalized.startsWith("default_network_")
    }

    private fun shouldPreserveFailureMessage(): Boolean {
        val normalized = lastMessage.lowercase()
        return normalized.contains("failed") ||
            normalized.contains("denied") ||
            normalized.contains("missing") ||
            normalized.contains("invalid") ||
            normalized.contains("error")
    }
}
