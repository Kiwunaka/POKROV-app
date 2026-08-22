package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidLifecycleTaskScopeTest {
    @Test
    fun cancellationFencesLateTasksInterruptsWorkAndRunsHooksOnce() {
        val started = CountDownLatch(1)
        val interrupted = CountDownLatch(1)
        val cancellationCalled = AtomicBoolean(false)
        val lateMutation = AtomicBoolean(false)
        val scope = AndroidLifecycleTaskScope(
            generation = 41L,
            threadNamePrefix = "pokrov-scope-test",
            parallelism = 1,
        )
        scope.onCancel { cancellationCalled.set(true) }
        assertTrue(
            scope.execute {
                started.countDown()
                try {
                    Thread.sleep(30_000L)
                    lateMutation.set(true)
                } catch (_: InterruptedException) {
                    interrupted.countDown()
                }
            },
        )
        assertTrue(started.await(2L, TimeUnit.SECONDS))

        scope.close()
        scope.close()

        assertTrue(interrupted.await(2L, TimeUnit.SECONDS))
        assertTrue(cancellationCalled.get())
        assertFalse(scope.isActive())
        assertFalse(scope.execute { lateMutation.set(true) })
        assertFalse(lateMutation.get())
    }
}
