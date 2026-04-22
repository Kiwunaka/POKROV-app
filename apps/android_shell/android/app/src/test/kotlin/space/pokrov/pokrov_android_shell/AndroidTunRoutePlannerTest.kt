package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidTunRoutePlannerTest {
    @Test
    fun plan_addsDefaultRoutesWhenTunHasAddressesButNoExplicitRoutes() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = true,
            hasIpv4Address = true,
            hasIpv6Address = true,
            hasIpv4Route = false,
            hasIpv6Route = false,
            hasIpv4DefaultRoute = false,
            hasIpv6DefaultRoute = false,
        )

        assertTrue(plan.addDefaultIpv4Route)
        assertTrue(plan.addDefaultIpv6Route)
        assertTrue(plan.allowIpv4)
        assertTrue(plan.allowIpv6)
    }

    @Test
    fun plan_skipsDefaultRoutesWhenExplicitRoutesExist() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = true,
            hasIpv4Address = true,
            hasIpv6Address = true,
            hasIpv4Route = true,
            hasIpv6Route = true,
            hasIpv4DefaultRoute = true,
            hasIpv6DefaultRoute = true,
        )

        assertFalse(plan.addDefaultIpv4Route)
        assertFalse(plan.addDefaultIpv6Route)
        assertTrue(plan.allowIpv4)
        assertTrue(plan.allowIpv6)
    }

    @Test
    fun plan_keepsFamiliesClosedWhenAutoRouteIsOffAndNothingIsConfigured() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = false,
            hasIpv4Address = false,
            hasIpv6Address = false,
            hasIpv4Route = false,
            hasIpv6Route = false,
            hasIpv4DefaultRoute = false,
            hasIpv6DefaultRoute = false,
        )

        assertFalse(plan.addDefaultIpv4Route)
        assertFalse(plan.addDefaultIpv6Route)
        assertFalse(plan.allowIpv4)
        assertFalse(plan.allowIpv6)
    }

    @Test
    fun plan_doesNotAddIpv6DefaultRouteWhenOnlyIpv4TunAddressExists() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = true,
            hasIpv4Address = true,
            hasIpv6Address = false,
            hasIpv4Route = false,
            hasIpv6Route = false,
            hasIpv4DefaultRoute = false,
            hasIpv6DefaultRoute = false,
        )

        assertTrue(plan.addDefaultIpv4Route)
        assertFalse(plan.addDefaultIpv6Route)
        assertTrue(plan.allowIpv4)
        assertFalse(plan.allowIpv6)
    }

    @Test
    fun plan_doesNotAddIpv4DefaultRouteWhenOnlyIpv6TunAddressExists() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = true,
            hasIpv4Address = false,
            hasIpv6Address = true,
            hasIpv4Route = false,
            hasIpv6Route = false,
            hasIpv4DefaultRoute = false,
            hasIpv6DefaultRoute = false,
        )

        assertFalse(plan.addDefaultIpv4Route)
        assertTrue(plan.addDefaultIpv6Route)
        assertFalse(plan.allowIpv4)
        assertTrue(plan.allowIpv6)
    }

    @Test
    fun plan_addsDefaultRouteWhenSpecificRoutesExistButDefaultRouteIsMissing() {
        val plan = AndroidTunRoutePlanner.plan(
            autoRoute = true,
            hasIpv4Address = true,
            hasIpv6Address = false,
            hasIpv4Route = true,
            hasIpv6Route = false,
            hasIpv4DefaultRoute = false,
            hasIpv6DefaultRoute = false,
        )

        assertTrue(plan.addDefaultIpv4Route)
        assertFalse(plan.addDefaultIpv6Route)
        assertTrue(plan.allowIpv4)
        assertFalse(plan.allowIpv6)
    }
}
