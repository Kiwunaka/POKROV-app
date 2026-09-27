package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class AndroidProtectedHandoffTest {
    @Test
    fun failedReloadAndCancellationRetainProtectionUntilExplicitStop() {
        val owner = AndroidProtectedHandoff()
        assertTrue(owner.begin("first"))
        assertFalse(owner.begin("parallel"))
        assertFalse(owner.cancel("stale"))
        try {
            owner.publishTun<Unit> { error("reload failed") }
        } catch (_: IllegalStateException) { }
        owner.settle("first")
        assertTrue(owner.retainsTun)
        assertTrue(owner.begin("retry"))
        assertTrue(owner.cancel("retry"))
        var published = false
        try {
            owner.publishTun { published = true }
            fail("Cancelled replacement published a TUN")
        } catch (_: IllegalStateException) { }
        assertFalse(published)
        owner.settle("retry")
        assertTrue(owner.retainsTun)
        assertTrue(owner.begin("next"))
        assertFalse(owner.isCancelled("retry"))
        assertFalse(owner.cancel("retry"))
        owner.release()
        assertFalse(owner.retainsTun)
        assertFalse(owner.cancel("retry"))
    }

    @Test
    fun cancellationCannotAcknowledgeBeforeInFlightTunPublicationSettles() {
        val owner = AndroidProtectedHandoff()
        owner.begin("replacement")
        val establishing = CountDownLatch(1)
        val published = CountDownLatch(1)
        val cancellationReturned = CountDownLatch(1)
        val publisher = Thread {
            owner.publishTun {
                establishing.countDown()
                assertTrue(published.await(2, TimeUnit.SECONDS))
            }
        }.apply { start() }
        assertTrue(establishing.await(2, TimeUnit.SECONDS))
        val canceller = Thread {
            owner.cancel("replacement")
            cancellationReturned.countDown()
        }.apply { start() }
        assertFalse(cancellationReturned.await(30, TimeUnit.MILLISECONDS))
        published.countDown()
        assertTrue(cancellationReturned.await(2, TimeUnit.SECONDS))
        publisher.join()
        canceller.join()
        assertTrue(owner.retainsTun)
        assertFalse(owner.owns("replacement"))
    }
}
