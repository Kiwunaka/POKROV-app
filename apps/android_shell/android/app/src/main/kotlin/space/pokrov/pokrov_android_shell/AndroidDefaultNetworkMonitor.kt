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
import space.pokrov.core.libbox.InterfaceUpdateListener
import java.net.NetworkInterface
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

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
    private var currentNetworkGeneration = 0L
    private var interfaceResolutionExecutor: ExecutorService? = null

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
            if (clearCurrentNetworkIfMatches(network)) {
                Log.w(LOG_TAG, "Lost default uplink network.")
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
            updateCurrentNetwork(network)
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
            "Ждем до ${AndroidPlatformRuntimeBridge.DEFAULT_NETWORK_WAIT_TIMEOUT_MILLIS}мс, пока Android покажет обычную сеть устройства.",
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
            Log.i(LOG_TAG, "Using the default uplink for DNS resolution.")
            return network
        }
        publishInterfaceState(
            interfaceName = null,
            interfaceIndex = null,
            dnsReady = false,
        )
        AndroidRuntimeState.markDegraded(
            failureKind = "default_network_unavailable",
            message = "Android подключил POKROV, но обычная сеть устройства еще не готова для DNS.",
        )
        throw IllegalStateException("Android default network is unavailable for DNS resolution.")
    }

    private fun notifyCurrentInterface(network: Network, generation: Long) {
        val context = appContext ?: return
        val connectivityManager = connectivity(context)
        val interfaceName = connectivityManager.getLinkProperties(network)?.interfaceName
        if (interfaceName.isNullOrBlank()) {
            Log.w(
                LOG_TAG,
                "Resolved default uplink, but its interface name is unavailable.",
            )
            publishInterfaceStateIfCurrent(
                network = network,
                generation = generation,
                interfaceName = null,
                interfaceIndex = null,
                dnsReady = false,
            )
            return
        }
        publishInterfaceStateIfCurrent(
            network = network,
            generation = generation,
            interfaceName = interfaceName,
            interfaceIndex = null,
            dnsReady = false,
        )
        submitInterfaceResolution {
            resolveAndPublishInterface(network, generation, interfaceName)
        }
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
                    "Пропускаем VPN-сеть при выборе обычной сети устройства.",
                )
            }
            if (clearCurrentNetworkIfMatches(network)) {
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
        val generation = selectCurrentNetwork(network)
        notifyCurrentInterface(network, generation)
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
        appContext?.let { context ->
            runCatching {
                connectivity(context).unregisterNetworkCallback(callback)
            }
        }
        invalidateCurrentNetwork()
        publishInterfaceState(
            interfaceName = null,
            interfaceIndex = null,
            dnsReady = false,
        )
        shutdownInterfaceResolution()
        signalNetworkUpdate()
    }

    private fun selectCurrentNetwork(network: Network): Long = synchronized(networkLock) {
        currentNetwork = network
        ++currentNetworkGeneration
    }

    private fun clearCurrentNetworkIfMatches(network: Network): Boolean = synchronized(networkLock) {
        if (currentNetwork != network) {
            false
        } else {
            currentNetwork = null
            ++currentNetworkGeneration
            true
        }
    }

    private fun invalidateCurrentNetwork() {
        synchronized(networkLock) {
            currentNetwork = null
            ++currentNetworkGeneration
        }
    }

    private fun publishInterfaceStateIfCurrent(
        network: Network,
        generation: Long,
        interfaceName: String?,
        interfaceIndex: Int?,
        dnsReady: Boolean,
    ) {
        val activeGeneration: Long
        val isCurrentNetwork: Boolean
        synchronized(networkLock) {
            activeGeneration = currentNetworkGeneration
            isCurrentNetwork = currentNetwork == network
        }
        if (
            AndroidPlatformRuntimeBridge.canPublishNetworkResolution(
                requestGeneration = generation,
                activeGeneration = activeGeneration,
                isCurrentNetwork = isCurrentNetwork,
            )
        ) {
            publishInterfaceState(interfaceName, interfaceIndex, dnsReady)
        }
    }

    private fun resolveAndPublishInterface(
        network: Network,
        generation: Long,
        interfaceName: String,
    ) {
        val interfaceIndex = AndroidPlatformRuntimeBridge.resolveInterfaceIndex(interfaceName) {
            NetworkInterface.getByName(it)?.index
        }
        if (interfaceIndex == null) {
            Log.w(LOG_TAG, "Resolved default uplink, but interface index lookup did not settle.")
            publishInterfaceStateIfCurrent(
                network = network,
                generation = generation,
                interfaceName = interfaceName,
                interfaceIndex = null,
                dnsReady = false,
            )
            return
        }
        Log.i(LOG_TAG, "Selected default uplink interface.")
        publishInterfaceStateIfCurrent(
            network = network,
            generation = generation,
            interfaceName = interfaceName,
            interfaceIndex = interfaceIndex,
            dnsReady = true,
        )
    }

    private fun submitInterfaceResolution(task: () -> Unit) {
        val executor = synchronized(networkLock) {
            interfaceResolutionExecutor ?: Executors.newSingleThreadExecutor().also {
                interfaceResolutionExecutor = it
            }
        }
        runCatching { executor.execute(task) }
    }

    private fun shutdownInterfaceResolution() {
        val executor = synchronized(networkLock) {
            interfaceResolutionExecutor.also { interfaceResolutionExecutor = null }
        }
        executor?.shutdownNow()
    }

    private fun publishInterfaceState(
        interfaceName: String?,
        interfaceIndex: Int?,
        dnsReady: Boolean,
    ) {
        val capabilities = currentNetwork?.let { network ->
            appContext?.let(::connectivity)?.getNetworkCapabilities(network)
        }
        listener?.updateDefaultInterface(
            interfaceName.orEmpty(),
            interfaceIndex ?: -1,
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false,
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_CONGESTED) == false,
        )
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

    private const val LOG_TAG = "PokrovDefaultNet"
}
