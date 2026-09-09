package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidCoreEgressProbeTest {
    class CallBoundCore {
        val startedA = java.util.concurrent.CountDownLatch(1)
        val startedB = java.util.concurrent.CountDownLatch(1)
        val releaseA = java.util.concurrent.CountDownLatch(1)
        val releaseB = java.util.concurrent.CountDownLatch(1)

        fun probeSelectedOutbound(tag: String): Boolean = probeEndpoint(tag)

        fun probeEndpoint(tag: String): Boolean {
            if (tag == "target-a") {
                startedA.countDown()
                check(releaseA.await(3, java.util.concurrent.TimeUnit.SECONDS))
                return true
            }
            startedB.countDown()
            check(releaseB.await(3, java.util.concurrent.TimeUnit.SECONDS))
            return false
        }
    }

    @Test
    fun delayedSuccessCannotConfirmReplacementProbe() {
        for (kind in AndroidCoreEgressProbeTargetKind.values()) {
            val core = CallBoundCore()
            val results = java.util.concurrent.ConcurrentHashMap<String, AndroidCoreEgressProbeResult>()
            val a = Thread { results["a"] = AndroidCoreEgressProbe.resultFromCore(core, AndroidCoreEgressProbeTarget("target-a", kind)) }
            val b = Thread { results["b"] = AndroidCoreEgressProbe.resultFromCore(core, AndroidCoreEgressProbeTarget("target-b", kind)) }
            try {
                a.start()
                assertTrue(core.startedA.await(1, java.util.concurrent.TimeUnit.SECONDS))
                b.start()
                assertTrue(core.startedB.await(1, java.util.concurrent.TimeUnit.SECONDS))
                core.releaseA.countDown()
                a.join(1000)
                assertEquals(AndroidCoreEgressProbeResult.HEALTHY, results["a"])
                assertNull("Late A success must not settle B", results["b"])
                core.releaseB.countDown()
                b.join(1000)
                assertEquals(AndroidCoreEgressProbeResult.FAILED, results["b"])
            } finally {
                core.releaseA.countDown()
                core.releaseB.countDown()
                a.join(1000)
                b.join(1000)
            }
            }
    }

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
    fun resolvesAwgFinalAsEndpointProbeTarget() {
        assertEquals(
            AndroidCoreEgressProbeTarget(
                tag = "pokrov-awg31",
                kind = AndroidCoreEgressProbeTargetKind.ENDPOINT,
                keepRuntimeOnFailure = true,
                captureSafeFailureCategory = true,
            ),
            AndroidCoreEgressProbe.resolveFinalTarget(
                finalTag = "pokrov-awg31",
                outboundTypes = mapOf("direct" to "direct"),
                endpointTypes = mapOf("pokrov-awg31" to "awg"),
            ),
        )
    }

    @Test
    fun acceptsOnlySelectableGroupTypes() {
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType("selector"))
        assertTrue(AndroidCoreEgressProbe.isSelectableGroupType(" URLTEST "))
        assertFalse(AndroidCoreEgressProbe.isSelectableGroupType("vless"))
        assertTrue(AndroidCoreEgressProbe.isProbeableEndpointType(" WARP "))
        assertTrue(AndroidCoreEgressProbe.isProbeableEndpointType(" AWG "))
        assertFalse(AndroidCoreEgressProbe.isProbeableEndpointType("wireguard"))
    }

    class BrokenCore {
        fun probeEndpoint(@Suppress("UNUSED_PARAMETER") tag: String): Boolean = error("synthetic private failure")
    }

    @Test
    fun missingOrFailingPerCallApiCannotProveHealth() {
        for (kind in AndroidCoreEgressProbeTargetKind.values()) {
            for (core in listOf(null, Any(), BrokenCore())) {
                assertEquals(AndroidCoreEgressProbeResult.UNAVAILABLE,
                    AndroidCoreEgressProbe.resultFromCore(core, AndroidCoreEgressProbeTarget("target", kind)))
            }
        }
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
