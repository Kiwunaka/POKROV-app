package space.pokrov.pokrov_android_shell

internal object AndroidTunMtuPolicy {
    const val DEFAULT_MTU = 1280
    const val MINIMUM_MTU = 1280
    const val MAXIMUM_MTU = 1500

    fun select(requested: Any?, platformInterfaceMtu: Int?): Int {
        val requestedMtu = when (requested) {
            is Byte -> requested.toInt()
            is Short -> requested.toInt()
            is Int -> requested
            is Long -> requested.takeIf {
                it >= Int.MIN_VALUE.toLong() && it <= Int.MAX_VALUE.toLong()
            }?.toInt()
            else -> null
        }
        val boundedRequested = requestedMtu
            ?.takeIf { it in MINIMUM_MTU..MAXIMUM_MTU }
            ?: DEFAULT_MTU
        val platformCeiling = platformInterfaceMtu
            ?.takeIf { it >= MINIMUM_MTU }
            ?.coerceAtMost(MAXIMUM_MTU)
            ?: MAXIMUM_MTU
        return boundedRequested.coerceAtMost(platformCeiling)
    }
}
