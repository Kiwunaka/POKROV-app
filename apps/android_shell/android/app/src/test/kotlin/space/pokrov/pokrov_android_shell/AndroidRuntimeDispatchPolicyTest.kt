package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidRuntimeDispatchPolicyTest {
    @Test
    fun initializeQueuesWorkPreservesFailureSnapshotAndFencesLateCallback() {
        val ownerThread = Thread.currentThread()
        val workerThread = AtomicReference<Thread>()
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val callbacks = ConcurrentLinkedQueue<() -> Unit>()
        val firstQueued = CountDownLatch(1)
        val secondQueued = CountDownLatch(1)
        val publications = AtomicInteger(0)
        val failureSnapshot = mapOf<String, Any?>(
            "phase" to "artifactReady",
            "lastFailureKind" to "runtime_initialization_failed",
        )
        val scope = AndroidLifecycleTaskScope(42L, "pokrov-initialize-test", 1)
        try {
            assertTrue(AndroidRuntimeDispatchPolicy.initialize(
                scope = scope,
                postToOwner = { callback -> callbacks.add(callback); firstQueued.countDown() },
                task = {
                    workerThread.set(Thread.currentThread())
                    started.countDown()
                    check(release.await(2L, TimeUnit.SECONDS))
                    failureSnapshot
                },
                complete = { outcome ->
                    assertEquals(failureSnapshot, outcome.getOrThrow())
                    publications.incrementAndGet()
                },
            ))
            assertTrue(started.await(1L, TimeUnit.SECONDS))
            assertFalse(ownerThread === workerThread.get())
            assertTrue(callbacks.isEmpty())
            release.countDown()
            assertTrue(firstQueued.await(1L, TimeUnit.SECONDS))
            callbacks.remove().invoke()
            assertEquals(1, publications.get())

            assertTrue(AndroidRuntimeDispatchPolicy.initialize(
                scope = scope,
                postToOwner = { callback -> callbacks.add(callback); secondQueued.countDown() },
                task = { throw IllegalStateException("synthetic") },
                complete = { publications.incrementAndGet() },
            ))
            assertTrue(secondQueued.await(1L, TimeUnit.SECONDS))
            scope.close()
            callbacks.remove().invoke()
            assertEquals(1, publications.get())
            assertFalse(AndroidRuntimeDispatchPolicy.initialize(
                scope = scope,
                postToOwner = { callbacks.add(it) },
                task = { failureSnapshot },
                complete = { publications.incrementAndGet() },
            ))
        } finally {
            release.countDown()
            scope.close()
        }
    }

    @Test
    fun heldProbeReleasedAfterDestroyCannotMutateOrSubmitToShutdownRuntime() {
        val runtimeExecutor = Executors.newSingleThreadExecutor()
        val probeExecutor = Executors.newSingleThreadExecutor()
        val lifecycleActive = AtomicBoolean(true)
        val activeGeneration = AtomicLong(4L)
        val probeEntered = CountDownLatch(1)
        val releaseProbe = CountDownLatch(1)
        val probeFinished = CountDownLatch(1)
        val stateMutations = AtomicInteger(0)

        probeExecutor.execute {
            probeEntered.countDown()
            releaseProbe.await()
            AndroidRuntimeDispatchPolicy.dispatch(
                executor = runtimeExecutor,
                shouldRun = {
                    lifecycleActive.get() && activeGeneration.get() == 4L
                },
            ) {
                stateMutations.incrementAndGet()
            }
            probeFinished.countDown()
        }

        assertTrue(probeEntered.await(1, TimeUnit.SECONDS))
        lifecycleActive.set(false)
        activeGeneration.incrementAndGet()
        runtimeExecutor.shutdown()
        releaseProbe.countDown()

        assertTrue(probeFinished.await(1, TimeUnit.SECONDS))
        assertTrue(runtimeExecutor.awaitTermination(1, TimeUnit.SECONDS))
        assertTrue(probeExecutor.awaitTerminationAfterShutdown())
        assertFalse(
            AndroidRuntimeDispatchPolicy.dispatch(
                executor = runtimeExecutor,
                shouldRun = { true },
                task = { stateMutations.incrementAndGet() },
            ),
        )
        assertTrue(stateMutations.get() == 0)
    }

    private fun java.util.concurrent.ExecutorService.awaitTerminationAfterShutdown(): Boolean {
        shutdown()
        return awaitTermination(1, TimeUnit.SECONDS)
    }
}
