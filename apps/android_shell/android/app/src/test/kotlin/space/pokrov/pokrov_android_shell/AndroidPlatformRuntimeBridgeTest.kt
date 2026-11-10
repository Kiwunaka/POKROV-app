package space.pokrov.pokrov_android_shell

import java.net.Inet6Address
import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidPlatformRuntimeBridgeTest {
    @Test
    fun dnsUplinkBindingRejectsStoppedOwnersAndChangedNetworks() {
        var ownsProfile = true
        var network = 7L to 1L
        val operations = mutableListOf<String>()
        fun bind(onProtect: () -> Unit = {}, onBind: () -> Unit = {}) {
            AndroidPlatformRuntimeBridge.protectAndBindDnsUplink(
                ownsProfile = { ownsProfile },
                currentNetwork = { network },
                protectSocket = { operations += "protect"; onProtect() },
                bindSocket = { handle -> operations += "bind:$handle"; onBind() },
            )
        }
        bind()
        assertEquals(listOf("protect", "bind:7"), operations)

        operations.clear()
        ownsProfile = false
        assertTrue(runCatching { bind() }.exceptionOrNull() is IllegalStateException)
        assertTrue(operations.isEmpty())

        ownsProfile = true
        assertTrue(runCatching { bind(onProtect = { network = 7L to 2L }) }
            .exceptionOrNull() is IllegalStateException)
        assertEquals(listOf("protect"), operations)

        operations.clear()
        assertTrue(runCatching { bind(onBind = { ownsProfile = false }) }
            .exceptionOrNull() is IllegalStateException)
        assertEquals(listOf("protect", "bind:7"), operations)
    }

    @Test
    fun profileReplacementRetiresTheOldCoreOnlyAcrossDnsProfiles() {
        val dns = AndroidRuntimeUplinkProfile("dns", true)
        val ordinary = AndroidRuntimeUplinkProfile("ordinary", false)
        assertTrue(dns.requiresCoreCloseBefore(ordinary))
        assertTrue(ordinary.requiresCoreCloseBefore(dns))
        assertFalse(ordinary.requiresCoreCloseBefore(ordinary.copy(digest = "another")))
        assertFalse(dns.requiresCoreCloseBefore(dns))
    }

    @Test
    fun delayedNetworkUpdateCannotPublishOrResetAfterUplinkReplacement() {
        var generation = 1L
        val queued = java.util.ArrayDeque<() -> Unit>()
        val delivered = mutableListOf<String>()
        fun enqueue(name: String, onUpdate: () -> Unit = {}) {
            val capturedGeneration = generation
            queued.add {
                AndroidPlatformRuntimeBridge.deliverNetworkUpdate(
                    requestGeneration = capturedGeneration,
                    currentGeneration = { generation },
                    updateInterface = { delivered += name; onUpdate() },
                    resetNetwork = { delivered += "reset:$name" },
                )
            }
        }
        enqueue("wifi")
        generation++
        enqueue("cellular")
        while (queued.isNotEmpty()) queued.removeFirst().invoke()
        assertEquals(listOf("cellular", "reset:cellular"), delivered)

        delivered.clear()
        // Core's interface callback can block while Android publishes another uplink.
        enqueue("cellular") { generation++ }
        queued.removeFirst().invoke()
        assertEquals(listOf("cellular"), delivered)
    }

    @Test
    fun initialDnsInterfaceArrivesBeforeCoreRegistersAndOnlyNewGenerationResets() {
        var generation = 1L
        var initialPublicationGeneration: Long? = null
        var coreCallbackRegistered = false
        val queued = java.util.ArrayDeque<() -> Unit>()
        val delivered = mutableListOf<String>()
        fun enqueueResolution() {
            val requested = generation
            queued.add {
                if (AndroidPlatformRuntimeBridge.canPublishNetworkResolution(
                        requestGeneration = requested,
                        activeGeneration = generation,
                        isCurrentNetwork = true,
                        initialPublicationGeneration = initialPublicationGeneration,
                    )) {
                    AndroidPlatformRuntimeBridge.deliverNetworkUpdate(
                        requestGeneration = requested,
                        currentGeneration = { generation },
                        updateInterface = { delivered += "resolved:$requested" },
                        resetNetwork = { delivered += "reset:$requested" },
                    )
                }
            }
        }
        enqueueResolution()

        AndroidPlatformRuntimeBridge.publishInitialNetworkInterface(
            requestGeneration = generation,
            currentGeneration = { generation },
            updateInterface = {
                assertFalse(coreCallbackRegistered)
                delivered += "initial:$generation"
            },
        )
        initialPublicationGeneration = generation
        coreCallbackRegistered = true
        queued.removeFirst().invoke()
        assertEquals(listOf("initial:1"), delivered)

        generation++
        enqueueResolution()
        queued.removeFirst().invoke()
        assertEquals(listOf("initial:1", "resolved:2", "reset:2"), delivered)
    }

    @Test
    fun transientUplinkLossDoesNotPublishAfterReplacementArrives() {
        assertFalse(
            AndroidPlatformRuntimeBridge.shouldPublishMissingNetwork(
                requestGeneration = 4L,
                activeGeneration = 5L,
                hasCurrentNetwork = true,
            ),
        )
        assertFalse(
            AndroidPlatformRuntimeBridge.shouldPublishMissingNetwork(
                requestGeneration = 4L,
                activeGeneration = 4L,
                hasCurrentNetwork = true,
            ),
        )
        assertTrue(
            AndroidPlatformRuntimeBridge.shouldPublishMissingNetwork(
                requestGeneration = 4L,
                activeGeneration = 4L,
                hasCurrentNetwork = false,
            ),
        )
    }

    @Test
    fun supportFlags_enablePlatformMonitoringOnModernAndroid() {
        val flags = AndroidPlatformRuntimeBridge.supportFlags(34)

        assertTrue(flags.usePlatformAutoDetectInterfaceControl)
        assertTrue(flags.usePlatformDefaultInterfaceMonitor)
        assertTrue(flags.usePlatformInterfaceGetter)
    }

    @Test
    fun supportFlags_keepInterfaceGetterOffBeforeAndroidR() {
        val flags = AndroidPlatformRuntimeBridge.supportFlags(29)

        assertTrue(flags.usePlatformAutoDetectInterfaceControl)
        assertTrue(flags.usePlatformDefaultInterfaceMonitor)
        assertFalse(flags.usePlatformInterfaceGetter)
    }

    @Test
    fun resolveInterfaceIndex_retriesUntilLookupSucceeds() {
        var attempts = 0
        val slept = mutableListOf<Long>()

        val resolved = AndroidPlatformRuntimeBridge.resolveInterfaceIndex(
            interfaceName = "wlan0",
            maxAttempts = 4,
            sleeper = { slept += it },
        ) { _ ->
            attempts += 1
            if (attempts < 3) {
                null
            } else {
                42
            }
        }

        assertEquals(42, resolved)
        assertEquals(3, attempts)
        assertEquals(listOf(100L, 100L), slept)
    }

    @Test
    fun networkResolution_publishIsFencedByGenerationAndCurrentNetwork() {
        assertTrue(
            AndroidPlatformRuntimeBridge.canPublishNetworkResolution(
                requestGeneration = 8L,
                activeGeneration = 8L,
                isCurrentNetwork = true,
            ),
        )
        assertFalse(
            AndroidPlatformRuntimeBridge.canPublishNetworkResolution(
                requestGeneration = 7L,
                activeGeneration = 8L,
                isCurrentNetwork = true,
            ),
        )
        assertFalse(
            AndroidPlatformRuntimeBridge.canPublishNetworkResolution(
                requestGeneration = 8L,
                activeGeneration = 8L,
                isCurrentNetwork = false,
            ),
        )
    }

    @Test
    fun defaultNetworkRefresh_ignoresNoisyCapabilityCallbacksForResolvedInterface() {
        assertEquals(
            DefaultNetworkRefreshAction.NONE,
            resolveDefaultNetworkRefreshAction(
                networkChanged = false,
                capabilitiesChanged = false,
                interfaceReady = true,
                resolutionPending = false,
            ),
        )
        assertEquals(
            DefaultNetworkRefreshAction.REPUBLISH_CAPABILITIES,
            resolveDefaultNetworkRefreshAction(
                networkChanged = false,
                capabilitiesChanged = true,
                interfaceReady = true,
                resolutionPending = false,
            ),
        )
    }

    @Test
    fun defaultNetworkRefresh_resolvesOnlyOnceWhileLookupIsPending() {
        assertEquals(
            DefaultNetworkRefreshAction.RESOLVE_INTERFACE,
            resolveDefaultNetworkRefreshAction(
                networkChanged = true,
                capabilitiesChanged = true,
                interfaceReady = false,
                resolutionPending = false,
            ),
        )
        assertEquals(
            DefaultNetworkRefreshAction.NONE,
            resolveDefaultNetworkRefreshAction(
                networkChanged = false,
                capabilitiesChanged = false,
                interfaceReady = false,
                resolutionPending = true,
            ),
        )
    }

    @Test
    fun runtimeReload_happensOnlyForAResolvedUplinkInterfaceHandover() {
        assertFalse(
            shouldReloadRuntimeForInterfaceChange(
                previousInterfaceName = null,
                nextInterfaceName = "rmnet_data1",
                dnsReady = true,
            ),
        )
        assertFalse(
            shouldReloadRuntimeForInterfaceChange(
                previousInterfaceName = "wlan0",
                nextInterfaceName = "wlan0",
                dnsReady = true,
            ),
        )
        assertFalse(
            shouldReloadRuntimeForInterfaceChange(
                previousInterfaceName = "wlan0",
                nextInterfaceName = "rmnet_data1",
                dnsReady = false,
            ),
        )
        assertTrue(
            shouldReloadRuntimeForInterfaceChange(
                previousInterfaceName = "wlan0",
                nextInterfaceName = "rmnet_data1",
                dnsReady = true,
            ),
        )
        assertTrue(
            shouldResetCoreNetworkForLinkChange(
                previousInterfaceName = "wlan0",
                nextInterfaceName = "wlan0",
                dnsReady = true,
            ),
        )
        assertFalse(
            shouldResetCoreNetworkForLinkChange(
                previousInterfaceName = "wlan0",
                nextInterfaceName = "rmnet_data1",
                dnsReady = true,
            ),
        )
    }

    @Test
    fun toLibboxPrefix_removesIpv6ScopeSuffixAndAddsPrefixLength() {
        val scopedAddress = Inet6Address.getByAddress(
            null,
            byteArrayOf(
                0xfe.toByte(),
                0x80.toByte(),
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                1,
            ),
            7,
        )

        val prefix = AndroidPlatformRuntimeBridge.toLibboxPrefix(scopedAddress, 64.toShort())

        assertFalse(prefix.contains("%"))
        assertTrue(prefix.endsWith("/64"))
        assertTrue(prefix.startsWith("fe80:"))
    }

    @Test
    fun toLibboxPrefix_keepsIpv4AddressFormat() {
        val prefix = AndroidPlatformRuntimeBridge.toLibboxPrefix(
            InetAddress.getByName("192.168.50.10"),
            24.toShort(),
        )

        assertEquals("192.168.50.10/24", prefix)
    }

    @Test
    fun collectInterfaceNames_skipsBlankValuesAndDeduplicates() {
        val names = AndroidPlatformRuntimeBridge.collectInterfaceNames(
            items = listOf(1, 2, 3, 4, 5),
        ) { index ->
            when (index) {
                1 -> "wlan0"
                2 -> " "
                3 -> "rmnet_data0"
                4 -> "wlan0"
                else -> null
            }
        }

        assertEquals(listOf("wlan0", "rmnet_data0"), names)
    }

    @Test
    fun awaitValue_returnsCallbackValueBeforeTimeout() {
        var current: String? = null
        val waits = mutableListOf<Long>()

        val resolved = AndroidPlatformRuntimeBridge.awaitValue(
            timeoutMillis = 1_000L,
            waitStepMillis = 250L,
            currentValue = { current },
            refreshValue = { null },
            waitForSignal = { waitMillis ->
                waits += waitMillis
                if (waits.size == 2) {
                    current = "wlan0"
                }
            },
        )

        assertEquals("wlan0", resolved)
        assertEquals(listOf(250L, 250L), waits)
    }

    @Test
    fun awaitValue_returnsFallbackValueWhenRefreshFindsNetwork() {
        var refreshes = 0

        val resolved = AndroidPlatformRuntimeBridge.awaitValue(
            timeoutMillis = 1_000L,
            waitStepMillis = 200L,
            currentValue = { null },
            refreshValue = {
                refreshes += 1
                if (refreshes >= 3) {
                    "rmnet_data0"
                } else {
                    null
                }
            },
            waitForSignal = {},
        )

        assertEquals("rmnet_data0", resolved)
        assertEquals(3, refreshes)
    }

    @Test
    fun awaitValue_returnsNullAfterTimeoutWhenCallbackAndRefreshStayEmpty() {
        var waitedMillis = 0L

        val resolved = AndroidPlatformRuntimeBridge.awaitValue(
            timeoutMillis = 600L,
            waitStepMillis = 250L,
            currentValue = { null },
            refreshValue = { null },
            waitForSignal = { waitMillis ->
                waitedMillis += waitMillis
            },
        )

        assertEquals(null, resolved)
        assertEquals(600L, waitedMillis)
    }
}
