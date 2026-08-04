package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/** Reads Android's end-to-end validation result for the active VPN network. */
internal object AndroidVpnNetworkHealth {
    @Suppress("DEPRECATION")
    fun resolve(context: Context): Boolean? {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        val vpnCapabilities = connectivity.allNetworks.mapNotNull { network ->
            connectivity.getNetworkCapabilities(network)?.takeIf { capabilities ->
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            }
        }
        if (vpnCapabilities.isEmpty()) {
            return null
        }
        return vpnCapabilities.any { capabilities ->
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }
    }
}
