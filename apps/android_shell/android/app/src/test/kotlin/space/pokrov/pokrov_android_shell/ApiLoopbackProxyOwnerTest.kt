package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ApiLoopbackProxyOwnerTest {
    @Test
    fun cancelledLateStartCannotStopNewOwner() {
        val owner = ApiLoopbackProxyOwner()
        val oldBridge = Any()
        val newBridge = Any()
        val oldActive = AtomicBoolean(true)
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val stops = AtomicInteger()
        val executor = Executors.newFixedThreadPool(2)
        try {
            val old = executor.submit<Int?> {
                owner.start(oldBridge, { oldActive.get() }, {
                    started.countDown()
                    check(release.await(3, TimeUnit.SECONDS))
                    101
                }, { stops.incrementAndGet() })
            }
            assertTrue(started.await(3, TimeUnit.SECONDS))
            oldActive.set(false)
            val current = executor.submit<Int?> {
                owner.start(newBridge, { true }, { 202 }, { stops.incrementAndGet() })
            }
            release.countDown()
            assertNull(old.get(3, TimeUnit.SECONDS))
            assertEquals(202, current.get(3, TimeUnit.SECONDS))
            owner.close(oldBridge) { stops.incrementAndGet() }
            assertEquals(1, stops.get())
            assertEquals(202, owner.start(newBridge, { true }, { error("started twice") }, { stops.incrementAndGet() }))
            owner.close(newBridge) { stops.incrementAndGet() }
            assertEquals(2, stops.get())
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun closingPreviousOwnerDoesNotStopReplacement() {
        val owner = ApiLoopbackProxyOwner()
        val oldBridge = Any()
        val newBridge = Any()
        var stops = 0
        assertEquals(101, owner.start(oldBridge, { true }, { 101 }, { stops++ }))
        assertEquals(202, owner.start(newBridge, { true }, { 202 }, { stops++ }))
        owner.close(oldBridge) { stops++ }
        assertEquals(1, stops)
        owner.close(newBridge) { stops++ }
        assertEquals(2, stops)
    }
}
