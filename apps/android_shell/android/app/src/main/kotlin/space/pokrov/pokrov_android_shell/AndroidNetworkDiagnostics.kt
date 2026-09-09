package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import org.json.JSONObject
import java.net.Proxy
import java.net.URI
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** The server observes the source IP. It never enters Dart, logs or UI. */
internal object AndroidNetworkDiagnostics {
    private val ownedHosts = setOf("app.pokrov.space", "api.pokrov.space")

    internal fun observationUrl(baseUrl: String): URL? = runCatching {
        val uri = URI(baseUrl)
        if (uri.scheme != "https" || uri.host !in ownedHosts ||
            uri.port !in setOf(-1, 443) || uri.rawUserInfo != null ||
            uri.rawQuery != null || uri.rawFragment != null ||
            uri.rawPath !in setOf("", "/")) return null
        uri.resolve("/api/client/network/context").toURL()
    }.getOrNull()

    internal fun safeCarrier(value: String?): String? {
        val text = value?.trim().orEmpty()
        return text.takeIf {
            it.isNotEmpty() && it.length <= 80 &&
                it.all { char -> char.isLetterOrDigit() || char in " .()+'-_" }
        }
    }

    fun observe(
        context: Context, baseUrl: String, sessionToken: String,
        appVersion: String, profileRevision: String, runtimePhase: String,
    ): Map<String, Any?> {
        val unavailable = mapOf("status" to "unavailable", "network_class" to "unknown", "carrier" to null)
        val url = observationUrl(baseUrl) ?: return emptyMap()
        if (sessionToken.isBlank() || sessionToken.length > 8192 ||
            sessionToken.any { it.isISOControl() }) return emptyMap()
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = AndroidNodeLatencyProbe.selectUnderlyingNetwork(manager) ?: return unavailable
        val capabilities = manager.getNetworkCapabilities(network) ?: return unavailable
        val networkClass = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
        val carrier = if (networkClass == "cellular") runCatching {
            var telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val subscription = SubscriptionManager.getDefaultDataSubscriptionId()
                if (SubscriptionManager.isValidSubscriptionId(subscription)) {
                    telephony = telephony.createForSubscriptionId(subscription)
                }
            }
            safeCarrier(telephony.networkOperatorName)
        }.getOrNull() else null
        val fields = mapOf("network_class" to networkClass, "carrier" to carrier)
        var connection: HttpsURLConnection? = null
        return try {
            // Explicit network binding and no proxy/default-network fallback.
            connection = network.openConnection(url, Proxy.NO_PROXY) as HttpsURLConnection
            connection.connectTimeout = 2500
            connection.readTimeout = 2500
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.useCaches = false
            connection.setRequestProperty("Authorization", "Bearer $sessionToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "POKROV-Android/${appVersion.take(32).filter { it.isLetterOrDigit() || it in ".+-" }}")
            val body = JSONObject().apply {
                put("network_class", networkClass)
                if (carrier != null) put("carrier", carrier)
                put("direct_observation", true)
                put("profile_revision", profileRevision.take(128))
                put("runtime_phase", runtimePhase.take(32))
            }.toString().toByteArray(Charsets.UTF_8)
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }
            val status = when (connection.responseCode) {
                in 200..299 -> "observed"
                401, 403 -> "denied"
                else -> "unavailable"
            }
            fields + ("status" to status)
        } catch (_: Exception) {
            fields + ("status" to "unavailable")
        } finally {
            connection?.disconnect()
        }
    }
}
