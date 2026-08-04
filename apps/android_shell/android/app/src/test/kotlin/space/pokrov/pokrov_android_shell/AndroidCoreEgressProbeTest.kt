package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidCoreEgressProbeTest {
    @Test
    fun rejectsUnsafeOrUnboundedTags() {
        assertTrue(AndroidCoreEgressProbe.isSafeTag("auto-selector"))
        assertFalse(AndroidCoreEgressProbe.isSafeTag(""))
        assertFalse(AndroidCoreEgressProbe.isSafeTag("x".repeat(129)))
        assertFalse(AndroidCoreEgressProbe.isSafeTag("bad\u0000tag"))
    }

    @Test
    fun missingFinalGroupHasNoProbeTarget() {
        assertNull(AndroidCoreEgressProbe.finalGroupTag("{\"route\":{}}"))
        assertNull(AndroidCoreEgressProbe.finalGroupTag("{}"))
    }

    @Test
    fun acceptsOnlySelectableGroupTypes() {
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType("selector"))
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType(" URLTEST "))
        assertFalse(AndroidCoreEgressProbe.isSelectableGroupType("vless"))
    }

    @Test
    fun rejectsCoreTimeoutSentinelAsFailedEgress() {
        assertTrue(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 84))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 0L, delay = 84))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 0))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 65_535))
    }

    @Test
    fun resolvesNonSelectableUrltestFinalToItsSelectedLeaf() {
        val sample = AndroidCoreEgressProbeSample(time = 123L, delay = 84)
        val selection = AndroidCoreEgressProbe.resolveSelectedOutbound(
            groups = mapOf(
                "auto" to AndroidCoreEgressProbeGroupSnapshot(
                    selected = "node-1",
                    items = mapOf("node-1" to sample, "node-2" to null),
                ),
            ),
            rootGroupTag = "auto",
        )

        assertEquals(
            AndroidCoreEgressProbeSelection(
                groupTag = "auto",
                outboundTag = "node-1",
                sample = sample,
            ),
            selection,
        )
    }

    @Test
    fun resolvesNestedSelectorToTheUrltestThatOwnsSelectedLeaf() {
        val sample = AndroidCoreEgressProbeSample(time = 456L, delay = 95)
        val selection = AndroidCoreEgressProbe.resolveSelectedOutbound(
            groups = mapOf(
                "select" to AndroidCoreEgressProbeGroupSnapshot(
                    selected = "auto",
                    items = mapOf("auto" to null, "node-1" to sample),
                ),
                "auto" to AndroidCoreEgressProbeGroupSnapshot(
                    selected = "node-1",
                    items = mapOf("node-1" to sample),
                ),
            ),
            rootGroupTag = "select",
        )

        assertEquals(
            AndroidCoreEgressProbeSelection(
                groupTag = "auto",
                outboundTag = "node-1",
                sample = sample,
            ),
            selection,
        )
    }

    @Test
    fun rejectsCyclicGroupSelection() {
        assertNull(
            AndroidCoreEgressProbe.resolveSelectedOutbound(
                groups = mapOf(
                    "select" to AndroidCoreEgressProbeGroupSnapshot(
                        selected = "auto",
                        items = mapOf("auto" to null),
                    ),
                    "auto" to AndroidCoreEgressProbeGroupSnapshot(
                        selected = "select",
                        items = mapOf("select" to null),
                    ),
                ),
                rootGroupTag = "select",
            ),
        )
    }
}
