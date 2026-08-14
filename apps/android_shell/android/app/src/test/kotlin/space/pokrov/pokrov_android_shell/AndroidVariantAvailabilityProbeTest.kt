package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Test

class AndroidVariantAvailabilityProbeTest {
    @After
    fun clearCache() {
        AndroidVariantAvailabilityProbe.clearCacheForTest()
    }

    @Test
    fun parsesOnlyExactPrivateMappingsBackedByProbeGroup() {
        val catalog = requireNotNull(
            AndroidVariantAvailabilityProbe.validateCatalog(
                groupTag = "pokrov-variant-probe",
                finalGroupTag = "select",
                probeMembers = setOf("normal-de", "bridge-mini"),
                targets = validTargets(),
            ),
        )

        assertEquals("pokrov-variant-probe", catalog.groupTag)
        assertEquals("select", catalog.finalGroupTag)
        assertEquals(listOf("direct", "mini"), catalog.targets.map { it.id })
    }

    @Test
    fun rejectsIncompleteOrUnsafeMappings() {
        assertNull(
            AndroidVariantAvailabilityProbe.validateCatalog(
                groupTag = "pokrov-variant-probe",
                finalGroupTag = "select",
                probeMembers = setOf("normal-de", "bridge-mini"),
                targets = listOf(
                    AndroidVariantProbeTarget("direct", "normal-de"),
                    AndroidVariantProbeTarget("../../mini", "bridge-mini"),
                ),
            ),
        )
        assertNull(
            AndroidVariantAvailabilityProbe.validateCatalog(
                groupTag = "pokrov-variant-probe",
                finalGroupTag = "select",
                probeMembers = setOf("normal-de", "bridge-mini"),
                targets = listOf(
                    AndroidVariantProbeTarget("direct", "normal-de"),
                    AndroidVariantProbeTarget("mini", "not-a-member"),
                ),
            ),
        )
    }

    @Test
    fun returnsSafeStatusLatencyFreshnessAndActiveVariantOnly() {
        val catalog = AndroidVariantProbeCatalog(
            groupTag = "pokrov-variant-probe",
            finalGroupTag = "select",
            targets = validTargets(),
        )
        val snapshot = AndroidVariantAvailabilityProbe.buildSnapshot(
            catalog = catalog,
            groups = mapOf(
                "select" to AndroidCoreEgressProbeGroupSnapshot(
                    selected = "bridge-mini",
                    items = mapOf(
                        "normal-de" to null,
                        "bridge-mini" to AndroidCoreEgressProbeSample(1000L, 81),
                    ),
                ),
                "pokrov-variant-probe" to AndroidCoreEgressProbeGroupSnapshot(
                    selected = "normal-de",
                    items = mapOf(
                        "normal-de" to AndroidCoreEgressProbeSample(1001L, 65_535),
                        "bridge-mini" to AndroidCoreEgressProbeSample(1002L, 81),
                    ),
                ),
            ),
            observedAtMs = 2000L,
        )

        assertEquals("mini", snapshot["activeVariantId"])
        val results = snapshot["results"] as List<*>
        assertEquals("unavailable", (results[0] as Map<*, *>)["status"])
        assertEquals("available", (results[1] as Map<*, *>)["status"])
        assertEquals(81, (results[1] as Map<*, *>)["latencyMs"])
        val serialized = snapshot.toString()
        assertFalse(serialized.contains("normal-de"))
        assertFalse(serialized.contains("bridge-mini"))
        assertTrue(serialized.contains("mini"))
    }

    @Test
    fun filtersAOneVariantRefreshWithoutDroppingSafeActiveIdentity() {
        val snapshot = mapOf<String, Any?>(
            "observedAtMs" to 2000L,
            "activeVariantId" to "mini",
            "results" to listOf(
                mapOf("id" to "direct", "status" to "available"),
                mapOf("id" to "mini", "status" to "unavailable"),
            ),
        )

        val filtered = AndroidVariantAvailabilityProbe.filterSnapshot(snapshot, "direct")

        assertEquals("mini", filtered["activeVariantId"])
        val results = filtered["results"] as List<*>
        assertEquals(1, results.size)
        assertEquals("direct", (results.single() as Map<*, *>)["id"])
    }

    @Test
    fun reusesOnlyFreshSnapshotForTheExactCatalogAfterRuntimeStops() {
        val catalog = AndroidVariantProbeCatalog(
            groupTag = "pokrov-variant-probe",
            finalGroupTag = "select",
            targets = validTargets(),
        )
        val snapshot = mapOf<String, Any?>(
            "observedAtMs" to 1_000L,
            "activeVariantId" to "mini",
            "results" to listOf(
                mapOf("id" to "direct", "status" to "unavailable"),
                mapOf("id" to "mini", "status" to "available", "latencyMs" to 81),
            ),
        )
        AndroidVariantAvailabilityProbe.rememberForTest(
            catalog = catalog,
            snapshot = snapshot,
            capturedAtMs = 10_000L,
        )

        val cached = requireNotNull(
            AndroidVariantAvailabilityProbe.cachedSnapshotForTest(catalog, 20_000L),
        )
        assertEquals("", cached["activeVariantId"])
        assertEquals(true, cached["fromCache"])
        assertNull(
            AndroidVariantAvailabilityProbe.cachedSnapshotForTest(
                catalog.copy(groupTag = "other-probe"),
                20_000L,
            ),
        )
        assertNull(
            AndroidVariantAvailabilityProbe.cachedSnapshotForTest(catalog, 130_001L),
        )
    }

    @Test
    fun waitsUntilEveryVariantHasAFreshTerminalSample() {
        val catalog = AndroidVariantProbeCatalog(
            groupTag = "pokrov-variant-probe",
            finalGroupTag = "select",
            targets = validTargets(),
        )
        val partial = AndroidCoreEgressProbeGroupSnapshot(
            selected = "normal-de",
            items = mapOf(
                "normal-de" to AndroidCoreEgressProbeSample(121_000L, 65_535),
                "bridge-mini" to AndroidCoreEgressProbeSample(1_000L, 81),
            ),
        )
        val complete = partial.copy(
            items = partial.items +
                ("bridge-mini" to AndroidCoreEgressProbeSample(121_001L, 74)),
        )

        assertFalse(
            AndroidVariantAvailabilityProbe.hasFreshSamples(catalog, partial, 121_001L),
        )
        assertTrue(
            AndroidVariantAvailabilityProbe.hasFreshSamples(catalog, complete, 121_001L),
        )
    }

    private fun validTargets(): List<AndroidVariantProbeTarget> = listOf(
        AndroidVariantProbeTarget("direct", "normal-de"),
        AndroidVariantProbeTarget("mini", "bridge-mini"),
    )
}
