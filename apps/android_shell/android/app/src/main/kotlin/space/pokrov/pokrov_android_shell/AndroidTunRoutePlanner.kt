package space.pokrov.pokrov_android_shell

internal data class AndroidTunRoutePlan(
    val addDefaultIpv4Route: Boolean,
    val addDefaultIpv6Route: Boolean,
    val allowIpv4: Boolean,
    val allowIpv6: Boolean,
)

internal object AndroidTunRoutePlanner {
    fun plan(
        autoRoute: Boolean,
        hasIpv4Address: Boolean,
        hasIpv6Address: Boolean,
        hasIpv4Route: Boolean,
        hasIpv6Route: Boolean,
        hasIpv4DefaultRoute: Boolean,
        hasIpv6DefaultRoute: Boolean,
    ): AndroidTunRoutePlan {
        val addDefaultIpv4Route =
            autoRoute && hasIpv4Address && (!hasIpv4Route || !hasIpv4DefaultRoute)
        val addDefaultIpv6Route =
            autoRoute && hasIpv6Address && (!hasIpv6Route || !hasIpv6DefaultRoute)
        return AndroidTunRoutePlan(
            addDefaultIpv4Route = addDefaultIpv4Route,
            addDefaultIpv6Route = addDefaultIpv6Route,
            allowIpv4 = hasIpv4Address || hasIpv4Route || addDefaultIpv4Route,
            allowIpv6 = hasIpv6Address || hasIpv6Route || addDefaultIpv6Route,
        )
    }
}
