package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidCoreEgressProbeTest {
    @Test
    fun endpointFailureGetsBoundedRetriesWhileGroupFailureRemainsTerminal() {
        val endpoint = AndroidCoreEgressProbeTarget(
            tag = "pokrov-warp",
            kind = AndroidCoreEgressProbeTargetKind.ENDPOINT,
        )
        val group = AndroidCoreEgressProbeTarget(
            tag = "proxy",
            kind = AndroidCoreEgressProbeTargetKind.GROUP,
        )

        assertTrue(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                endpoint,
                AndroidCoreEgressProbeResult.FAILED,
                completedAttempts = 1,
            ),
        )
        assertFalse(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                group,
                AndroidCoreEgressProbeResult.FAILED,
                completedAttempts = 1,
            ),
        )
        assertTrue(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                group,
                AndroidCoreEgressProbeResult.UNAVAILABLE,
                completedAttempts = 1,
            ),
        )
        assertFalse(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                endpoint,
                AndroidCoreEgressProbeResult.TIMED_OUT,
                completedAttempts = 1,
            ),
        )
        assertTrue(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                endpoint,
                AndroidCoreEgressProbeResult.FAILED,
                completedAttempts = 2,
            ),
        )
        assertFalse(
            AndroidCoreEgressRetryPolicy.shouldRetry(
                endpoint,
                AndroidCoreEgressProbeResult.FAILED,
                completedAttempts = 3,
            ),
        )
    }

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
    fun resolvesSelectableFinalAsGroupProbeTarget() {
        assertEquals(
            AndroidCoreEgressProbeTarget(
                tag = "select",
                kind = AndroidCoreEgressProbeTargetKind.GROUP,
            ),
            AndroidCoreEgressProbe.resolveFinalTarget(
                finalTag = "select",
                outboundTypes = mapOf("select" to "selector"),
                endpointTypes = emptyMap(),
            ),
        )
    }

    @Test
    fun resolvesWarpFinalAsEndpointProbeTarget() {
        assertEquals(
            AndroidCoreEgressProbeTarget(
                tag = "pokrov-warp",
                kind = AndroidCoreEgressProbeTargetKind.ENDPOINT,
            ),
            AndroidCoreEgressProbe.resolveFinalTarget(
                finalTag = "pokrov-warp",
                outboundTypes = mapOf("direct" to "direct"),
                endpointTypes = mapOf("pokrov-warp" to "warp"),
            ),
        )
        assertNull(
            AndroidCoreEgressProbe.resolveFinalTarget(
                finalTag = "mesh",
                outboundTypes = emptyMap(),
                endpointTypes = mapOf("mesh" to "tailscale"),
            ),
        )
    }

    @Test
    fun acceptsOnlySelectableGroupTypes() {
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType("selector"))
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType(" URLTEST "))
        assertFalse(AndroidCoreEgressProbe.isSelectableGroupType("vless"))
        assertTrue(AndroidCoreEgressProbe.isProbeableEndpointType(" WARP "))
        assertFalse(AndroidCoreEgressProbe.isProbeableEndpointType("wireguard"))
    }

    @Test
    fun rejectsCoreTimeoutSentinelAsFailedEgress() {
        assertTrue(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 84))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 0L, delay = 84))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 0))
        assertFalse(AndroidCoreEgressProbe.isHealthySample(time = 1L, delay = 65_535))
    }

    @Test
    fun convertsCoreUnixSecondsToPublicMilliseconds() {
        assertEquals(
            1_786_716_000_000L,
            AndroidCoreEgressProbe.urlTestTimeMillis(1_786_716_000L),
        )
        assertEquals(0L, AndroidCoreEgressProbe.urlTestTimeMillis(0L))
        assertEquals(0L, AndroidCoreEgressProbe.urlTestTimeMillis(Long.MAX_VALUE))
    }

    @Test
    fun recognizesEndpointResultsFromCommandLogAndPlatformDebugChannel() {
        assertEquals(
            AndroidCoreEgressProbeResult.HEALTHY,
            AndroidCoreEgressProbe.endpointResultFromMessage(
                "selected endpoint URL test succeeded",
            ),
        )
        assertEquals(
            AndroidCoreEgressProbeResult.HEALTHY,
            AndroidCoreEgressProbe.endpointResultFromMessage(
                "selected_endpoint_url_test:healthy",
            ),
        )
        assertEquals(
            AndroidCoreEgressProbeResult.FAILED,
            AndroidCoreEgressProbe.endpointResultFromMessage(
                "selected_endpoint_url_test:endpoint_initialization_http_rejected",
            ),
        )
        assertNull(AndroidCoreEgressProbe.endpointResultFromMessage("unrelated"))
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
