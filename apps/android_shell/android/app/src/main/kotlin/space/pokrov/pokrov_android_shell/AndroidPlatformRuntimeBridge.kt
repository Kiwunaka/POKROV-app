package space.pokrov.pokrov_android_shell

import android.net.Network
import android.os.Build
import android.os.ParcelFileDescriptor
import java.net.Inet6Address
import java.net.InetAddress
import kotlin.math.min

internal data class AndroidRuntimeUplinkProfile(val digest: String, val bindDnsCarrier: Boolean) {
    fun requiresCoreCloseBefore(next: AndroidRuntimeUplinkProfile): Boolean =
        this != next && (bindDnsCarrier || next.bindDnsCarrier)
}

internal object AndroidPlatformRuntimeBridge {
    const val DEFAULT_NETWORK_WAIT_TIMEOUT_MILLIS = 5_000L

    fun shouldPublishMissingNetwork(
        requestGeneration: Long,
        activeGeneration: Long,
        hasCurrentNetwork: Boolean,
    ): Boolean = requestGeneration == activeGeneration && !hasCurrentNetwork
    const val DEFAULT_NETWORK_WAIT_SLICE_MILLIS = 250L

    data class SupportFlags(
        val usePlatformAutoDetectInterfaceControl: Boolean,
        val usePlatformDefaultInterfaceMonitor: Boolean,
        val usePlatformInterfaceGetter: Boolean,
    )

    fun supportFlags(sdkInt: Int): SupportFlags {
        return SupportFlags(
            usePlatformAutoDetectInterfaceControl = true,
            usePlatformDefaultInterfaceMonitor = true,
            usePlatformInterfaceGetter = sdkInt >= Build.VERSION_CODES.R,
        )
    }

    fun resolveInterfaceIndex(
        interfaceName: String,
        maxAttempts: Int = 10,
        retryDelayMillis: Long = 100,
        sleeper: (Long) -> Unit = Thread::sleep,
        indexLookup: (String) -> Int?,
    ): Int? {
        repeat(maxAttempts) { attempt ->
            val index = indexLookup(interfaceName)
            if (index != null && index >= 0) {
                return index
            }
            if (attempt < maxAttempts - 1) {
                sleeper(retryDelayMillis)
            }
        }
        return null
    }

    fun canPublishNetworkResolution(
        requestGeneration: Long,
        activeGeneration: Long,
        isCurrentNetwork: Boolean,
    ): Boolean = isCurrentNetwork && requestGeneration == activeGeneration

    fun bindUplinkSocket(network: Network, fd: Int) {
        // The wrapper owns a duplicate. Core retains its original socket.
        ParcelFileDescriptor.fromFd(fd).use { network.bindSocket(it.fileDescriptor) }
    }

    fun protectAndBindDnsUplink(
        ownsProfile: () -> Boolean,
        currentNetwork: () -> Pair<Long, Long>?,
        protectSocket: () -> Unit,
        bindSocket: (Long) -> Unit,
    ) {
        check(ownsProfile()) { "android: uplink profile changed" }
        val network = currentNetwork() ?: error("android: physical uplink unavailable")
        fun requireCurrent() {
            check(ownsProfile() && currentNetwork() == network) { "android: physical uplink changed" }
        }
        requireCurrent()
        protectSocket()
        requireCurrent()
        bindSocket(network.first)
        requireCurrent()
    }

    fun deliverNetworkUpdate(
        requestGeneration: Long,
        currentGeneration: () -> Long,
        updateInterface: () -> Unit,
        resetNetwork: () -> Unit,
    ) {
        if (requestGeneration != currentGeneration()) return
        updateInterface()
        // The Core callback can block while Android replaces or loses the uplink.
        if (requestGeneration == currentGeneration()) resetNetwork()
    }

    fun <T> awaitValue(
        timeoutMillis: Long = DEFAULT_NETWORK_WAIT_TIMEOUT_MILLIS,
        waitStepMillis: Long = DEFAULT_NETWORK_WAIT_SLICE_MILLIS,
        currentValue: () -> T?,
        refreshValue: () -> T?,
        waitForSignal: (Long) -> Unit,
    ): T? {
        currentValue()?.let { return it }
        refreshValue()?.let { return it }
        var remainingMillis = timeoutMillis
        while (remainingMillis > 0) {
            val waitMillis = min(waitStepMillis, remainingMillis)
            waitForSignal(waitMillis)
            currentValue()?.let { return it }
            refreshValue()?.let { return it }
            remainingMillis -= waitMillis
        }
        return currentValue() ?: refreshValue()
    }

    fun toLibboxPrefix(address: InetAddress, networkPrefixLength: Short): String {
        val normalizedAddress = if (address is Inet6Address) {
            Inet6Address.getByAddress(address.address).hostAddress
        } else {
            address.hostAddress
        }
        return "$normalizedAddress/$networkPrefixLength"
    }

    fun <T> collectInterfaceNames(
        items: Iterable<T>,
        interfaceNameLookup: (T) -> String?,
    ): List<String> {
        return items
            .mapNotNull(interfaceNameLookup)
            .map(String::trim)
            .filter(String::isNotEmpty)
            .distinct()
    }
}
