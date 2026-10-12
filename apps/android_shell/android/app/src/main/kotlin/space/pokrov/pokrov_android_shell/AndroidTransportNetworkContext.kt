package space.pokrov.pokrov_android_shell

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import java.net.Inet6Address
import java.net.InetAddress
import java.util.UUID

/** Bridge-owned observation only: no requestNetwork, sockets or runtime monitor ownership. */
internal class AndroidTransportNetworkContext(context: Context) {
    internal data class CandidateNetwork(
        val network: Network?,
        val links: LinkProperties?,
        val contextRef: String?,
        val networkAvailable: Boolean?,
        val captivePortal: Boolean?,
        val networkClass: String? = null,
        val mccMnc: String? = null,
        val carrier: String? = null,
        val wifiSsid: String? = null,
    ) {
        fun channelValue(): Map<String, Any?> = mapOf(
            "selection_key" to selectionKey(network?.networkHandle, networkClass, mccMnc),
            "context_ref" to contextRef,
            "network_available" to networkAvailable,
            "captive_portal" to captivePortal,
            "network_class" to networkClass,
            "mcc_mnc" to mccMnc,
            "ipv6_available" to links?.let { properties ->
                ipv6Available(properties.linkAddresses.map { it.address },
                    properties.routes.any { it.isDefaultRoute && it.destination.address is Inet6Address })
            },
        ) + if (networkClass == "cellular") mapOf("carrier" to carrier) else emptyMap()

        companion object {
            fun ipv6Available(addresses: Iterable<InetAddress>, defaultRoute: Boolean): Boolean =
                defaultRoute && addresses.any { address ->
                    address is Inet6Address && !address.isAnyLocalAddress &&
                        !address.isLoopbackAddress && !address.isLinkLocalAddress && !address.isMulticastAddress
                }

            fun selectionKey(handle: Long?, networkClass: String?, mccMnc: String?): String? =
                if (networkClass == "cellular" && mccMnc != null) "android:cellular:$mccMnc"
                else handle?.let { "android:$it" }
        }
    }

    private data class UplinkCapabilities(
        val wifi: Boolean,
        val cellular: Boolean,
        val ethernet: Boolean,
        val validated: Boolean,
        val captivePortal: Boolean,
    )

    private val appContext = context.applicationContext
    private val manager = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val lock = Any()
    private var closed = false
    private var network: Network? = null
    private var links: LinkProperties? = null
    private var capabilities: UplinkCapabilities? = null
    @Volatile private var reference: String? = null

    private val networkRequest = NetworkRequest.Builder()
        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        .build()
    private var wifiLocationAllowed = canReadWifiSsid()
    private val wifiSsids = mutableMapOf<Network, String?>()
    private var callback = createNetworkCallback()

    private fun createNetworkCallback(): UplinkCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            UplinkCallback(if (wifiLocationAllowed) ConnectivityManager.NetworkCallback.FLAG_INCLUDE_LOCATION_INFO else 0)
        } else UplinkCallback()

    private inner class UplinkCallback : ConnectivityManager.NetworkCallback {
        constructor() : super()
        @android.annotation.TargetApi(Build.VERSION_CODES.S)
        constructor(flags: Int) : super(flags)
        override fun onAvailable(network: Network) { refresh() }
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            val changed = synchronized(lock) {
                if (closed || callback !== this) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                    wifiSsids[network] = if (wifiLocationAllowed && canReadWifiSsid())
                        decodeWifiSsid((capabilities.transportInfo as? WifiInfo)?.ssid) else null
                }
                !closed && this@AndroidTransportNetworkContext.network == network &&
                    this@AndroidTransportNetworkContext.capabilities != uplinkCapabilities(capabilities)
            }
            if (changed) invalidateSelected(network)
            refresh()
        }
        override fun onLost(network: Network) {
            synchronized(lock) {
                if (closed || callback !== this) return
                wifiSsids.remove(network)
            }
            invalidateSelected(network)
            refresh()
        }
        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            // Use the event as well as a fresh read so an intervening DNS/route
            // change cannot disappear merely because the network changed back.
            val changed = synchronized(lock) {
                if (closed || callback !== this) return
                this@AndroidTransportNetworkContext.network == network && links != linkProperties
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
        manager.registerNetworkCallback(networkRequest, callback)
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

    fun candidateNetwork(): CandidateNetwork {
        refreshWifiLocationAccess()
        refresh()
        val observed = synchronized(lock) {
            if (closed) return@synchronized CandidateNetwork(null, null, null, null, null)
            val observed = capabilities
            if (network != null && observed != null) {
                val networkClass = when {
                    observed.cellular -> "cellular"
                    observed.wifi -> "wifi"
                    observed.ethernet -> "ethernet"
                    else -> "other"
                }
                CandidateNetwork(network, links, reference, true, observed.captivePortal,
                    networkClass, wifiSsid = if (observed.wifi && canReadWifiSsid())
                        network?.let(wifiSsids::get) else null)
            } else {
                // A failed/racing capability read is unknown, not proof of no network.
                val available = runCatching {
                    val observedNetworks = manager.allNetworks.map { manager.getNetworkCapabilities(it) }
                    if (observedNetworks.any { it == null }) null
                    else observedNetworks.any(AndroidNodeLatencyProbe::isEligibleUnderlyingNetwork)
                        .let { if (it) null else false }
                }.getOrNull()
                CandidateNetwork(null, null, null, available, if (available == false) false else null)
            }
        }
        if (observed.networkClass != "cellular") return observed
        val mobile = AndroidNetworkDiagnostics.mobileOperator(appContext)
        return observed.copy(mccMnc = mobile?.mccMnc, carrier = mobile?.carrier)
    }

    private fun canReadWifiSsid(): Boolean =
        ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED &&
            LocationManagerCompat.isLocationEnabled(appContext.getSystemService(LocationManager::class.java))

    private fun refreshWifiLocationAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        synchronized(lock) {
            if (closed) return
            val allowed = canReadWifiSsid()
            if (allowed == wifiLocationAllowed) return
            // A grant/toggle change needs fresh callback capabilities; synchronous
            // getNetworkCapabilities always redacts location-sensitive Wi-Fi info.
            manager.unregisterNetworkCallback(callback)
            wifiLocationAllowed = allowed
            wifiSsids.clear()
            callback = createNetworkCallback()
            manager.registerNetworkCallback(networkRequest, callback)
        }
    }

    fun isCurrent(expected: String): Boolean = reference == expected

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
            wifiSsids.clear()
            reference = null
            network = null
            links = null
            capabilities = null
        }
        AndroidConnectRequestOwner.cancelIfNetworkChanged()
        runCatching { manager.unregisterNetworkCallback(callback) }
        runCatching { manager.unregisterNetworkCallback(defaultCallback) }
    }

    companion object {
        internal fun decodeWifiSsid(raw: String?): String? = raw
            ?.takeUnless { it == WifiManager.UNKNOWN_SSID }
            ?.removeSurrounding("\"")
            ?.takeUnless { it.isEmpty() }
    }
}
