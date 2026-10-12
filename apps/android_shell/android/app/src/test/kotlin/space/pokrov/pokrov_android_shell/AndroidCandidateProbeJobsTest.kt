package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.*
import org.junit.Test

class AndroidCandidateProbeJobsTest {
    @Test
    fun completedNativeWorkerRemainsCancellableUntilUiPublication() {
        val jobs = AndroidCandidateProbeJobs()
        try {
            assertTrue(jobs.start("reply_pending") {})
            val worker = jobs.cancel("reply_pending")!!
            worker.awaitFinished()
            assertNotNull(jobs.cancel("reply_pending"))
            var publishedCancellation = false
            var published: Map<String, Any>? = null
            val probeError = mapOf("operation" to "read_headers", "cause" to "closed", "cancel_state" to "cancelled",
                "target" to "owned_reserve", "request" to "egress_204", "elapsed_ms" to 100L,
                "stage_started_ms" to 11_900L, "duration_ms" to 12_000L)
            val nativeDiagnostic = AndroidCandidateProbeDiagnostic.fromNativeFields(
                "proxy_dial", 7L, 12_000L,
                probeError = probeError,
            )
            jobs.publish("reply_pending") {
                publishedCancellation = it.get()
                if (publishedCancellation) published = nativeDiagnostic.cancelledResponse(12_034L)
            }
            assertTrue(publishedCancellation)
            assertEquals("proxy_dial", published!!["stage"])
            assertEquals(false, published!!["success"])
            assertEquals("cancelled", published!!["failure_kind"])
            assertEquals(12_034L, published!!["duration_ms"])
            assertEquals(probeError, published!!["probe_error"])
            assertEquals(setOf("success", "failure_kind", "duration_ms", "stage", "probe_error"), published!!.keys)
            assertFalse(AndroidCandidateProbeDiagnostic.fromNativeFields(
                "http_204", 7L, 12_000L, probeError = probeError + ("raw_error" to "sensitive-host")
            ).cancelledResponse(12_034L).containsKey("probe_error"))
            assertFalse(AndroidCandidateProbeDiagnostic.fromNativeFields(
                "not-an-allowed-phase", 7L, 12_000L,
            ).cancelledResponse(12_034L).containsKey("stage"))
            assertNull(jobs.cancel("reply_pending"))
        } finally {
            jobs.close()
        }
    }

    @Test
    fun threeIndependentProbesOwnSlotsUntilNativeCloseReturns() {
        val jobs = AndroidCandidateProbeJobs()
        val started = CountDownLatch(3)
        val nativeClose = CountDownLatch(1)
        val cancelled = CountDownLatch(1)
        try {
            repeat(3) { index ->
                assertTrue(jobs.start("probe$index") { flag ->
                    started.countDown()
                    while (!flag.get()) Thread.yield()
                    cancelled.countDown()
                    nativeClose.await()
                })
            }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            assertFalse(jobs.start("fourth") {})
            val first = jobs.cancel("probe0")!!
            assertTrue(cancelled.await(2, TimeUnit.SECONDS))
            val joined = CountDownLatch(1)
            val waiter = Thread { first.awaitFinished(); joined.countDown() }.apply { start() }
            assertFalse(joined.await(30, TimeUnit.MILLISECONDS))
            assertFalse(jobs.start("probe0") {})
            nativeClose.countDown()
            assertTrue(joined.await(2, TimeUnit.SECONDS))
            waiter.join()
        } finally {
            nativeClose.countDown()
            jobs.close()
        }
    }

    @Test
    fun cancellationBeforeNativeRegistrationAndBridgeCloseRemainVisible() {
        val jobs = AndroidCandidateProbeJobs()
        val nativeRegistration = CountDownLatch(1)
        val observed = AtomicBoolean(false)
        assertTrue(jobs.start("probe") { flag ->
            nativeRegistration.await()
            observed.set(flag.get())
        })
        val job = jobs.cancel("probe")!!
        jobs.close()
        assertFalse(jobs.start("late") {})
        nativeRegistration.countDown()
        job.awaitFinished()
        assertTrue(observed.get())
    }
}
