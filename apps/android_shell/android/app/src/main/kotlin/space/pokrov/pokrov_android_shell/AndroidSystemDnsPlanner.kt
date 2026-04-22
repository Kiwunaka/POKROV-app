package space.pokrov.pokrov_android_shell

import org.json.JSONArray
import org.json.JSONObject
import java.net.InetAddress

internal object AndroidSystemDnsPlanner {
    private const val loopbackSystemDnsServer = "127.0.0.1"
    private const val fallbackSystemDnsServer = "1.1.1.1"

    fun resolveSystemDnsServer(configContent: String): String {
        val hasUsableUpstream = runCatching {
            val root = JSONObject(configContent)
            val servers = root.optJSONObject("dns")?.optJSONArray("servers")
            val addresses = buildList {
                if (servers != null) {
                    for (index in 0 until servers.length()) {
                        val server = servers.optJSONObject(index) ?: continue
                        add(server.optString("address"))
                    }
                }
            }
            firstUsablePublicDnsServer(addresses) != null
        }.getOrDefault(false)
        return if (hasUsableUpstream) {
            loopbackSystemDnsServer
        } else {
            fallbackSystemDnsServer
        }
    }

    internal fun firstUsablePublicDnsServer(addresses: Iterable<String?>): String? {
        for (address in addresses) {
            val candidate = normalizeAddress(address)
            if (candidate != null && !isPrivateOrLoopback(candidate)) {
                return candidate
            }
        }
        return null
    }

    internal fun normalizeAddress(address: String?): String? {
        val raw = address?.trim().orEmpty()
        if (raw.isBlank()) {
            return null
        }
        if (raw.equals("local", ignoreCase = true)) {
            return null
        }
        val withoutScheme = raw.substringAfter("://", raw)
        val hostPort = withoutScheme.substringBefore('/').substringBefore('?').substringBefore('#')
        val host = when {
            hostPort.startsWith('[') -> hostPort.substringAfter('[').substringBefore(']')
            hostPort.count { it == ':' } == 1 && hostPort.contains('.') -> hostPort.substringBefore(':')
            else -> hostPort
        }.trim()
        if (host.isBlank() || !looksLikeNumericAddress(host)) {
            return null
        }
        return runCatching { InetAddress.getByName(host).hostAddress }.getOrNull()
    }

    internal fun isPrivateOrLoopback(address: String): Boolean {
        val inetAddress = runCatching { InetAddress.getByName(address) }.getOrNull() ?: return true
        if (
            inetAddress.isAnyLocalAddress ||
            inetAddress.isLoopbackAddress ||
            inetAddress.isLinkLocalAddress ||
            inetAddress.isSiteLocalAddress
        ) {
            return true
        }
        val bytes = inetAddress.address
        if (bytes.size == 16) {
            val first = bytes[0].toInt() and 0xff
            if (first == 0xfc || first == 0xfd) {
                return true
            }
        } else if (bytes.size == 4) {
            val first = bytes[0].toInt() and 0xff
            val second = bytes[1].toInt() and 0xff
            if (first == 100 && second in 64..127) {
                return true
            }
        }
        return false
    }

    private fun looksLikeNumericAddress(value: String): Boolean {
        val ipv4Pattern = Regex("""^\d{1,3}(\.\d{1,3}){3}$""")
        val ipv6Pattern = Regex("""^[0-9A-Fa-f:]+$""")
        return ipv4Pattern.matches(value) || ipv6Pattern.matches(value)
    }
}
