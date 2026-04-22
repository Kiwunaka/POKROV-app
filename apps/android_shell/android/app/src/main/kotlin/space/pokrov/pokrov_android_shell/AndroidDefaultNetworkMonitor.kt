package space.pokrov.pokrov_android_shell

import android.annotation.TargetApi
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import java.net.NetworkInterface

internal object AndroidDefaultNetworkMonitor {
    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M) {
            removeCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            removeCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
        }
    }.build()

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var listener: InterfaceUpdateListener? = null
    @Volatile
    private var currentNetwork: Network? = null
    private var appContext: Context? = null
    private var registered = false
    private val networkLock = Object()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            updateCurrentNetwork(network)
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            updateCurrentNetwork(network, networkCapabilities)
        }

        override fun onLost(network: Network) {
            if (currentNetwork == network) {
                Log.w(LOG_TAG, "Lost default uplink network=${networkToken(network)}")
                currentNetwork = null
                publishInterfaceState(
                    interfaceName = null,
                    interfaceIndex = null,
                    dnsReady = false,
                )
                AndroidRuntimeState.markDegraded(
                    failureKind = "default_network_unavailable",
                    message = "Android tun is established, but the default uplink is unavailable for DNS resolution.",
                )
                signalNetworkUpdate()
            }
        }
    }

    fun ensureStarted(context: Context) {
        val applicationContext = context.applicationContext
        val connectivityManager = connectivity(applicationContext)
        if (!registered || appContext !== applicationContext) {
            unregister()
            register(connectivityManager)
            appContext = applicationContext
            registered = true
        }
        if (currentNetwork == null) {
            activeNetwork()?.let(::updateCurrentNetwork)
        }
    }

    fun start(context: Context, listener: InterfaceUpdateListener) {
        this.listener = listener
        ensureStarted(context)
        val network = currentNetwork ?: activeNetwork()
        if (network != null) {
            currentNetwork = network
            notifyCurrentInterface(network)
        } else {
            publishInterfaceState(
                interfaceName = null,
                interfaceIndex = null,
                dnsReady = false,
            )
        }
    }

    fun stop(listener: InterfaceUpdateListener?) {
        if (listener == null || this.listener === listener) {
            this.listener = null
        }
        if (this.listener == null) {
            unregister()
            appContext = null
            registered = false
        }
    }

    private fun connectivity(context: Context): ConnectivityManager {
        return context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private fun activeNetwork(): Network? {
        val context = appContext ?: return null
        val connectivityManager = connectivity(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null
        }
        val network = connectivityManager.activeNetwork ?: return null
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        return if (isUsableNetwork(capabilities)) {
            network
        } else {
            null
        }
    }

    fun require(): Network {
        currentNetwork?.let { return it }
        Log.i(
            LOG_TAG,
            "Waiting up to ${AndroidPlatformRuntimeBridge.DEFAULT_NETWORK_WAIT_TIMEOUT_MILLIS}ms for a non-VPN default uplink.",
        )
        val network = AndroidPlatformRuntimeBridge.awaitValue(
            currentValue = { currentNetwork },
            refreshValue = {
                activeNetwork()?.also { resolved ->
                    if (currentNetwork != resolved) {
                        updateCurrentNetwork(resolved)
                    }
                } ?: currentNetwork
            },
            waitForSignal = ::waitForNetworkUpdate,
        )
        if (network != null) {
            Log.i(LOG_TAG, "Using default uplink network=${networkToken(network)} for DNS resolution.")
            return network
        }
        publishInterfaceState(
            interfaceName = null,
            interfaceIndex = null,
            dnsReady = false,
        )
        AndroidRuntimeState.markDegraded(
            failureKind = "default_network_unavailable",
            message = "Android tun is established, but no non-VPN default uplink is ready for DNS resolution.",
        )
        throw IllegalStateException("Android default network is unavailable for DNS resolution.")
    }

    private fun notifyCurrentInterface(network: Network) {
        val context = appContext ?: return
        val connectivityManager = connectivity(context)
        val interfaceName = connectivityManager.getLinkProperties(network)?.interfaceName
        if (interfaceName.isNullOrBlank()) {
            Log.w(
                LOG_TAG,
                "Resolved default uplink network=${networkToken(network)}, but interfaceName is unavailable.",
            )
            publishInterfaceState(
                interfaceName = null,
                interfaceIndex = null,
                dnsReady = false,
            )
            AndroidRuntimeState.markDegraded(
                failureKind = "default_network_interface_unresolved",
                message = "Android tun is established, but the default uplink interface is unresolved.",
            )
            return
        }
        val interfaceIndex = AndroidPlatformRuntimeBridge.resolveInterfaceIndex(interfaceName) {
            NetworkInterface.getByName(it)?.index
        }
        if (interfaceIndex == null) {
            Log.w(
                LOG_TAG,
                "Resolved default uplink network=${networkToken(network)} interface=$interfaceName, but index lookup did not settle.",
            )
            publishInterfaceState(
                interfaceName = interfaceName,
                interfaceIndex = null,
                dnsReady = false,
            )
            AndroidRuntimeState.markDegraded(
                failureKind = "default_network_index_unresolved",
                message = "Android tun is established, but the default uplink interface index is unresolved.",
            )
            return
        }
        Log.i(
            LOG_TAG,
            "Selected default uplink network=${networkToken(network)} interface=$interfaceName index=$interfaceIndex",
        )
        publishInterfaceState(
            interfaceName = interfaceName,
            interfaceIndex = interfaceIndex,
            dnsReady = true,
        )
    }

    private fun updateCurrentNetwork(
        network: Network,
        capabilities: NetworkCapabilities? = null,
    ) {
        val context = appContext ?: return
        val connectivityManager = connectivity(context)
        val resolvedCapabilities = capabilities ?: connectivityManager.getNetworkCapabilities(network)
        if (!isUsableNetwork(resolvedCapabilities)) {
            if (resolvedCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                Log.i(
                    LOG_TAG,
                    "Ignoring VPN network=${networkToken(network)} as an uplink candidate.",
                )
            }
            if (currentNetwork == network) {
                currentNetwork = null
                publishInterfaceState(
                    interfaceName = null,
                    interfaceIndex = null,
                    dnsReady = false,
                )
                AndroidRuntimeState.markDegraded(
                    failureKind = "default_network_unavailable",
                    message = "Android tun is established, but the default uplink is unavailable for DNS resolution.",
                )
                signalNetworkUpdate()
            }
            return
        }
        currentNetwork = network
        notifyCurrentInterface(network)
        signalNetworkUpdate()
    }

    private fun isUsableNetwork(capabilities: NetworkCapabilities?): Boolean {
        return capabilities != null &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    private fun register(connectivityManager: ConnectivityManager) {
        when (Build.VERSION.SDK_INT) {
            in 31..Int.MAX_VALUE -> registerBestMatching(connectivityManager)
            in 28 until 31 -> registerRequested(connectivityManager)
            in 26 until 28 -> connectivityManager.registerDefaultNetworkCallback(
                callback,
                mainHandler,
            )
            in 24 until 26 -> connectivityManager.registerDefaultNetworkCallback(
                callback,
            )
            else -> connectivityManager.requestNetwork(request, callback)
        }
    }

    @TargetApi(31)
    private fun registerBestMatching(connectivityManager: ConnectivityManager) {
        connectivityManager.registerBestMatchingNetworkCallback(
            request,
            callback,
            mainHandler,
        )
    }

    @TargetApi(28)
    private fun registerRequested(connectivityManager: ConnectivityManager) {
        connectivityManager.requestNetwork(
            request,
            callback,
            mainHandler,
        )
    }

    private fun unregister() {
        val context = appContext ?: return
        runCatching {
            connectivity(context).unregisterNetworkCallback(callback)
        }
        currentNetwork = null
        publishInterfaceState(
            interfaceName = null,
            interfaceIndex = null,
            dnsReady = false,
        )
        signalNetworkUpdate()
    }

    private fun publishInterfaceState(
        interfaceName: String?,
        interfaceIndex: Int?,
        dnsReady: Boolean,
    ) {
        listener?.updateDefaultInterface(interfaceName.orEmpty(), interfaceIndex ?: -1)
        AndroidRuntimeState.updateDefaultNetwork(
            interfaceName = interfaceName,
            interfaceIndex = interfaceIndex,
            dnsReady = dnsReady,
        )
    }

    private fun waitForNetworkUpdate(waitMillis: Long) {
        synchronized(networkLock) {
            if (currentNetwork == null) {
                runCatching {
                    networkLock.wait(waitMillis)
                }.onFailure { error ->
                    if (error is InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
            }
        }
    }

    private fun signalNetworkUpdate() {
        synchronized(networkLock) {
            networkLock.notifyAll()
        }
    }

    private fun networkToken(network: Network): String {
        return network.toString()
    }

    private const val LOG_TAG = "PokrovDefaultNet"
}
