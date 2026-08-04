package space.pokrov.pokrov_android_shell

/** Keeps a DNS transport callback bound to exactly one established TUN. */
internal class AndroidDnsFailureTokenGate {
    private var activeToken: Any? = null

    fun activate(): Any = Any().also { activeToken = it }

    fun release(): Any? = activeToken.also { activeToken = null }

    fun owns(token: Any): Boolean = activeToken === token
}
