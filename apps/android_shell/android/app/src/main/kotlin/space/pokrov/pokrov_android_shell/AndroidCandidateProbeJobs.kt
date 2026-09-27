package space.pokrov.pokrov_android_shell

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** A slot remains owned until the blocking native call has closed its IO and returned. */
internal class AndroidCandidateProbeJobs : AutoCloseable {
    internal class Job {
        val cancelled = AtomicBoolean(false)
        private val finished = CountDownLatch(1)
        var replyFinished = false
        var nativeFinished = false
        fun awaitFinished() = finished.await()
        fun finish() = finished.countDown()
    }

    private val lock = Any()
    private val jobs = mutableMapOf<String, Job>()
    private var closed = false
    private val workers = Executors.newFixedThreadPool(3) { task ->
        Thread(task, "pokrov-candidate-probe").apply { isDaemon = true }
    }

    fun start(id: String, work: (AtomicBoolean) -> Unit): Boolean = synchronized(lock) {
        if (closed || jobs.size >= 3 || jobs.containsKey(id)) return false
        val job = Job()
        jobs[id] = job
        workers.execute {
            try {
                work(job.cancelled)
            } finally {
                synchronized(lock) {
                    job.nativeFinished = true
                    job.finish()
                    if (closed || job.replyFinished) jobs.remove(id)
                }
            }
        }
        true
    }

    fun cancel(id: String): Job? = synchronized(lock) {
        jobs[id]?.also { it.cancelled.set(true) }
    }

    fun publish(id: String, reply: (AtomicBoolean) -> Unit) = synchronized(lock) {
        val job = jobs[id] ?: return@synchronized
        try {
            reply(job.cancelled)
        } finally {
            job.replyFinished = true
            if (job.nativeFinished) jobs.remove(id)
        }
    }

    override fun close() = synchronized(lock) {
        closed = true
        jobs.values.forEach { it.cancelled.set(true) }
        jobs.entries.removeAll { it.value.nativeFinished }
        // Do not discard queued work: each accepted job must settle its latch.
        workers.shutdown()
    }
}
