package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidRuntimeProfileIdentityTest {
    @Test
    fun samePathCannotSubstituteNewContentOrRouteForAnOldIntent() {
        val content = "{\"route\":{\"final\":\"synthetic-a\"}}"
        val digest = runtimeProfileDigest(content, "selected_apps", true)
        val profile = PersistedRuntimeProfile(
            configPath = "/synthetic/managed-profile.json",
            configDigest = digest,
            routeMode = "selected_apps",
            quickSettingsEligible = true,
        )
        assertTrue(runtimeProfileMatchesIntent(profile, digest, profile.configPath, profile.routeMode, content))
        assertFalse(runtimeProfileMatchesIntent(profile, digest, profile.configPath, profile.routeMode, "{}"))
        assertFalse(runtimeProfileMatchesIntent(profile, digest, profile.configPath, "device", content))
        assertFalse(runtimeProfileMatchesIntent(profile, "", profile.configPath, profile.routeMode, content))
        assertFalse(runtimeProfileMatchesIntent(profile.copy(configDigest = "0".repeat(64)), digest, profile.configPath, profile.routeMode, content))
        assertNotEquals(digest, runtimeProfileDigest(content, profile.routeMode, false))
        assertTrue(profile.canStartFromQuickSettings())
        assertFalse(profile.copy(configDigest = "").canStartFromQuickSettings())
    }
}
