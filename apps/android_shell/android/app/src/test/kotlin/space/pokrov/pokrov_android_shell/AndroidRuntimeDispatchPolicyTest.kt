package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidRuntimeDispatchPolicyTest {
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
