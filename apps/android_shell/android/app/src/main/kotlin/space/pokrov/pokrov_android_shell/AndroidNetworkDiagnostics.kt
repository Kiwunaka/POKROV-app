package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.BatteryManager
import android.os.PowerManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import org.json.JSONObject
import java.net.Proxy
import java.net.URI
import java.net.URL
import java.util.Timer
import java.util.TimerTask
import javax.net.ssl.HttpsURLConnection

/** The server observes the source IP. It never enters Dart, logs or UI. */
internal object AndroidNetworkDiagnostics {
    private val ownedHosts = setOf("app.pokrov.space", "api.pokrov.space")
    internal const val intervalMs = 60L * 60 * 1000
    internal fun userAgent(appVersion: String): String =
        "POKROV/android/${appVersion.take(32).filter { it.isLetterOrDigit() || it in ".+-_" }}"
    internal fun checkDue(now: Long, last: Long, batteryPercent: Int, powerSave: Boolean, roaming: Boolean): Boolean =
        batteryPercent in 21..100 && !powerSave && !roaming && (last == 0L || now - last >= intervalMs)

    internal data class MobileOperator(val carrier: String?, val mccMnc: String?)

    internal fun safeMccMnc(value: String?): String? = value?.takeIf {
        it.length in 5..6 && it.all { digit -> digit in '0'..'9' }
    }

    internal fun mobileOperator(context: Context): MobileOperator? = runCatching {
        var telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val subscription = SubscriptionManager.getDefaultDataSubscriptionId()
            if (SubscriptionManager.isValidSubscriptionId(subscription)) {
                telephony = telephony.createForSubscriptionId(subscription)
            }
        }
        MobileOperator(safeCarrier(telephony.networkOperatorName),
            safeMccMnc(telephony.networkOperator))
    }.getOrNull()

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
        reportRunId: String,
    ): Map<String, Any?> {
        val unavailable = mapOf("status" to "skipped", "network_class" to "unknown",
            "carrier" to null, "mcc_mnc" to null)
        val url = observationUrl(baseUrl) ?: return emptyMap()
        if (!reportRunId.matches(Regex("[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"))) return emptyMap()
        if (sessionToken.isBlank() || sessionToken.length > 8192 ||
            sessionToken.any { it.isISOControl() }) return emptyMap()
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = AndroidNodeLatencyProbe.selectUnderlyingNetwork(manager) ?: return unavailable
        val capabilities = manager.getNetworkCapabilities(network) ?: return unavailable
        val roaming = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING)
            else runCatching { (context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager).isNetworkRoaming }.getOrDefault(true)
        val battery = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        // Only the last attempt time is retained. No addresses or network identity.
        val preferences = context.getSharedPreferences("pokrov_network_diagnostics", Context.MODE_PRIVATE)
        synchronized(this) {
            val now = System.currentTimeMillis()
            if (!checkDue(now, preferences.getLong("last_attempt_ms", 0L),
                    battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY), power.isPowerSaveMode, roaming)) {
                return mapOf("status" to "skipped")
            }
            if (!preferences.edit().putLong("last_attempt_ms", now).commit()) return mapOf("status" to "skipped")
        }
        val networkClass = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
        val mobile = if (networkClass == "cellular") mobileOperator(context) else null
        val carrier = mobile?.carrier
        val fields = mapOf("network_class" to networkClass, "carrier" to carrier,
            "mcc_mnc" to mobile?.mccMnc)
        var connection: HttpsURLConnection? = null
        val deadline = Timer("pokrov-network-check", true)
        return try {
            // Explicit network binding and no proxy/default-network fallback.
            connection = network.openConnection(url, Proxy.NO_PROXY) as HttpsURLConnection
            val currentConnection = connection
            deadline.schedule(object : TimerTask() {
                override fun run() { currentConnection.disconnect() }
            }, 6000L)
            connection.connectTimeout = 2500
            connection.readTimeout = 2500
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.useCaches = false
            connection.setRequestProperty("Authorization", "Bearer $sessionToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", userAgent(appVersion))
            val body = JSONObject().apply {
                put("network_class", networkClass)
                if (carrier != null) put("carrier", carrier)
                put("direct_observation", true)
                put("source_network", "physical")
                put("report_run_id", reportRunId)
                put("profile_revision", profileRevision.take(128))
                put("runtime_phase", runtimePhase.take(32))
            }.toString().toByteArray(Charsets.UTF_8)
            if (body.size > 1024) return fields + ("status" to "unavailable")
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }
            val status = when (connection.responseCode) {
                in 200..299 -> "acknowledged"
                401, 403 -> "denied"
                else -> "unavailable"
            }
            fields + ("status" to status)
        } catch (_: Exception) {
            fields + ("status" to "unavailable")
        } finally {
            deadline.cancel()
            connection?.disconnect()
        }
    }
}
