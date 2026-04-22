package space.pokrov.pokrov_android_shell

import java.net.Inet6Address
import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidPlatformRuntimeBridgeTest {
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
