package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import java.util.UUID

/** Bridge-owned observation only: no requestNetwork, sockets or runtime monitor ownership. */
internal class AndroidTransportNetworkContext(context: Context) {
    private data class UplinkCapabilities(
        val wifi: Boolean,
        val cellular: Boolean,
        val ethernet: Boolean,
        val validated: Boolean,
        val captivePortal: Boolean,
    )

    private val manager = context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val lock = Any()
    private var closed = false
    private var network: Network? = null
    private var links: LinkProperties? = null
    private var capabilities: UplinkCapabilities? = null
    @Volatile private var reference: String? = null

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) { refresh() }
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            val changed = synchronized(lock) {
                !closed && this@AndroidTransportNetworkContext.network == network &&
                    this@AndroidTransportNetworkContext.capabilities != uplinkCapabilities(capabilities)
            }
            if (changed) invalidateSelected(network)
            refresh()
        }
        override fun onLost(network: Network) {
            invalidateSelected(network)
            refresh()
        }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            // Use the event as well as a fresh read so an intervening DNS/route
            // change cannot disappear merely because the network changed back.
            val changed = synchronized(lock) {
                !closed && this@AndroidTransportNetworkContext.network == network && links != linkProperties
            }
            if (changed) invalidateSelected(network)
            refresh()
        }
    }

    private val defaultCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            val capabilities = runCatching { manager.getNetworkCapabilities(network) }.getOrNull()
            if (AndroidNodeLatencyProbe.isEligibleUnderlyingNetwork(capabilities)) {
                val previous = synchronized(lock) { this@AndroidTransportNetworkContext.network }
                if (previous != null && previous != network) invalidateSelected(previous)
            }
            refresh()
        }
    }

    init {
        // Older Android cannot provide the default-network event stream used
        // here. Ordinary Connect is unchanged; ATS cannot claim this binding.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) throw IllegalStateException("network_context_unavailable")
        manager.registerNetworkCallback(NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build(), callback)
        try {
            manager.registerDefaultNetworkCallback(defaultCallback)
        } catch (error: Exception) {
            manager.unregisterNetworkCallback(callback)
            throw error
        }
        refresh()
    }

    fun read(): String? {
        refresh()
        return reference
    }

    fun matches(expected: String): Boolean = synchronized(lock) {
        !closed && reference == expected && matchesCurrentCapabilities()
    }

    fun matchesRuntimeNetwork(expected: String): Boolean = synchronized(lock) {
        !closed && reference == expected && network != null && links != null &&
            matchesCurrentCapabilities() &&
            AndroidDefaultNetworkMonitor.matchesTransportContext(network!!, links!!)
    }

    private fun matchesCurrentCapabilities(): Boolean {
        val selected = network ?: return false
        val current = runCatching { manager.getNetworkCapabilities(selected) }.getOrNull()
        return capabilities != null && capabilities == uplinkCapabilities(current)
    }

    private fun uplinkCapabilities(value: NetworkCapabilities?): UplinkCapabilities? {
        val current = value ?: return null
        if (!AndroidNodeLatencyProbe.isEligibleUnderlyingNetwork(current)) return null
        return UplinkCapabilities(
            wifi = current.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
            cellular = current.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
            ethernet = current.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET),
            validated = current.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
            captivePortal = current.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL),
        )
    }

    private fun refresh() {
        var changed = false
        synchronized(lock) {
            if (closed) return
            val selected = runCatching {
                val active = manager.activeNetwork
                val activeCapabilities = active?.let(manager::getNetworkCapabilities)
                val retained = network
                // Starting our VPN changes the system default to the VPN.
                // Keep its observed uplink rather than reranking other networks.
                if (activeCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true &&
                    retained != null && AndroidNodeLatencyProbe.isEligibleUnderlyingNetwork(manager.getNetworkCapabilities(retained)))
                    retained else AndroidNodeLatencyProbe.selectUnderlyingNetwork(manager)
            }.getOrNull()
            val properties = selected?.let { runCatching { manager.getLinkProperties(it) }.getOrNull() }
            val currentCapabilities = selected?.let {
                uplinkCapabilities(runCatching { manager.getNetworkCapabilities(it) }.getOrNull())
            }
            if (selected != network || properties != links || currentCapabilities != capabilities ||
                (reference == null && selected != null && properties != null && currentCapabilities != null)) {
                network = selected
                links = properties
                capabilities = currentCapabilities
                reference = if (selected != null && properties != null && currentCapabilities != null)
                    "network_" + UUID.randomUUID().toString().replace("-", "") else null
                changed = true
            }
        }
        if (changed) AndroidConnectRequestOwner.cancelIfNetworkChanged()
    }

    private fun invalidateSelected(lost: Network) {
        val changed = synchronized(lock) {
            if (closed || network != lost) false else {
                reference = null
                network = null
                links = null
                capabilities = null
                true
            }
        }
        if (changed) AndroidConnectRequestOwner.cancelIfNetworkChanged()
    }

    fun close() {
        synchronized(lock) {
            if (closed) return
            closed = true
            reference = null
            network = null
            links = null
            capabilities = null
        }
        AndroidConnectRequestOwner.cancelIfNetworkChanged()
        runCatching { manager.unregisterNetworkCallback(callback) }
        runCatching { manager.unregisterNetworkCallback(defaultCallback) }
    }
}
