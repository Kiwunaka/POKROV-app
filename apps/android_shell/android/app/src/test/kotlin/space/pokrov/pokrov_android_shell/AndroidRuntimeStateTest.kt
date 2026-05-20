package space.pokrov.pokrov_android_shell

import java.io.File
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
    fun markStopped_preservesSpecificFailureMessage_afterFailedStart() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libbox.so",
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
                coreBinaryPath = "libbox.so",
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

        val snapshot = AndroidRuntimeState.snapshot()
        @Suppress("UNCHECKED_CAST")
        val hostDiagnostics = snapshot["hostDiagnostics"] as Map<String, Any?>

        assertEquals("running", snapshot["phase"])
        assertEquals("healthy", snapshot["hostHealth"])
        assertEquals("healthy", snapshot["dnsState"])
        assertEquals("healthy", snapshot["uplinkState"])
        assertEquals(
            "Сеть wlan0 (#42) | DNS готов | Правила v4=3 v6=2 | Приложения include=4 exclude=1",
            snapshot["hostDiagnosticsSummary"],
        )
        assertEquals("wlan0", snapshot["default_network_interface"])
        assertEquals(42, snapshot["default_network_index"])
        assertEquals(true, snapshot["dns_ready"])
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
                coreBinaryPath = "libbox.so",
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
                coreBinaryPath = "libbox.so",
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
    fun reconcileActiveRuntime_promotesStagedSnapshotBackToRunning() {
        setPrivateField(
            "environment",
            AndroidRuntimeEnvironment(
                artifactDirectory = "artifacts",
                coreBinaryPath = "libbox.so",
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

    private fun resetState() {
        setPrivateField("environment", null)
        setPrivateField("phase", AndroidRuntimePhase.ARTIFACT_MISSING)
        setPrivateField("stagedConfigPath", null)
        setPrivateField(
            "lastMessage",
            "Native runtime bridge has not inspected this host yet.",
        )
        setPrivateField("lastRunningMessage", null)
        setPrivateField("defaultNetworkInterface", null)
        setPrivateField("defaultNetworkIndex", null)
        setPrivateField("dnsReady", false)
        setPrivateField("lastFailureKind", null)
        setPrivateField("lastStopReason", null)
        setPrivateField("ipv4RouteCount", 0)
        setPrivateField("ipv6RouteCount", 0)
        setPrivateField("includePackageCount", 0)
        setPrivateField("excludePackageCount", 0)
    }

    private fun setPrivateField(name: String, value: Any?) {
        val field = AndroidRuntimeState::class.java.getDeclaredField(name)
        field.isAccessible = true
        field.set(AndroidRuntimeState, value)
    }
}
