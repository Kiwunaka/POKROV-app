package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidTunPackagePlannerTest {
    @Test
    fun `full tunnel excludes the VPN host process`() {
        val plan = AndroidTunPackagePlanner.plan(
            appPackage = "space.pokrov.pokrov_android_shell",
            includedPackages = emptyList(),
            excludedPackages = emptyList(),
        )

        assertEquals(emptyList<String>(), plan.allowedPackages)
        assertEquals(
            listOf("space.pokrov.pokrov_android_shell"),
            plan.disallowedPackages,
        )
    }

    @Test
    fun `selected apps uses allow-list without mixing disallowed packages`() {
        val plan = AndroidTunPackagePlanner.plan(
            appPackage = "space.pokrov.pokrov_android_shell",
            includedPackages = listOf("com.example.browser", "com.example.browser"),
            excludedPackages = listOf("com.example.mail"),
        )

        assertEquals(listOf("com.example.browser"), plan.allowedPackages)
        assertEquals(emptyList<String>(), plan.disallowedPackages)
    }

    @Test
    fun `selected apps rejects an empty allow-list instead of falling back to all apps`() {
        val plan = AndroidTunPackagePlanner.plan(
            appPackage = "space.pokrov.pokrov_android_shell",
            includedPackages = emptyList(),
            excludedPackages = emptyList(),
            selectedAppsMode = true,
        )

        assertEquals(false, plan.isValid)
        assertEquals(emptyList<String>(), plan.allowedPackages)
        assertEquals(emptyList<String>(), plan.disallowedPackages)
    }

    @Test
    fun `selected apps rejects a requested allow-list when none is applied`() {
        val plan = AndroidTunPackagePlanner.plan(
            appPackage = "space.pokrov.pokrov_android_shell",
            includedPackages = listOf("com.example.selected"),
            excludedPackages = emptyList(),
            selectedAppsMode = true,
        )

        assertEquals(true, plan.isValid)
        assertEquals(
            false,
            AndroidTunPackagePlanner.hasRequiredAppliedAllowList(
                selectedAppsMode = true,
                appliedAllowedPackageCount = 0,
            ),
        )
    }

    @Test
    fun `selected apps permits a requested allow-list when an app is applied`() {
        assertEquals(
            true,
            AndroidTunPackagePlanner.hasRequiredAppliedAllowList(
                selectedAppsMode = true,
                appliedAllowedPackageCount = 1,
            ),
        )
    }

    @Test
    fun `full tunnel merges requested exclusions with the host process`() {
        val plan = AndroidTunPackagePlanner.plan(
            appPackage = "space.pokrov.pokrov_android_shell",
            includedPackages = emptyList(),
            excludedPackages = listOf(
                "com.example.mail",
                "space.pokrov.pokrov_android_shell",
                " ",
            ),
        )

        assertEquals(
            listOf(
                "space.pokrov.pokrov_android_shell",
                "com.example.mail",
            ),
            plan.disallowedPackages,
        )
    }
}
