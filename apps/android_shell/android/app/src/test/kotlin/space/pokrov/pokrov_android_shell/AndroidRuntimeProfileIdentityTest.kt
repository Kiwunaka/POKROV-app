package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidRuntimeProfileIdentityTest {
    @Test
    fun restoredDisplayNodeBelongsOnlyToTheHealthyEffectiveProfile() {
        val digest = "a".repeat(64)
        val stored = runtimeProfileStorageValues(PersistedRuntimeProfile(
            configPath = "/synthetic/profile.json", configDigest = digest,
            routeMode = "device", displayNodeCode = "de",
        ))
        var profile = decodeRuntimeProfileStorage(stored) { true }
        val healthy = mapOf<String, Any?>(
            "phase" to "running", "hostHealth" to "healthy",
            "dnsState" to "healthy", "uplinkState" to "healthy",
            "dns_ready" to true, "core_egress_validated" to true,
            "effectiveProfileDigest" to digest,
        )
        var reads = 0
        fun read(snapshot: Map<String, Any?>) = activeRuntimeDisplayNodeCode(snapshot) {
            reads++; profile
        }
        assertEquals("de", read(healthy))
        profile = profile!!.copy(configDigest = "b".repeat(64), displayNodeCode = "ch")
        assertNull(read(healthy)) // Replaced persisted metadata cannot label the old runtime.
        val replacement = healthy + ("effectiveProfileDigest" to "b".repeat(64))
        assertEquals("ch", read(replacement))
        val completedReads = reads
        assertNull(read(replacement + ("core_egress_validated" to false)))
        assertEquals(completedReads, reads) // An unhealthy snapshot does not read profile storage.
    }

    @Test
    fun samePathCannotSubstituteNewContentOrRouteForAnOldIntent() {
        val content = "{\"route\":{\"final\":\"synthetic-a\"}}"
        val digest = runtimeProfileDigest(content, "selected_apps", true)
        val profile = PersistedRuntimeProfile(
            configPath = "/synthetic/managed-profile.json",
            configDigest = digest,
            routeMode = "selected_apps",
            quickSettingsEligible = true,
            lanScopeVersion = 1,
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
