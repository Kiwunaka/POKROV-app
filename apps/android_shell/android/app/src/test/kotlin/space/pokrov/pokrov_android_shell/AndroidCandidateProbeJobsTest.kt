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
            jobs.publish("reply_pending") { publishedCancellation = it.get() }
            assertTrue(publishedCancellation)
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
