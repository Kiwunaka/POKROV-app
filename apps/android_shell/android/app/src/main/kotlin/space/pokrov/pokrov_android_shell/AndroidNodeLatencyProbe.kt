package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.SystemClock
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

internal data class AndroidNodeLatencyTarget(
    val code: String,
    val host: String,
    val port: Int,
)

internal object AndroidNodeLatencyProbe {
    private const val MAX_TARGETS = 16
    private const val CONNECT_TIMEOUT_MILLIS = 1500
    private val CODE_PATTERN = Regex("^[a-z0-9._-]{1,64}$")

    fun parseTargets(raw: Any?): List<AndroidNodeLatencyTarget> {
        val rows = raw as? List<*> ?: return emptyList()
        val seen = mutableSetOf<String>()
        return rows.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val code = map["code"]?.toString()?.trim()?.lowercase().orEmpty()
            val host = map["host"]?.toString()?.trim().orEmpty()
            val port = (map["port"] as? Number)?.toInt()
                ?: map["port"]?.toString()?.toIntOrNull()
                ?: 0
            if (!CODE_PATTERN.matches(code) ||
                host.isBlank() ||
                host.length > 253 ||
                host.any { it.isWhitespace() || it.isISOControl() } ||
                host.any { it in "/\\@?#" } ||
                port !in 1..65535 ||
                !seen.add(code)
            ) {
                return@mapNotNull null
            }
            AndroidNodeLatencyTarget(code = code, host = host, port = port)
        }.take(MAX_TARGETS)
    }

    fun measure(context: Context, targets: List<AndroidNodeLatencyTarget>): Map<String, Int> {
        if (targets.isEmpty()) {
            return emptyMap()
        }
        val connectivityManager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = selectUnderlyingNetwork(connectivityManager) ?: return emptyMap()
        val executor = Executors.newFixedThreadPool(minOf(4, targets.size))
        return try {
            val futures = targets.associateWith { target ->
                executor.submit(Callable { measureOne(network, target) })
            }
            buildMap {
                for ((target, future) in futures) {
                    val latency = runCatching {
                        future.get(CONNECT_TIMEOUT_MILLIS.toLong() + 750L, TimeUnit.MILLISECONDS)
                    }.getOrNull()
                    if (latency != null) {
                        put(target.code, latency)
                    }
                }
            }
        } finally {
            executor.shutdownNow()
        }
    }

    private fun selectUnderlyingNetwork(connectivityManager: ConnectivityManager): Network? {
        fun capabilities(network: Network): NetworkCapabilities? =
            connectivityManager.getNetworkCapabilities(network)

        val active = connectivityManager.activeNetwork
        if (active != null && isEligibleUnderlyingNetwork(capabilities(active))) {
            return active
        }
        return connectivityManager.allNetworks
            .mapNotNull { network ->
                val networkCapabilities = capabilities(network)
                if (!isEligibleUnderlyingNetwork(networkCapabilities)) {
                    null
                } else {
                    network to networkScore(networkCapabilities!!)
                }
            }
            .maxByOrNull { it.second }
            ?.first
    }

    private fun isEligibleUnderlyingNetwork(capabilities: NetworkCapabilities?): Boolean {
        if (capabilities == null ||
            !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
            !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        ) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_SUSPENDED)
        ) {
            return false
        }
        return true
    }

    private fun networkScore(capabilities: NetworkCapabilities): Int {
        var score = 0
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
            score += 100
        }
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            score += 20
        } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
            score += 10
        }
        return score
    }

    private fun measureOne(network: Network, target: AndroidNodeLatencyTarget): Int? {
        val address = runCatching {
            network.getAllByName(target.host).firstOrNull(::isPublicAddress)
        }.getOrNull() ?: return null
        val started = SystemClock.elapsedRealtimeNanos()
        return runCatching {
            Socket().use { socket ->
                network.bindSocket(socket)
                socket.connect(
                    InetSocketAddress(address, target.port),
                    CONNECT_TIMEOUT_MILLIS,
                )
            }
            val elapsedNanos = SystemClock.elapsedRealtimeNanos() - started
            ((elapsedNanos + 999_999L) / 1_000_000L).coerceIn(1L, 60_000L).toInt()
        }.getOrNull()
    }

    private fun isPublicAddress(address: InetAddress): Boolean {
        if (address.isAnyLocalAddress ||
            address.isLoopbackAddress ||
            address.isLinkLocalAddress ||
            address.isSiteLocalAddress ||
            address.isMulticastAddress
        ) {
            return false
        }
        if (address is Inet6Address) {
            val first = address.address.firstOrNull()?.toInt()?.and(0xff) ?: return false
            if (first and 0xfe == 0xfc) {
                return false
            }
        }
        return true
    }
}
