package space.pokrov.pokrov_android_shell

import android.os.SystemClock
import java.math.BigInteger
import space.pokrov.core.libbox.CommandClientHandler
import space.pokrov.core.libbox.CommandClientOptions
import space.pokrov.core.libbox.ConnectionEvents
import space.pokrov.core.libbox.Libbox
import space.pokrov.core.libbox.LogIterator
import space.pokrov.core.libbox.OutboundGroupIterator
import space.pokrov.core.libbox.StatusMessage
import space.pokrov.core.libbox.StringIterator

internal enum class AndroidTunnelTrafficSampleState(val wireValue: String) {
    UNAVAILABLE("unavailable"),
    WARMING("warming"),
    AVAILABLE("available"),
    RESET("reset"),
    OVERFLOW("overflow"),
}

internal data class AndroidTunnelTrafficSnapshot(
    val state: AndroidTunnelTrafficSampleState,
    val uplinkBps: Long? = null,
    val downlinkBps: Long? = null,
    val uplinkTotalBytes: Long? = null,
    val downlinkTotalBytes: Long? = null,
) {
    val available: Boolean
        get() = state != AndroidTunnelTrafficSampleState.UNAVAILABLE

    companion object {
        val unavailable = AndroidTunnelTrafficSnapshot(
            state = AndroidTunnelTrafficSampleState.UNAVAILABLE,
        )
    }
}

/** Converts monotonic Core tunnel totals into session-only transfer rates. */
internal class AndroidTunnelTrafficTracker(
    private val monotonicNanos: () -> Long = SystemClock::elapsedRealtimeNanos,
) {
    private var previousUplinkTotal: Long? = null
    private var previousDownlinkTotal: Long? = null
    private var previousSampleNanos: Long? = null

    @Synchronized
    fun update(
        trafficAvailable: Boolean,
        uplinkTotalBytes: Long,
        downlinkTotalBytes: Long,
    ): AndroidTunnelTrafficSnapshot {
        if (!trafficAvailable || uplinkTotalBytes < 0L || downlinkTotalBytes < 0L) {
            reset()
            return AndroidTunnelTrafficSnapshot.unavailable
        }

        val now = monotonicNanos()
        val priorUplink = previousUplinkTotal
        val priorDownlink = previousDownlinkTotal
        val priorNanos = previousSampleNanos
        previousUplinkTotal = uplinkTotalBytes
        previousDownlinkTotal = downlinkTotalBytes
        previousSampleNanos = now

        if (priorUplink == null || priorDownlink == null || priorNanos == null) {
            return AndroidTunnelTrafficSnapshot(
                state = AndroidTunnelTrafficSampleState.WARMING,
                uplinkTotalBytes = uplinkTotalBytes,
                downlinkTotalBytes = downlinkTotalBytes,
            )
        }
        if (uplinkTotalBytes < priorUplink || downlinkTotalBytes < priorDownlink) {
            return AndroidTunnelTrafficSnapshot(
                state = AndroidTunnelTrafficSampleState.RESET,
                uplinkTotalBytes = uplinkTotalBytes,
                downlinkTotalBytes = downlinkTotalBytes,
            )
        }

        val elapsedNanos = now - priorNanos
        if (elapsedNanos <= 0L) {
            return AndroidTunnelTrafficSnapshot(
                state = AndroidTunnelTrafficSampleState.WARMING,
                uplinkTotalBytes = uplinkTotalBytes,
                downlinkTotalBytes = downlinkTotalBytes,
            )
        }
        val uplinkRate = ratePerSecond(uplinkTotalBytes - priorUplink, elapsedNanos)
        val downlinkRate = ratePerSecond(downlinkTotalBytes - priorDownlink, elapsedNanos)
        val state = if (uplinkRate == null || downlinkRate == null) {
            AndroidTunnelTrafficSampleState.OVERFLOW
        } else {
            AndroidTunnelTrafficSampleState.AVAILABLE
        }
        return AndroidTunnelTrafficSnapshot(
            state = state,
            uplinkBps = uplinkRate,
            downlinkBps = downlinkRate,
            uplinkTotalBytes = uplinkTotalBytes,
            downlinkTotalBytes = downlinkTotalBytes,
        )
    }

    @Synchronized
    fun unavailable(): AndroidTunnelTrafficSnapshot {
        reset()
        return AndroidTunnelTrafficSnapshot.unavailable
    }

    private fun reset() {
        previousUplinkTotal = null
        previousDownlinkTotal = null
        previousSampleNanos = null
    }

    private fun ratePerSecond(deltaBytes: Long, elapsedNanos: Long): Long? {
        val scaled = BigInteger.valueOf(deltaBytes)
            .multiply(NANOS_PER_SECOND)
            .divide(BigInteger.valueOf(elapsedNanos))
        return runCatching { scaled.longValueExact() }.getOrNull()
    }

    private companion object {
        val NANOS_PER_SECOND: BigInteger = BigInteger.valueOf(1_000_000_000L)
    }
}

/** Owns the cancellable Core status stream for one VPN runtime session. */
internal class AndroidTunnelTrafficClient(
    private val scope: AndroidLifecycleTaskScope,
    private val onSnapshot: (AndroidTunnelTrafficSnapshot) -> Unit,
    private val tracker: AndroidTunnelTrafficTracker = AndroidTunnelTrafficTracker(),
) {
    private val handler = Handler()
    private val options = CommandClientOptions().apply {
        addCommand(Libbox.CommandStatus)
        setStatusInterval(STATUS_INTERVAL_NANOS)
    }
    private val client = Libbox.newCommandClient(handler, options)

    fun start(): Boolean {
        scope.onCancel { runCatching { client.disconnect() } }
        return scope.execute {
            try {
                client.connect()
                if (!scope.isActive()) {
                    runCatching { client.disconnect() }
                }
            } catch (_: Throwable) {
                publish(tracker.unavailable())
                runCatching { client.disconnect() }
            }
        }
    }

    private fun publish(snapshot: AndroidTunnelTrafficSnapshot) {
        if (scope.isActive()) {
            onSnapshot(snapshot)
        }
    }

    private inner class Handler : CommandClientHandler {
        override fun writeStatus(status: StatusMessage) {
            publish(
                tracker.update(
                    trafficAvailable = status.getTrafficAvailable(),
                    uplinkTotalBytes = status.getUplinkTotal(),
                    downlinkTotalBytes = status.getDownlinkTotal(),
                ),
            )
        }

        override fun disconnected(message: String) = publish(tracker.unavailable())
        override fun clearLogs() = Unit
        override fun connected() = Unit
        override fun initializeClashMode(modes: StringIterator, currentMode: String) = Unit
        override fun setDefaultLogLevel(level: Int) = Unit
        override fun updateClashMode(newMode: String) = Unit
        override fun writeConnectionEvents(events: ConnectionEvents) = Unit
        override fun writeGroups(groups: OutboundGroupIterator) = Unit
        override fun writeLogs(logs: LogIterator) = Unit
    }

    private companion object {
        const val STATUS_INTERVAL_NANOS = 1_000_000_000L
    }
}
