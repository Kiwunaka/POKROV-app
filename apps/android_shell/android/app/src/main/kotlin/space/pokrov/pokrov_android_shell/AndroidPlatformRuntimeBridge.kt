package space.pokrov.pokrov_android_shell

import android.os.Build
import java.net.Inet6Address
import java.net.InetAddress
import kotlin.math.min

internal object AndroidPlatformRuntimeBridge {
    const val DEFAULT_NETWORK_WAIT_TIMEOUT_MILLIS = 5_000L
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
