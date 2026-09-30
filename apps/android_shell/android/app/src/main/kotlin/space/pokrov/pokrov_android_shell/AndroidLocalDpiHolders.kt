package space.pokrov.pokrov_android_shell

/** Captured Core identities are never reread during withdrawal or publication. */
internal class AndroidLocalDpiHolders(
    private val current: () -> Boolean,
    private val read: (String) -> String,
    private val admit: (String) -> Boolean,
    private val withdraw: (String) -> Unit,
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

