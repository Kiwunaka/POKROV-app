package space.pokrov.pokrov_android_shell

import android.content.Context
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.mobile.Mobile
import java.io.File

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
    private var environment: AndroidRuntimeEnvironment? = null
    private var phase: AndroidRuntimePhase = AndroidRuntimePhase.ARTIFACT_MISSING
    private var stagedConfigPath: String? = null
    private var lastMessage = "POKROV has not checked this device yet."
    private var lastRunningMessage: String? = null
    private var defaultNetworkInterface: String? = null
    private var defaultNetworkIndex: Int? = null
    private var dnsReady: Boolean = false
    private var lastFailureKind: String? = null
    private var lastStopReason: String? = null
    private var ipv4RouteCount: Int = 0
    private var ipv6RouteCount: Int = 0
    private var includePackageCount: Int = 0
    private var excludePackageCount: Int = 0

    @Synchronized
    fun resolveEnvironment(context: Context): AndroidRuntimeEnvironment? {
        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir ?: return null
        val libbox = File(nativeLibraryDir, "libbox.so")
        if (!libbox.exists()) {
            environment = null
            phase = AndroidRuntimePhase.ARTIFACT_MISSING
            stagedConfigPath = null
            lastMessage = "This Android build is missing the connection runtime."
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
            artifactDirectory = nativeLibraryDir,
            coreBinaryPath = libbox.absolutePath,
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
        val resolved = resolveEnvironment(context) ?: return false
        return try {
            Mobile.touch()
            Libbox.touch()
            Libbox.setup(
                resolved.baseDirectory.absolutePath,
                resolved.workingDirectory.absolutePath,
                resolved.tempDirectory.absolutePath,
                false,
            )
            Mobile.setup(
                resolved.baseDirectory.absolutePath,
                resolved.workingDirectory.absolutePath,
                resolved.tempDirectory.absolutePath,
                false,
            )
            phase = if (phase == AndroidRuntimePhase.RUNNING) {
                AndroidRuntimePhase.RUNNING
            } else {
                AndroidRuntimePhase.INITIALIZED
            }
            lastMessage = "POKROV finished the device setup step."
            true
        } catch (error: Throwable) {
            phase = AndroidRuntimePhase.ARTIFACT_READY
            lastMessage = "POKROV could not finish the device setup step: ${error.message ?: error.javaClass.simpleName}"
            false
        }
    }

    @Synchronized
    fun markProfileStaged(path: String) {
        stagedConfigPath = path
        phase = AndroidRuntimePhase.CONFIG_STAGED
        lastFailureKind = null
        lastStopReason = null
        lastMessage = "POKROV finished preparing this device."
    }

    @Synchronized
    fun markPermissionRequested() {
        lastMessage = "Android is asking for permission so POKROV can protect this device."
    }

    @Synchronized
    fun markRunning(message: String) {
        phase = AndroidRuntimePhase.RUNNING
        lastFailureKind = null
        lastStopReason = null
        lastRunningMessage = message
        lastMessage = message
    }

    @Synchronized
    fun markStopRequested(
        message: String = "Disconnecting POKROV on this device...",
        stopReason: String = "user_requested",
    ) {
        phase = when {
            stagedConfigPath != null -> AndroidRuntimePhase.CONFIG_STAGED
            environment != null -> AndroidRuntimePhase.INITIALIZED
            else -> AndroidRuntimePhase.ARTIFACT_MISSING
        }
        lastStopReason = stopReason
        lastMessage = message
    }

    @Synchronized
    fun markStopped(
        message: String,
        stopReason: String = "service_stopped",
    ) {
        phase = when {
            stagedConfigPath != null -> AndroidRuntimePhase.CONFIG_STAGED
            environment != null -> AndroidRuntimePhase.INITIALIZED
            else -> AndroidRuntimePhase.ARTIFACT_MISSING
        }
        lastStopReason = stopReason
        if (message == "POKROV turned off on this device." && shouldPreserveFailureMessage()) {
            return
        }
        lastMessage = message
    }

    @Synchronized
    fun markFailure(message: String) {
        markFailure("runtime_failure", message)
    }

    @Synchronized
    fun markFailure(kind: String, message: String) {
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
    fun stagedConfigPath(): String? = stagedConfigPath

    @Synchronized
    fun snapshot(): Map<String, Any?> {
        val resolved = environment
        val canInitialize = resolved != null
        val canConnect = resolved != null && stagedConfigPath != null
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
            "last_failure_kind" to lastFailureKind,
            "last_stop_reason" to lastStopReason,
            "ipv4_route_count" to ipv4RouteCount,
            "ipv6_route_count" to ipv6RouteCount,
            "include_package_count" to includePackageCount,
            "exclude_package_count" to excludePackageCount,
        )
        return mapOf(
            "phase" to phase.wireValue,
            "artifactDirectory" to resolved?.artifactDirectory,
            "coreBinaryPath" to resolved?.coreBinaryPath,
            "helperBinaryPath" to null,
            "stagedConfigPath" to stagedConfigPath,
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
            "last_failure_kind" to lastFailureKind,
            "last_stop_reason" to lastStopReason,
            "ipv4_route_count" to ipv4RouteCount,
            "ipv6_route_count" to ipv6RouteCount,
            "include_package_count" to includePackageCount,
            "exclude_package_count" to excludePackageCount,
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
            return
        }
        phase = AndroidRuntimePhase.RUNNING
        lastStopReason = null
        val resolvedMessage = when {
            !runningMessage.isNullOrBlank() -> runningMessage
            !lastRunningMessage.isNullOrBlank() -> lastRunningMessage!!
            else -> "POKROV is on for this device."
        }
        lastRunningMessage = resolvedMessage
        val normalizedMessage = lastMessage.lowercase()
        if (
            normalizedMessage.contains("staged") ||
                normalizedMessage.contains("setup step") ||
                normalizedMessage.contains("permission requested") ||
                normalizedMessage.contains("ready to connect") ||
                normalizedMessage.contains("not checked")
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
            dnsState == "healthy" && uplinkState == "healthy" -> "healthy"
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
        val interfaceName = defaultNetworkInterface?.takeIf { it.isNotBlank() }
        when {
            interfaceName != null && defaultNetworkIndex != null ->
                details += "Uplink $interfaceName (#$defaultNetworkIndex)"
            interfaceName != null ->
                details += "Uplink $interfaceName"
            uplinkState == "degraded" ->
                details += "Uplink unresolved"
        }

        details += if (dnsReady) "DNS ready" else "DNS waiting"
        details += "Routes v4=$ipv4RouteCount v6=$ipv6RouteCount"

        if (includePackageCount > 0 || excludePackageCount > 0) {
            details += "Packages include=$includePackageCount exclude=$excludePackageCount"
        }
        if (!lastFailureKind.isNullOrBlank()) {
            details += "Last failure $lastFailureKind"
        }

        if (details.isEmpty()) {
            return when (hostHealth) {
                "healthy" -> "Android device checks look healthy."
                "degraded" -> if (dnsState == "degraded" || uplinkState == "degraded") {
                    "Android device checks report warnings."
                } else {
                    "Android device checks are still settling after connect."
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
