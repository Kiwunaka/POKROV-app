package space.pokrov.pokrov_android_shell

internal class ApiLoopbackProxyOwner {
    private var owner: Any? = null
    private var port: Int? = null

    @Synchronized
    fun start(requester: Any, active: () -> Boolean, start: () -> Int?, stop: () -> Unit): Int? {
        if (!active()) return null
        if (owner === requester) return port
        if (owner != null) {
            stop()
            owner = null
            port = null
        }
        val value = start()?.takeIf { it in 1..65535 } ?: return null
        if (!active()) {
            stop()
            return null
        }
        owner = requester
        port = value
        return value
    }

    @Synchronized
    fun close(requester: Any, stop: () -> Unit) {
        if (owner !== requester) return
        try { stop() } finally {
            owner = null
            port = null
        }
    }
}
