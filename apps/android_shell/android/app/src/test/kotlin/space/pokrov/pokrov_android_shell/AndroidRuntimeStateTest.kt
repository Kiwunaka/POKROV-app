package space.pokrov.pokrov_android_shell

import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AndroidRuntimeStateTest {
    @Before
    fun setUp() {
        resetState()
    }

    @After
    fun tearDown() {
        resetState()
    }

    @Test
    fun packagedRuntimeLocator_findsCoreInsideApk_whenNativeLibsAreNotExtracted() {
        val apk = File.createTempFile("pokrov-runtime", ".apk")
        try {
            ZipOutputStream(apk.outputStream()).use { zip ->
                zip.putNextEntry(ZipEntry("lib/arm64-v8a/libpokrov-core.so"))
                zip.write(byteArrayOf(1))
                zip.closeEntry()
            }

            val resolved = AndroidPackagedRuntimeLocator.resolve(
                nativeLibraryDir = File(apk.parentFile, "empty-native-libs").absolutePath,
                apkPaths = listOf(apk.absolutePath),
                supportedAbis = listOf("arm64-v8a"),
            )

            assertEquals(apk.absolutePath, resolved?.artifactDirectory)
            assertEquals(
                "${apk.absolutePath}!/lib/arm64-v8a/libpokrov-core.so",
                resolved?.coreBinaryPath,
            )
        } finally {
            apk.delete()
        }
    }

    @Test
    fun packagedRuntimeLocator_prefersExtractedCore_whenAvailable() {
        val nativeDirectory = Files.createTempDirectory("pokrov-native-").toFile()
        try {
            val extractedCore = File(nativeDirectory, "libpokrov-core.so")
                .apply { writeBytes(byteArrayOf(1)) }

            val resolved = AndroidPackagedRuntimeLocator.resolve(
                nativeLibraryDir = nativeDirectory.absolutePath,
                apkPaths = listOf(File(nativeDirectory, "missing.apk").absolutePath),
                supportedAbis = listOf("arm64-v8a"),
            )

            assertEquals(nativeDirectory.absolutePath, resolved?.artifactDirectory)
            assertEquals(extractedCore.absolutePath, resolved?.coreBinaryPath)
        } finally {
            nativeDirectory.deleteRecursively()
        }
    }

    @Test
    fun safeAwgDiagnosticIsSnapshotOnlyAndClearsForTheNextAttempt() {
        AndroidRuntimeState.recordAwgSafeDiagnostic(
            AndroidAwgSafeDiagnostic("handshake_retry", 3),
        )
        AndroidRuntimeState.recordAwgSafeDiagnostic(
            AndroidAwgSafeDiagnostic("egress_probe_tls_certificate", 1),
        )
        AndroidRuntimeState.recordAwgSafeDiagnostic(
            AndroidAwgSafeDiagnostic("receive_handshake_response", 4),
        )

        var snapshot = AndroidRuntimeState.snapshot()
        assertEquals("egress_probe_tls_certificate", snapshot["safe_protocol_diagnostic_code"])
        assertEquals(1, snapshot["safe_protocol_diagnostic_occurrence"])
        assertEquals("unknown", snapshot["hostHealth"])
        assertNull(snapshot["last_failure_kind"])

        AndroidRuntimeState.markConnectionRequested()
        snapshot = AndroidRuntimeState.snapshot()
        assertNull(snapshot["safe_protocol_diagnostic_code"])
        assertNull(snapshot["safe_protocol_diagnostic_occurrence"])
    }

    @Test
    fun markStopped_preservesSpecificFailureMessage_afterFailedStart() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.CONFIG_STAGED)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-seed-runtime.json")
        setPrivateField("lastMessage", "POKROV подготовил профиль для этого устройства.")

        AndroidRuntimeState.markFailure(
            kind = "runtime_service_start_failed",
            message = "POKROV не смог подключить устройство: invalid inbound mix.",
        )
        AndroidRuntimeState.markStopped(
            message = "POKROV отключен на этом устройстве.",
            stopReason = "service_destroyed",
        )

        val snapshot = AndroidRuntimeState.snapshot()
        assertEquals("configStaged", snapshot["phase"])
        assertEquals(
            "POKROV не смог подключить устройство: invalid inbound mix.",
            snapshot["message"],
        )
        assertEquals("runtime_service_start_failed", snapshot["last_failure_kind"])
        assertEquals("service_destroyed", snapshot["last_stop_reason"])
    }

    @Test
    fun snapshot_includesStructuredDiagnostics_afterRunning() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.INITIALIZED)

        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-runtime.json")
        AndroidRuntimeState.recordTunConfiguration(
            ipv4RouteCount = 3,
            ipv6RouteCount = 2,
            includePackageCount = 4,
            excludePackageCount = 1,
        )
        AndroidRuntimeState.updateDefaultNetwork(
            interfaceName = "wlan0",
            interfaceIndex = 42,
            dnsReady = true,
        )
        AndroidRuntimeState.markRunning("POKROV включен на этом устройстве.")

        AndroidRuntimeState.updateVpnValidation(true)
        setPrivateField("stagedProfileDigest", "a".repeat(64))
        AndroidRuntimeState.bindActiveProfile("a".repeat(64))
        AndroidRuntimeState.updateCoreEgressValidation(true)
        val snapshot = AndroidRuntimeState.snapshot()
        @Suppress("UNCHECKED_CAST")
        val hostDiagnostics = snapshot["hostDiagnostics"] as Map<String, Any?>

        assertEquals("running", snapshot["phase"])
        assertEquals("healthy", snapshot["hostHealth"])
        assertEquals("healthy", snapshot["dnsState"])
        assertEquals("healthy", snapshot["uplinkState"])
        assertEquals(
            "Сеть готова | DNS готов | Правила v4=3 v6=2 | Приложения include=4 exclude=1",
            snapshot["hostDiagnosticsSummary"],
        )
        assertEquals("wlan0", snapshot["default_network_interface"])
        assertEquals(42, snapshot["default_network_index"])
        assertEquals(true, snapshot["dns_ready"])
        assertEquals(true, snapshot["vpn_validated"])
        assertEquals(true, snapshot["core_egress_validated"])
        assertEquals(3, snapshot["ipv4_route_count"])
        assertEquals(2, snapshot["ipv6_route_count"])
        assertEquals(4, snapshot["include_package_count"])
        assertEquals(1, snapshot["exclude_package_count"])
        assertNull(snapshot["last_failure_kind"])
        assertNull(snapshot["last_stop_reason"])
        assertEquals("healthy", hostDiagnostics["health"])
        assertEquals("healthy", hostDiagnostics["dnsStatus"])
        assertEquals("healthy", hostDiagnostics["uplinkStatus"])
    }

    @Test
    fun snapshot_tracksFailureKindAndStopReason_afterRevoke() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.INITIALIZED)
        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markRunning("Android tun established.")
        AndroidRuntimeState.markDegraded(
            failureKind = "default_network_unavailable",
            message = "Android подключил POKROV, но обычная сеть устройства еще не готова для DNS.",
        )
        AndroidRuntimeState.markStopped(
            message = "Android отозвал разрешение на подключение POKROV.",
            stopReason = "vpn_permission_revoked",
        )

        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals("configStaged", snapshot["phase"])
        assertEquals("default_network_unavailable", snapshot["last_failure_kind"])
        assertEquals("vpn_permission_revoked", snapshot["last_stop_reason"])
        assertEquals(
            "Android отозвал разрешение на подключение POKROV.",
            snapshot["message"],
        )
        assertFalse(snapshot["dns_ready"] as Boolean)
    }

    @Test
    fun markDnsOperational_clearsResolverFailureAfterHealthyRecovery() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        setPrivateField("lastRunningMessage", "Android tun established.")
        setPrivateField("lastMessage", "Android tun is established, but local DNS resolution is degraded.")
        setPrivateField("lastFailureKind", "resolver_dns_exception")
        setPrivateField("dnsReady", true)

        AndroidRuntimeState.markDnsOperational()

        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals(null, snapshot["last_failure_kind"])
        assertEquals("healthy", snapshot["dnsState"])
        assertEquals("Android tun established.", snapshot["message"])
    }

    @Test
    fun coreEgressProbeOwnsEndToEndHealthWithoutUsingRequestLogs() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        AndroidRuntimeState.updateDefaultNetwork("wlan0", 42, dnsReady = true)

        AndroidRuntimeState.updateVpnValidation(true)
        assertEquals("unknown", AndroidRuntimeState.snapshot()["hostHealth"])

        AndroidRuntimeState.updateCoreEgressValidation(false)
        assertEquals("degraded", AndroidRuntimeState.snapshot()["hostHealth"])

        setPrivateField("stagedProfileDigest", "a".repeat(64))
        AndroidRuntimeState.bindActiveProfile("a".repeat(64))
        AndroidRuntimeState.updateCoreEgressValidation(true)
        val snapshot = AndroidRuntimeState.snapshot()
        assertEquals("healthy", snapshot["hostHealth"])
        assertEquals(true, snapshot["vpn_validated"])
    }

    @Test
    fun coreEgressFailure_stopsRuntimeAndPreservesSafeFailureSnapshot() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markStoppedAfterCoreEgressFailure(
            failureKind = "core_egress_probe_failed",
            message = AndroidRuntimeSafety.publicFailureMessage("core_egress_probe_failed"),
            stopReason = "core_egress_probe_failed",
        )

        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals("initialized", snapshot["phase"])
        assertEquals(null, snapshot["stagedConfigPath"])
        assertEquals(false, AndroidRuntimeState.liveStats()["available"])
        assertEquals(false, snapshot["core_egress_validated"])
        assertEquals("core_egress_probe_failed", snapshot["last_failure_kind"])
        assertEquals("core_egress_probe_failed", snapshot["last_stop_reason"])
        assertEquals(
            "POKROV не подтвердил защищенное подключение.",
            snapshot["message"],
        )
    }

    @Test
    fun coreEgressFailure_isNotPromotedBackToRunningAfterTunClosed() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markStoppedAfterCoreEgressFailure(
            failureKind = "core_egress_probe_failed",
            message = AndroidRuntimeSafety.publicFailureMessage("core_egress_probe_failed"),
            stopReason = "core_egress_probe_failed",
        )

        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = false,
            runningMessage = "POKROV подключен на этом устройстве.",
        )
        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals("initialized", snapshot["phase"])
        assertEquals(null, snapshot["stagedConfigPath"])
        assertEquals(false, snapshot["core_egress_validated"])
        assertEquals("core_egress_probe_failed", snapshot["last_failure_kind"])
        assertEquals("core_egress_probe_failed", snapshot["last_stop_reason"])
    }

    @Test
    fun coreEgressFailure_clearsStagedReuseSoQuickSettingsCannotStart() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-runtime.json")

        AndroidRuntimeState.markStoppedAfterCoreEgressFailure(
            failureKind = "core_egress_probe_failed",
            message = AndroidRuntimeSafety.publicFailureMessage("core_egress_probe_failed"),
            stopReason = "core_egress_probe_failed",
        )

        val snapshot = AndroidRuntimeState.snapshot()
        assertEquals(null, snapshot["stagedConfigPath"])
        assertEquals(
            QuickTileAction.OPEN_APP,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = snapshot["stagedConfigPath"] != null,
                quickSettingsEligible = false,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun reconcileActiveRuntime_promotesStagedSnapshotBackToRunning() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.CONFIG_STAGED)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-runtime.json")
        setPrivateField("lastMessage", "POKROV подготовил профиль для этого устройства.")
        setPrivateField("lastRunningMessage", "POKROV включен на этом устройстве.")
        setPrivateField("lastStopReason", "service_destroyed")

        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = true,
            runningMessage = "POKROV включен на этом устройстве.",
        )

        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals("running", snapshot["phase"])
        assertEquals("POKROV включен на этом устройстве.", snapshot["message"])
        assertEquals(null, snapshot["last_stop_reason"])
    }

    @Test
    fun reconcileActiveRuntime_demotesStaleRunningSnapshotWithoutTun() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-runtime.json")
        setPrivateField("runningSince", "2026-08-28T12:00:00Z")
        setPrivateField("vpnValidated", true)
        setPrivateField("coreEgressValidated", true)

        AndroidRuntimeState.reconcileActiveRuntime(
            tunEstablished = false,
            runningMessage = "POKROV включен на этом устройстве.",
        )
        val snapshot = AndroidRuntimeState.snapshot()

        assertEquals("configStaged", snapshot["phase"])
        assertEquals("service_destroyed", snapshot["last_stop_reason"])
        assertEquals(null, snapshot["core_egress_validated"])
        assertEquals("POKROV отключен на этом устройстве.", snapshot["message"])
        assertEquals(false, AndroidRuntimeState.liveStats()["available"])
    }

    @Test
    fun pendingConnection_remainsObservableUntilRuntimeResolvesIt() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markConnectionRequested()

        assertTrue(AndroidRuntimeState.snapshot()["connection_pending"] as Boolean)

        AndroidRuntimeState.markStopRequested()
        assertFalse(AndroidRuntimeState.snapshot()["connection_pending"] as Boolean)

        AndroidRuntimeState.markConnectionRequested()
        AndroidRuntimeState.markRunning("POKROV включен на этом устройстве.")
        assertFalse(AndroidRuntimeState.snapshot()["connection_pending"] as Boolean)
    }

    @Test
    fun initializationFailure_clearsPendingConnectionState() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.CONFIG_STAGED)
        setPrivateField("stagedConfigPath", "/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markConnectionRequested()

        AndroidRuntimeState.markFailure(
            kind = "runtime_initialization_failed",
            message = AndroidRuntimeSafety.publicFailureMessage("runtime_initialization_failed"),
        )

        val snapshot = AndroidRuntimeState.snapshot()
        assertFalse(snapshot["connection_pending"] as Boolean)
        assertEquals("configStaged", snapshot["phase"])
        assertEquals("runtime_initialization_failed", snapshot["last_failure_kind"])
    }

    @Test
    fun dnsTransportFailure_marksRunningSnapshotDegradedBeforeFailClose() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        AndroidRuntimeState.updateDefaultNetwork("wlan0", 42, dnsReady = true)
        AndroidRuntimeState.updateVpnValidation(true)
        setPrivateField("stagedProfileDigest", "a".repeat(64))
        AndroidRuntimeState.bindActiveProfile("a".repeat(64))
        AndroidRuntimeState.updateCoreEgressValidation(true)

        AndroidRuntimeState.markDnsTransportFailure(
            failureKind = AndroidResolverPolicy.TIMEOUT,
            message = AndroidRuntimeSafety.publicFailureMessage(AndroidResolverPolicy.TIMEOUT),
        )

        val snapshot = AndroidRuntimeState.snapshot()
        assertEquals("degraded", snapshot["dnsState"])
        assertEquals("degraded", snapshot["hostHealth"])
        assertFalse(snapshot["dns_ready"] as Boolean)
        assertEquals(AndroidResolverPolicy.TIMEOUT, snapshot["last_failure_kind"])
    }

    @Test
    fun invalidatedProfile_keepsRunningTunnelStoppable_butLeavesNoRestartProfile() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-runtime.json")
        AndroidRuntimeState.markRunning("POKROV включен на этом устройстве.")

        AndroidRuntimeState.invalidateStagedProfile()

        var snapshot = AndroidRuntimeState.snapshot()
        assertEquals("running", snapshot["phase"])
        assertEquals(null, snapshot["stagedConfigPath"])
        AndroidRuntimeState.markStopRequested(stopReason = "quick_settings")

        snapshot = AndroidRuntimeState.snapshot()
        assertEquals("initialized", snapshot["phase"])
        assertEquals(null, snapshot["stagedConfigPath"])
        assertEquals(false, snapshot["canConnect"])

        AndroidRuntimeState.markProfileStaged("/tmp/pokrov-fresh-runtime.json")
        snapshot = AndroidRuntimeState.snapshot()
        assertEquals("configStaged", snapshot["phase"])
        assertEquals("/tmp/pokrov-fresh-runtime.json", snapshot["stagedConfigPath"])
        assertEquals(true, snapshot["canConnect"])
        assertEquals(
            QuickTileAction.START,
            resolveQuickTileAction(
                isRunning = false,
                hasStagedProfile = true,
                quickSettingsEligible = true,
                vpnPermissionRequired = false,
            ),
        )
    }

    @Test
    fun notificationPermissionWarning_persistsAfterRunningUntilPermissionIsGranted() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.CONFIG_STAGED)

        AndroidRuntimeState.markSystemNotificationWarning()
        AndroidRuntimeState.markRunning("POKROV подключен на этом устройстве.")

        var snapshot = AndroidRuntimeState.snapshot()
        assertEquals("notification_permission_denied", snapshot["last_failure_kind"])
        assertEquals(
            "Системное уведомление POKROV скрыто в настройках Android.",
            snapshot["message"],
        )

        AndroidRuntimeState.clearSystemNotificationWarning()
        snapshot = AndroidRuntimeState.snapshot()
        assertNull(snapshot["last_failure_kind"])
        assertEquals("POKROV подключен на этом устройстве.", snapshot["message"])
    }

    @Test
    fun tunnelTrafficStats_areSessionScopedAndRejectLateGenerations() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libpokrov-core.so",
                baseDirectory = File("build/test/base"),
                workingDirectory = File("build/test/working"),
                tempDirectory = File("build/test/temp"),
                configDirectory = File("build/test/config"),
            ),
        )
        setPrivateField("phase", AndroidRuntimePhase.RUNNING)
        AndroidRuntimeState.beginTunnelTrafficSession(10L)
        AndroidRuntimeState.updateTunnelTraffic(
            10L,
            AndroidTunnelTrafficSnapshot(
                state = AndroidTunnelTrafficSampleState.AVAILABLE,
                uplinkBps = 1_024L,
                downlinkBps = 2_048L,
                uplinkTotalBytes = 4_096L,
                downlinkTotalBytes = 8_192L,
            ),
        )

        var stats = AndroidRuntimeState.liveStats()
        assertEquals(true, stats["available"])
        assertEquals("available", stats["counterState"])
        assertEquals(1_024L, stats["uplinkBps"])
        assertEquals(8_192L, stats["downlinkTotalBytes"])

        AndroidRuntimeState.updateTunnelTraffic(
            9L,
            AndroidTunnelTrafficSnapshot(
                state = AndroidTunnelTrafficSampleState.AVAILABLE,
                uplinkBps = 99_999L,
                downlinkBps = 99_999L,
            ),
        )
        AndroidRuntimeState.endTunnelTrafficSession(9L)
        stats = AndroidRuntimeState.liveStats()
        assertEquals(1_024L, stats["uplinkBps"])

        AndroidRuntimeState.markStopped(stopReason = "test", message = "stopped")
        stats = AndroidRuntimeState.liveStats()
        assertEquals(false, stats["available"])
        assertEquals("unavailable", stats["counterState"])
        assertNull(stats["uplinkBps"])
        assertNull(stats["downlinkTotalBytes"])
    }

    @Test
    fun effectiveIdentityBelongsToTheActiveProfileAndClearsAfterStop() {
        val first = "a".repeat(64)
        val second = "b".repeat(64)
        AndroidRuntimeState.markProfileStaged("/synthetic/profile.json", profileDigest = first)
        AndroidRuntimeState.bindActiveProfile(first)
        AndroidRuntimeState.markRunning("synthetic running")
        AndroidRuntimeState.updateCoreEgressValidation(true)
        assertEquals(first, AndroidRuntimeState.snapshot()["effectiveProfileDigest"])

        // The same path is now owned by B. A delayed success from A proves nothing about B.
        AndroidRuntimeState.markProfileStaged("/synthetic/profile.json", profileDigest = second)
        AndroidRuntimeState.updateCoreEgressValidation(true)
        assertEquals(second, AndroidRuntimeState.snapshot()["stagedProfileDigest"])
        assertFalse(AndroidRuntimeState.snapshot()["core_egress_validated"] as Boolean)
        assertEquals("profile_identity_mismatch", AndroidRuntimeState.snapshot()["last_failure_kind"])
        assertNull(AndroidRuntimeState.snapshot()["effectiveProfileDigest"])

        AndroidRuntimeState.bindActiveProfile(second)
        AndroidRuntimeState.markRunning("synthetic replacement running")
        AndroidRuntimeState.updateCoreEgressValidation(true)
        assertEquals(second, AndroidRuntimeState.snapshot()["effectiveProfileDigest"])
        AndroidRuntimeState.markStopRequested()
        assertNull(AndroidRuntimeState.snapshot()["effectiveProfileDigest"])
        AndroidRuntimeState.invalidateStagedProfile()
        assertNull(AndroidRuntimeState.snapshot()["stagedProfileDigest"])
    }

    private fun resetState() {
        setPrivateField("environment", null)
        setPrivateField("phase", AndroidRuntimePhase.ARTIFACT_MISSING)
        setPrivateField("stagedConfigPath", null)
        setPrivateField("stagedProfileDigest", null)
        setPrivateField("activeProfileDigest", null)
        setPrivateField(
            "lastMessage",
            "Native runtime bridge has not inspected this host yet.",
        )
        setPrivateField("lastRunningMessage", null)
        setPrivateField("runningSince", null)
        setPrivateField("defaultNetworkInterface", null)
        setPrivateField("defaultNetworkIndex", null)
        setPrivateField("dnsReady", false)
        setPrivateField("vpnValidated", null)
        setPrivateField("coreEgressValidated", null)
        setPrivateField("lastFailureKind", null)
        setPrivateField("lastStopReason", null)
        setPrivateField("awgSafeDiagnosticCode", null)
        setPrivateField("awgSafeDiagnosticOccurrence", null)
        setPrivateField("ipv4RouteCount", 0)
        setPrivateField("ipv6RouteCount", 0)
        setPrivateField("includePackageCount", 0)
        setPrivateField("excludePackageCount", 0)
        setPrivateField("systemNotificationWarning", false)
        setPrivateField("connectionPending", false)
        setPrivateField("tunnelTrafficGeneration", 0L)
        setPrivateField(
            "tunnelTrafficState",
            AndroidTunnelTrafficSampleState.UNAVAILABLE,
        )
        setPrivateField("tunnelUplinkBps", null)
        setPrivateField("tunnelDownlinkBps", null)
        setPrivateField("tunnelUplinkTotalBytes", null)
        setPrivateField("tunnelDownlinkTotalBytes", null)
    }

    private fun setPrivateField(name: String, value: Any?) {
        val field = AndroidRuntimeState::class.java.getDeclaredField(name)
        field.isAccessible = true
        field.set(AndroidRuntimeState, value)
    }
}
