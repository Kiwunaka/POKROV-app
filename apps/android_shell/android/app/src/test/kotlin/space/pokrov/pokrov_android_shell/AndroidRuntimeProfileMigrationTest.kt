package space.pokrov.pokrov_android_shell

import java.util.Properties
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidRuntimeProfileMigrationTest {
    @Test
    fun legacyFixtureMigratesIdempotentlyToCurrentSchema() {
        val legacy = loadLegacyFixture()

        assertEquals(RuntimeProfileSchemaRoute.LEGACY_V0, runtimeProfileSchemaRoute(legacy))
        val decoded = decodeRuntimeProfileStorage(legacy) { true }
        assertEquals(
            PersistedRuntimeProfile(
                configPath = "C:\\fixture\\pokrov-runtime.json",
                routeMode = "allExceptRu",
                quickSettingsEligible = true,
                coreEgressProbeRequired = true,
                displayCountry = "Netherlands",
                displayNodeCode = "nl-fixture-01",
                displayRouteMode = "all_except_ru",
            ),
            decoded,
        )

        val migrated = runtimeProfileStorageValues(decoded!!)
        assertEquals(RuntimeProfileSchemaRoute.CURRENT_V1, runtimeProfileSchemaRoute(migrated))
        val secondDecode = decodeRuntimeProfileStorage(migrated) { true }
        assertEquals(decoded, secondDecode)
        assertEquals(migrated, runtimeProfileStorageValues(secondDecode!!))
    }

    @Test
    fun missingLegacySafetyMetadataDefaultsFailClosed() {
        val decoded = decodeRuntimeProfileStorage(
            mapOf("config_path" to "C:\\fixture\\legacy-minimal.json"),
        ) { true }

        assertEquals(false, decoded?.quickSettingsEligible)
        assertEquals(true, decoded?.coreEgressProbeRequired)
        assertEquals(false, decoded?.canStartFromQuickSettings())
    }

    @Test
    fun futureAndMalformedSchemasAreRejectedWithoutMigration() {
        val future = loadLegacyFixture() + ("schema_version" to 2)
        val malformed = loadLegacyFixture() + ("schema_version" to "1")

        assertEquals(RuntimeProfileSchemaRoute.FORWARD_UNKNOWN, runtimeProfileSchemaRoute(future))
        assertNull(decodeRuntimeProfileStorage(future) { true })
        assertEquals(RuntimeProfileSchemaRoute.FORWARD_UNKNOWN, runtimeProfileSchemaRoute(malformed))
        assertNull(decodeRuntimeProfileStorage(malformed) { true })
        assertEquals(2, future["schema_version"])
    }

    private fun loadLegacyFixture(): Map<String, Any> {
        val properties = Properties()
        val stream = checkNotNull(
            javaClass.classLoader?.getResourceAsStream("runtime-profile-v0.properties"),
        )
        stream.use { properties.load(it) }
        return properties.entries.associate { (rawKey, rawValue) ->
            val key = rawKey.toString()
            val value = rawValue.toString()
            key to when (key) {
                "quick_settings_eligible", "core_egress_probe_required" -> value.toBooleanStrict()
                else -> value
            }
        }
    }
}
