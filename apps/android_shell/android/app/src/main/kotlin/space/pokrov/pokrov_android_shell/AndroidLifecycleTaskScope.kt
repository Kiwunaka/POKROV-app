package space.pokrov.pokrov_android_shell

import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ExecutorService
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadFactory
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Bounded parent scope for Android host work that must end with one lifecycle.
 *
 * Tasks are accepted only while the scope is active. Cancellation fences late
 * callbacks first, interrupts queued/running JVM work, then invokes registered
 * native/network cancellation hooks. It deliberately does not own Android UI
 * state; callers still check that this exact scope is current before mutation.
 */
internal class AndroidLifecycleTaskScope(
    val generation: Long,
    threadNamePrefix: String,
    parallelism: Int,
    queueCapacity: Int = DEFAULT_QUEUE_CAPACITY,
    executorFactory: ((ThreadFactory) -> ExecutorService)? = null,
) : AutoCloseable {
    private val active = AtomicBoolean(true)
    private val cancellationLock = Any()
    private val cancellationActions = mutableListOf<() -> Unit>()
    private val threadSequence = AtomicLong(0L)
    private val threadFactory = ThreadFactory { task ->
        Thread(task, "$threadNamePrefix-${threadSequence.incrementAndGet()}").apply {
            isDaemon = true
        }
    }
    private val executor = executorFactory?.invoke(threadFactory)
        ?: ThreadPoolExecutor(
            parallelism,
            parallelism,
            0L,
            TimeUnit.MILLISECONDS,
            ArrayBlockingQueue(queueCapacity),
            threadFactory,
            ThreadPoolExecutor.AbortPolicy(),
        )

    fun isActive(): Boolean = active.get()

    fun execute(task: () -> Unit): Boolean {
        if (!active.get()) {
            return false
        }
        return try {
            executor.execute {
                if (active.get()) {
                    task()
                }
            }
            true
        } catch (_: RejectedExecutionException) {
            false
        }
    }

    fun onCancel(action: () -> Unit) {
        val invokeNow = synchronized(cancellationLock) {
            if (active.get()) {
                cancellationActions += action
                false
            } else {
                true
            }
        }
        if (invokeNow) {
            runCatching(action)
        }
    }

    override fun close() {
        if (!active.compareAndSet(true, false)) {
            return
        }
        executor.shutdownNow()
        val actions = synchronized(cancellationLock) {
            cancellationActions.asReversed().toList().also { cancellationActions.clear() }
        }
        actions.forEach { action -> runCatching(action) }
    }

    private companion object {
        const val DEFAULT_QUEUE_CAPACITY = 32
    }
}
