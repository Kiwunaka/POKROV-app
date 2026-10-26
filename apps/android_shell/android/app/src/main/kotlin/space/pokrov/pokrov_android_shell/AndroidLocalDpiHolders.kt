package space.pokrov.pokrov_android_shell

import org.json.JSONObject

/** Captured Core identities are never reread during withdrawal or publication. */
internal class AndroidLocalDpiHolders(
    private val current: () -> Boolean,
    private val read: (String) -> String,
    private val admit: (String) -> Boolean,
    private val withdraw: (String) -> Unit,
    private val readObservation: (String) -> String,
) {
    private val lock = Any()
    private val holders = linkedMapOf<String, String>()
    private val withdrawnServices = mutableSetOf<String>()
    private var closed = false
    private var anyAdmitted = false

    fun capture(tags: Map<String, String>): Boolean = synchronized(lock) {
        if (closed || !current()) return false
        for ((service, tag) in tags) {
            val id = read(tag)
            if (id.isEmpty()) return false
            holders[service] = id
        }
        current()
    }

    fun publish(service: String, proof: () -> Boolean): Boolean {
        val id = synchronized(lock) {
            if (closed || !current() || service in withdrawnServices) return false
            holders[service] ?: return false
        }
        if (!proof()) return false
        return synchronized(lock) {
            if (closed || !current() || service in withdrawnServices) return false
            val accepted = admit(id)
            if (!current()) { withdraw(id); return false }
            if (accepted) anyAdmitted = true
            accepted
        }
    }

    fun hasAdmission(): Boolean = synchronized(lock) { anyAdmitted }

    fun observationSummary(): String? {
        // Read Core outside our lock. The captured IDs stay private and cannot
        // resolve a successor's counters after a same-profile reload.
        val ids = synchronized(lock) { holders.values.toList() }
        if (ids.isEmpty()) return null
        val observations = ids.mapNotNull { id ->
            runCatching { JSONObject(readObservation(id)) }.getOrNull()?.takeIf {
                it.optString("state") in setOf("unpublished", "ready", "failed", "withdrawn")
            }
        }
        if (observations.size != ids.size) return "Локальный DPI: наблюдение недоступно"
        val ready = observations.count { it.optString("state") == "ready" }
        val pending = observations.count { it.optString("state") == "unpublished" }
        val failed = observations.count { it.optString("state") == "failed" }
        val withdrawn = observations.count { it.optString("state") == "withdrawn" }
        val local = observations.sumOf { it.optLong("local_handoffs") }
        val vpn = observations.sumOf { it.optLong("vpn_handoffs") }
        val quic = observations.sumOf { it.optLong("quic_rejected") }
        val reasons = observations.map { it.optString("failure_reason") }.filter { it in setOf(
            "connect_timeout_ipv4", "connect_timeout_ipv6", "connect_error_ipv4", "connect_error_ipv6",
            "early_read", "early_write",
        ) }.distinct().joinToString(", ")
        return "Локальный DPI: готово $ready, ожидание $pending, сбой $failed, отключено $withdrawn; " +
            "TCP напрямую $local, через VPN $vpn; отклонено соединений QUIC $quic" +
            if (reasons.isEmpty()) "" else "; причина $reasons"
    }

    fun withdrawService(service: String) = synchronized(lock) {
        withdrawnServices.add(service)
        // A native error must not prevent the owner's catalog revoke.
        holders[service]?.let { runCatching { withdraw(it) } }
        Unit
    }

    fun close() = synchronized(lock) {
        if (closed) return
        closed = true
        // The CommandServer API can throw; still withdraw every captured ID.
        holders.values.forEach { runCatching { withdraw(it) } }
    }
}

