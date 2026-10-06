package space.pokrov.pokrov_android_shell

import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.ArrayDeque
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

internal enum class AndroidOperationalEvent(val wireValue: String) {
    VPN_SERVICE("vpn_service"),
    VPN_PERMISSION("vpn_permission"),
    NOTIFICATION_PERMISSION("notification_permission"),
    UPLINK_SOCKET("uplink_socket"),
    NETWORK_CALLBACK("network_callback"),
    CORE_EGRESS_PROBE("core_egress_probe"),
    CANDIDATE_PROBE("candidate_probe"),
    DOZE("doze"),
    APP_STANDBY("app_standby"),
    BACKGROUND_RESTRICTION("background_restriction"),
    MAIN_THREAD_WATCHDOG("main_thread_watchdog"),
    UPDATER_IDENTITY("updater_identity"),
    UPDATER_HANDOFF("updater_handoff"),
}

internal enum class AndroidOperationalOutcome(val wireValue: String) {
    CREATED("created"),
    START_REQUESTED("start_requested"),
    SESSION_STARTED("session_started"),
    TUN_ESTABLISHED("tun_established"),
    STOP_REQUESTED("stop_requested"),
    STOPPED("stopped"),
    REVOKED("revoked"),
    DESTROYED("destroyed"),
    FAILED("failed"),
    REQUIRED("required"),
    ALREADY_GRANTED("already_granted"),
    GRANTED("granted"),
    DENIED("denied"),
    AVAILABLE("available"),
    CAPABILITIES_CHANGED("capabilities_changed"),
    LOST("lost"),
    ACTIVE("active"),
    INACTIVE("inactive"),
    WORKING_SET("working_set"),
    FREQUENT("frequent"),
    RARE("rare"),
    RESTRICTED("restricted"),
    UNKNOWN("unknown"),
    ENABLED("enabled"),
    WHITELISTED("whitelisted"),
    DISABLED("disabled"),
    STALLED("stalled"),
    VERIFIED("verified"),
    REJECTED("rejected"),
    INSTALLER_OPENED("installer_opened"),
    STORE_OPENED("store_opened"),
    PERMISSION_REQUIRED("permission_required"),
}

private val ANDROID_OPERATIONAL_OUTCOMES = mapOf(
    AndroidOperationalEvent.VPN_SERVICE to setOf(
        AndroidOperationalOutcome.CREATED,
        AndroidOperationalOutcome.START_REQUESTED,
        AndroidOperationalOutcome.SESSION_STARTED,
        AndroidOperationalOutcome.TUN_ESTABLISHED,
        AndroidOperationalOutcome.STOP_REQUESTED,
        AndroidOperationalOutcome.STOPPED,
        AndroidOperationalOutcome.REVOKED,
        AndroidOperationalOutcome.DESTROYED,
        AndroidOperationalOutcome.FAILED,
    ),
    AndroidOperationalEvent.VPN_PERMISSION to setOf(
        AndroidOperationalOutcome.REQUIRED,
        AndroidOperationalOutcome.ALREADY_GRANTED,
        AndroidOperationalOutcome.GRANTED,
        AndroidOperationalOutcome.DENIED,
    ),
    AndroidOperationalEvent.NOTIFICATION_PERMISSION to setOf(
        AndroidOperationalOutcome.REQUIRED,
        AndroidOperationalOutcome.ALREADY_GRANTED,
        AndroidOperationalOutcome.GRANTED,
        AndroidOperationalOutcome.DENIED,
    ),
    AndroidOperationalEvent.UPLINK_SOCKET to setOf(
        AndroidOperationalOutcome.GRANTED,
        AndroidOperationalOutcome.DENIED,
    ),
    AndroidOperationalEvent.NETWORK_CALLBACK to setOf(
        AndroidOperationalOutcome.AVAILABLE,
        AndroidOperationalOutcome.CAPABILITIES_CHANGED,
        AndroidOperationalOutcome.LOST,
    ),
    AndroidOperationalEvent.CORE_EGRESS_PROBE to setOf(
        AndroidOperationalOutcome.REQUIRED,
        AndroidOperationalOutcome.VERIFIED,
        AndroidOperationalOutcome.FAILED,
        AndroidOperationalOutcome.STALLED,
    ),
    AndroidOperationalEvent.CANDIDATE_PROBE to setOf(
        AndroidOperationalOutcome.VERIFIED,
        AndroidOperationalOutcome.FAILED,
    ),
    AndroidOperationalEvent.DOZE to setOf(
        AndroidOperationalOutcome.ACTIVE,
        AndroidOperationalOutcome.INACTIVE,
    ),
    AndroidOperationalEvent.APP_STANDBY to setOf(
        AndroidOperationalOutcome.ACTIVE,
        AndroidOperationalOutcome.WORKING_SET,
        AndroidOperationalOutcome.FREQUENT,
        AndroidOperationalOutcome.RARE,
        AndroidOperationalOutcome.RESTRICTED,
        AndroidOperationalOutcome.UNKNOWN,
    ),
    AndroidOperationalEvent.BACKGROUND_RESTRICTION to setOf(
        AndroidOperationalOutcome.ENABLED,
        AndroidOperationalOutcome.WHITELISTED,
        AndroidOperationalOutcome.DISABLED,
        AndroidOperationalOutcome.UNKNOWN,
    ),
    AndroidOperationalEvent.MAIN_THREAD_WATCHDOG to setOf(
        AndroidOperationalOutcome.STALLED,
    ),
    AndroidOperationalEvent.UPDATER_IDENTITY to setOf(
        AndroidOperationalOutcome.VERIFIED,
        AndroidOperationalOutcome.REJECTED,
    ),
    AndroidOperationalEvent.UPDATER_HANDOFF to setOf(
        AndroidOperationalOutcome.INSTALLER_OPENED,
        AndroidOperationalOutcome.STORE_OPENED,
        AndroidOperationalOutcome.PERMISSION_REQUIRED,
        AndroidOperationalOutcome.FAILED,
    ),
)

internal enum class AndroidCandidateProbePhase(val wireValue: String) {
    PARSE_PROFILE("parse_profile"),
    CREATE_INSTANCE("create_instance"),
    START_INSTANCE("start_instance"),
    SELECT_OUTBOUND("select_outbound"),
    PROXY_DIAL("proxy_dial"),
    EGRESS_CHECK("egress_check"),
    TLS_HANDSHAKE("tls_handshake"),
    TLS_READ("tls_read"),
    TLS_WRITE("tls_write"),
    TLS_PROCESSING("tls_processing"),
    TLS_CERTIFICATE_VERIFIED("tls_certificate_verified"),
    TLS_COMPLETE("tls_complete"),
    HTTP_204("http_204"),
    HTTP_64K("http_64k"),
}

internal data class AndroidCandidateProbeDiagnostic(
    val phase: AndroidCandidateProbePhase? = null,
    val phaseStartedMs: Long? = null,
    val durationMs: Long? = null,
) {
    init {
        require(durationMs == null || durationMs >= 0L)
        require((phase == null) == (phaseStartedMs == null))
        require(phaseStartedMs == null ||
            (durationMs != null && phaseStartedMs >= 0L && phaseStartedMs <= durationMs))
    }

    companion object {
        fun fromNativeFields(stage: Any?, stageStartedMs: Any?, durationMs: Any?): AndroidCandidateProbeDiagnostic {
            fun millis(value: Any?): Long? = when (value) {
                is Int -> value.toLong()
                is Long -> value
                else -> null
            }?.takeIf { it >= 0L }

            val duration = millis(durationMs)
            val phase = AndroidCandidateProbePhase.values().firstOrNull { it.wireValue == stage }
            val started = millis(stageStartedMs)
            return if (phase != null && started != null && duration != null && started <= duration) {
                AndroidCandidateProbeDiagnostic(phase, started, duration)
            } else {
                AndroidCandidateProbeDiagnostic(durationMs = duration)
            }
        }
    }
}

internal data class AndroidOperationalRecord(
    val occurredAtUtc: String,
    val sequence: Long,
    val event: AndroidOperationalEvent,
    val outcome: AndroidOperationalOutcome,
    val generation: Long? = null,
    val droppedBefore: Long = 0L,
    val probeSequence: Long? = null,
    val candidateProbe: AndroidCandidateProbeDiagnostic? = null,
) {
    init {
        require(ANDROID_OPERATIONAL_TIMESTAMP.matches(occurredAtUtc))
        require(sequence > 0L)
        require(generation == null || generation > 0L)
        require(droppedBefore >= 0L)
        require(outcome in ANDROID_OPERATIONAL_OUTCOMES.getValue(event))
        require(probeSequence == null || probeSequence > 0L)
        require((probeSequence == null && candidateProbe == null) || event == AndroidOperationalEvent.CANDIDATE_PROBE)
    }

    fun toJsonLine(): String = buildString {
        append("{\"schema_version\":1,\"occurred_at_utc\":\"")
        append(occurredAtUtc)
        append("\",\"sequence\":")
        append(sequence)
        append(",\"event\":\"")
        append(event.wireValue)
        append("\",\"outcome\":\"")
        append(outcome.wireValue)
        append('"')
        if (generation != null) {
            append(",\"generation\":")
            append(generation)
        }
        append(",\"dropped_before\":")
        append(droppedBefore)
        if (probeSequence != null) {
            append(",\"probe_sequence\":")
            append(probeSequence)
        }
        candidateProbe?.let { diagnostic ->
            if (diagnostic.durationMs != null) {
                append(",\"duration_ms\":")
                append(diagnostic.durationMs)
            }
            if (diagnostic.phase != null) {
                append(",\"phase\":\"")
                append(diagnostic.phase.wireValue)
                append("\",\"phase_started_ms\":")
                append(diagnostic.phaseStartedMs)
            }
        }
        append('}')
    }
}

internal class AndroidOperationalJournalStore(
    root: File,
    private val maxFileBytes: Long = DEFAULT_MAX_FILE_BYTES,
) {
    val currentFile = File(root, CURRENT_FILE_NAME)
    val previousFile = File(root, PREVIOUS_FILE_NAME)

    init {
        require(maxFileBytes >= MIN_MAX_FILE_BYTES)
        check(root.isDirectory || root.mkdirs()) { "android_operational_journal_root_unavailable" }
        makeOwnerOnly(root)
    }

    @Synchronized
    fun append(record: AndroidOperationalRecord) {
        val payload = (record.toJsonLine() + "\n").toByteArray(StandardCharsets.UTF_8)
        require(payload.size <= MAX_RECORD_BYTES)
        if (currentFile.isFile && currentFile.length() + payload.size > maxFileBytes) {
            rotate()
        }
        FileOutputStream(currentFile, true).use { output ->
            output.write(payload)
        }
        makeOwnerOnly(currentFile)
    }

    @Synchronized
    fun readCandidateDiagnostics(): List<Map<String, Any>> {
        val records = ArrayDeque<Map<String, Any>>()
        for (file in listOf(previousFile, currentFile)) {
            if (!file.exists()) continue
            check(file.length() <= maxFileBytes) { "android_operational_journal_size_invalid" }
            file.bufferedReader(StandardCharsets.UTF_8).useLines { lines ->
                for (line in lines) {
                    val match = CANDIDATE_RECORD.matchEntire(line) ?: continue
                    val duration = match.groupValues[3].toLongOrNull() ?: continue
                    val phase = AndroidCandidateProbePhase.values().firstOrNull {
                        it.wireValue == match.groupValues[4]
                    } ?: continue
                    val started = match.groupValues[5].toLongOrNull() ?: continue
                    if (started > duration) continue
                    if (records.size == MAX_CANDIDATE_DIAGNOSTICS) records.removeFirst()
                    records.addLast(mapOf(
                        "occurred_at" to match.groupValues[1],
                        "subsystem" to "candidate_probe",
                        "stage" to phase.wireValue,
                        "outcome" to if (match.groupValues[2] == "verified") "succeeded" else "failed",
                        "duration_ms" to duration,
                        "phase_started_ms" to started,
                    ))
                }
            }
        }
        return records.toList()
    }

    private fun rotate() {
        if (previousFile.exists()) {
            check(previousFile.delete()) { "android_operational_journal_previous_delete_failed" }
        }
        if (currentFile.exists()) {
            check(currentFile.renameTo(previousFile)) {
                "android_operational_journal_rotation_failed"
            }
            makeOwnerOnly(previousFile)
        }
    }

    private fun makeOwnerOnly(file: File) {
        file.setReadable(false, false)
        file.setWritable(false, false)
        file.setExecutable(false, false)
        file.setReadable(true, true)
        file.setWritable(true, true)
        if (file.isDirectory) {
            file.setExecutable(true, true)
        }
    }

    private companion object {
        const val CURRENT_FILE_NAME = "android-operational-v1.jsonl"
        const val PREVIOUS_FILE_NAME = "android-operational-v1.previous.jsonl"
        const val DEFAULT_MAX_FILE_BYTES = 256L * 1024L
        const val MIN_MAX_FILE_BYTES = 512L
        const val MAX_RECORD_BYTES = 1024
        const val MAX_CANDIDATE_DIAGNOSTICS = 256
        // Accept only the canonical closed record written above, never raw JSON fields.
        val CANDIDATE_RECORD = Regex(
            """\{"schema_version":1,"occurred_at_utc":"([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z)","sequence":[1-9][0-9]*,"event":"candidate_probe","outcome":"(verified|failed)"(?:,"generation":[1-9][0-9]*)?,"dropped_before":[0-9]+(?:,"probe_sequence":[1-9][0-9]*)?,"duration_ms":([0-9]+),"phase":"([a-z0-9_]+)","phase_started_ms":([0-9]+)\}""",
        )
    }
}

internal class AndroidOperationalRateLimiter(
    private val intervalMillis: Long = 10_000L,
    private val clockMillis: () -> Long = { System.nanoTime() / 1_000_000L },
) {
    private val lastEmission = mutableMapOf<Pair<AndroidOperationalEvent, AndroidOperationalOutcome>, Long>()

    init {
        require(intervalMillis > 0L)
    }

    @Synchronized
    fun shouldEmit(event: AndroidOperationalEvent, outcome: AndroidOperationalOutcome): Boolean {
        val key = event to outcome
        val now = clockMillis()
        val previous = lastEmission[key]
        if (previous != null && now - previous < intervalMillis) {
            return false
        }
        lastEmission[key] = now
        return true
    }
}

internal object AndroidOperationalJournal {
    private val sequence = AtomicLong(0L)
    private val dropped = AtomicLong(0L)
    private val rateLimiter = AndroidOperationalRateLimiter()
    private val writer = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(256),
        { runnable -> Thread(runnable, "pokrov-android-journal").apply { isDaemon = true } },
        ThreadPoolExecutor.AbortPolicy(),
    )

    @Volatile
    private var store: AndroidOperationalJournalStore? = null

    fun initialize(context: Context) {
        if (store != null) {
            return
        }
        synchronized(this) {
            if (store == null) {
                store = AndroidOperationalJournalStore(
                    File(context.applicationContext.noBackupFilesDir, "observability"),
                )
            }
        }
    }

    @Synchronized
    fun record(
        event: AndroidOperationalEvent,
        outcome: AndroidOperationalOutcome,
        generation: Long? = null,
        probeSequence: Long? = null,
        candidateProbe: AndroidCandidateProbeDiagnostic? = null,
    ) {
        val target = store ?: return
        val record = AndroidOperationalRecord(
            occurredAtUtc = utcNow(),
            sequence = sequence.incrementAndGet(),
            event = event,
            outcome = outcome,
            generation = generation,
            droppedBefore = dropped.getAndSet(0L),
            probeSequence = probeSequence,
            candidateProbe = candidateProbe,
        )
        try {
            writer.execute {
                runCatching { target.append(record) }
                    .onFailure { dropped.addAndGet(record.droppedBefore + 1L) }
            }
        } catch (_: RejectedExecutionException) {
            dropped.addAndGet(record.droppedBefore + 1L)
        }
    }

    fun recordRateLimited(
        event: AndroidOperationalEvent,
        outcome: AndroidOperationalOutcome,
        generation: Long? = null,
    ) {
        if (rateLimiter.shouldEmit(event, outcome)) {
            record(event, outcome, generation)
        }
    }

    @Synchronized
    fun readCandidateDiagnostics(complete: (Result<List<Map<String, Any>>>) -> Unit) {
        try {
            // The same queue places this read after already submitted records and off the UI thread.
            writer.execute {
                complete(runCatching {
                    checkNotNull(store) { "android_operational_journal_unavailable" }
                        .readCandidateDiagnostics()
                })
            }
        } catch (failure: RejectedExecutionException) {
            complete(Result.failure(failure))
        }
    }

    private fun utcNow(): String = SimpleDateFormat(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        Locale.US,
    ).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date())
}

internal object AndroidMainThreadWatchdogPolicy {
    fun shouldRecord(
        nowMillis: Long,
        lastHeartbeatMillis: Long,
        lastRecordMillis: Long,
        stallThresholdMillis: Long = 10_000L,
        recordCooldownMillis: Long = 60_000L,
    ): Boolean =
        nowMillis - lastHeartbeatMillis >= stallThresholdMillis &&
            nowMillis - lastRecordMillis >= recordCooldownMillis
}

private object AndroidMainThreadWatchdog {
    private val started = AtomicBoolean(false)
    private val handler = Handler(Looper.getMainLooper())
    private val checker = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "pokrov-main-watchdog").apply { isDaemon = true }
    }
    @Volatile
    private var lastHeartbeatMillis = 0L
    @Volatile
    private var lastRecordMillis = Long.MIN_VALUE / 2L
    private val heartbeat = object : Runnable {
        override fun run() {
            lastHeartbeatMillis = SystemClock.elapsedRealtime()
            handler.postDelayed(this, HEARTBEAT_INTERVAL_MILLIS)
        }
    }

    fun start() {
        if (!started.compareAndSet(false, true)) {
            return
        }
        lastHeartbeatMillis = SystemClock.elapsedRealtime()
        handler.post(heartbeat)
        checker.scheduleAtFixedRate(
            {
                val now = SystemClock.elapsedRealtime()
                if (AndroidMainThreadWatchdogPolicy.shouldRecord(
                        nowMillis = now,
                        lastHeartbeatMillis = lastHeartbeatMillis,
                        lastRecordMillis = lastRecordMillis,
                    )
                ) {
                    lastRecordMillis = now
                    AndroidOperationalJournal.record(
                        AndroidOperationalEvent.MAIN_THREAD_WATCHDOG,
                        AndroidOperationalOutcome.STALLED,
                    )
                }
            },
            CHECK_INTERVAL_MILLIS,
            CHECK_INTERVAL_MILLIS,
            TimeUnit.MILLISECONDS,
        )
    }

    private const val HEARTBEAT_INTERVAL_MILLIS = 2_000L
    private const val CHECK_INTERVAL_MILLIS = 5_000L
}

private object AndroidRuntimeEnvironmentDiagnostics {
    private val started = AtomicBoolean(false)

    fun start(context: Context) {
        if (!started.compareAndSet(false, true)) {
            return
        }
        val applicationContext = context.applicationContext
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED) {
                    recordDoze(context)
                }
                if (intent.action == ConnectivityManager.ACTION_RESTRICT_BACKGROUND_CHANGED) {
                    recordBackgroundRestriction(context)
                }
                recordAppStandby(context)
            }
        }
        val filter = IntentFilter().apply {
            addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
            addAction(ConnectivityManager.ACTION_RESTRICT_BACKGROUND_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            applicationContext.registerReceiver(
                receiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            applicationContext.registerReceiver(receiver, filter)
        }
        recordDoze(applicationContext)
        recordBackgroundRestriction(applicationContext)
        recordAppStandby(applicationContext)
    }

    private fun recordDoze(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        val power = runCatching {
            context.getSystemService(Context.POWER_SERVICE) as PowerManager
        }.getOrNull() ?: return
        AndroidOperationalJournal.recordRateLimited(
            AndroidOperationalEvent.DOZE,
            if (power.isDeviceIdleMode) {
                AndroidOperationalOutcome.ACTIVE
            } else {
                AndroidOperationalOutcome.INACTIVE
            },
        )
    }

    private fun recordBackgroundRestriction(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return
        }
        val status = runCatching {
            val connectivity =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            connectivity.restrictBackgroundStatus
        }.getOrNull() ?: return
        val outcome = when (status) {
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED ->
                AndroidOperationalOutcome.ENABLED
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_WHITELISTED ->
                AndroidOperationalOutcome.WHITELISTED
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_DISABLED ->
                AndroidOperationalOutcome.DISABLED
            else -> AndroidOperationalOutcome.UNKNOWN
        }
        AndroidOperationalJournal.recordRateLimited(
            AndroidOperationalEvent.BACKGROUND_RESTRICTION,
            outcome,
        )
    }

    private fun recordAppStandby(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return
        }
        val bucket = runCatching {
            val usage =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            usage.appStandbyBucket
        }.getOrNull() ?: return
        val outcome = when (bucket) {
            UsageStatsManager.STANDBY_BUCKET_ACTIVE -> AndroidOperationalOutcome.ACTIVE
            UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> AndroidOperationalOutcome.WORKING_SET
            UsageStatsManager.STANDBY_BUCKET_FREQUENT -> AndroidOperationalOutcome.FREQUENT
            UsageStatsManager.STANDBY_BUCKET_RARE -> AndroidOperationalOutcome.RARE
            UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> AndroidOperationalOutcome.RESTRICTED
            else -> AndroidOperationalOutcome.UNKNOWN
        }
        AndroidOperationalJournal.recordRateLimited(
            AndroidOperationalEvent.APP_STANDBY,
            outcome,
        )
    }
}

internal object AndroidOperationalRuntime {
    fun start(context: Context) {
        runCatching { AndroidOperationalJournal.initialize(context) }
        runCatching { AndroidMainThreadWatchdog.start() }
        runCatching { AndroidRuntimeEnvironmentDiagnostics.start(context) }
    }
}

private val ANDROID_OPERATIONAL_TIMESTAMP = Regex(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z$",
)
