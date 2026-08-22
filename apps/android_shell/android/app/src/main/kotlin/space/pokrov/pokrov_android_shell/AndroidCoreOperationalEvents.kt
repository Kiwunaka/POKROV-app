package space.pokrov.pokrov_android_shell

import space.pokrov.core.libbox.CommandServer
import java.lang.reflect.Proxy
import java.util.UUID

internal data class AndroidCoreOperationalEventRecord(
    val occurredAtUtc: String,
    val runId: String,
    val attemptId: String,
    val generation: Long,
    val sequence: Long,
    val name: String,
    val subsystem: String,
    val stage: String,
    val severity: String,
    val outcome: String,
    val errorCode: String?,
    val phase: String,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "schema_version" to CORE_EVENT_SCHEMA_VERSION,
        "event_abi" to CORE_EVENT_ABI_VERSION,
        "occurred_at_utc" to occurredAtUtc,
        "run_id" to runId,
        "attempt_id" to attemptId,
        "generation" to generation,
        "sequence" to sequence,
        "name" to name,
        "subsystem" to subsystem,
        "stage" to stage,
        "severity" to severity,
        "outcome" to outcome,
        "error_code" to errorCode,
        "phase" to phase,
    )
}

internal class AndroidCoreOperationalEventFence(
    private val capacity: Int = MAX_CORE_EVENT_BREADCRUMBS,
) {
    private var activeRunId: String? = null
    private var activeAttemptId: String? = null
    private var activeGeneration = 0L
    private var lastSequence = 0L
    private val breadcrumbs = ArrayDeque<AndroidCoreOperationalEventRecord>()

    init {
        require(capacity in 1..MAX_CORE_EVENT_BREADCRUMBS)
    }

    @Synchronized
    fun activate(runId: String, attemptId: String, generation: Long): Boolean {
        if (!CORE_UUID.matches(runId) || !CORE_UUID.matches(attemptId) ||
            generation !in 1..Int.MAX_VALUE.toLong() || generation < activeGeneration
        ) {
            return false
        }
        if (generation > activeGeneration) {
            lastSequence = 0L
        }
        activeRunId = runId
        activeAttemptId = attemptId
        activeGeneration = generation
        return true
    }

    @Synchronized
    fun accept(record: AndroidCoreOperationalEventRecord): Boolean {
        if (record.runId != activeRunId || record.attemptId != activeAttemptId ||
            record.generation != activeGeneration || record.sequence <= lastSequence
        ) {
            return false
        }
        lastSequence = record.sequence
        if (breadcrumbs.size == capacity) {
            breadcrumbs.removeFirst()
        }
        breadcrumbs.addLast(record)
        return true
    }

    @Synchronized
    fun snapshot(): List<AndroidCoreOperationalEventRecord> = breadcrumbs.toList()
}

internal object AndroidCoreOperationalEvents {
    private val fence = AndroidCoreOperationalEventFence()
    private val eventHandler: Any by lazy {
        val handlerType = Class.forName(CORE_EVENT_HANDLER_CLASS)
        Proxy.newProxyInstance(
            handlerType.classLoader,
            arrayOf(handlerType),
        ) { _, method, arguments ->
            if (method.name == "writeOperationalEvent" && arguments?.size == 1) {
                writeOperationalEvent(arguments[0])
            }
            null
        }
    }

    fun beginRun(server: CommandServer, generation: Long): String {
        val runId = UUID.randomUUID().toString().lowercase()
        beginAttempt(server, runId, generation)
        return runId
    }

    fun beginAttempt(server: CommandServer, runId: String, generation: Long) {
        val attemptId = UUID.randomUUID().toString().lowercase()
        check(fence.activate(runId, attemptId, generation)) {
            "Could not activate Core operational event context."
        }
        val handlerType = Class.forName(CORE_EVENT_HANDLER_CLASS)
        server.javaClass
            .getMethod("setOperationalEventHandler", handlerType)
            .invoke(server, eventHandler)
        server.javaClass
            .getMethod(
                "setOperationalEventContext",
                String::class.java,
                String::class.java,
                java.lang.Long.TYPE,
            )
            .invoke(server, runId, attemptId, generation)
    }

    private fun writeOperationalEvent(event: Any) {
        val record = parse(event) ?: return
        if (!fence.accept(record)) {
            return
        }
        if (record.name == "core.egress.probe") {
            AndroidCoreEgressProbe.writeCoreOperationalEvent(record)
        }
    }

    fun snapshot(): List<Map<String, Any?>> = fence.snapshot().map { it.toMap() }

    internal fun parse(event: Any): AndroidCoreOperationalEventRecord? = runCatching {
        val eventType = event.javaClass
        fun intValue(name: String): Int =
            (eventType.getMethod(name).invoke(event) as Number).toInt()
        fun longValue(name: String): Long =
            (eventType.getMethod(name).invoke(event) as Number).toLong()
        fun stringValue(name: String): String =
            eventType.getMethod(name).invoke(event) as String

        if (intValue("getSchemaVersion") != CORE_EVENT_SCHEMA_VERSION ||
            intValue("getEventABI") != CORE_EVENT_ABI_VERSION
        ) {
            return@runCatching null
        }
        val occurredAtUtc = stringValue("getOccurredAtUTC")
        val runId = stringValue("getRunID")
        val attemptId = stringValue("getAttemptID")
        val generation = longValue("getGeneration")
        val sequence = longValue("getSequence")
        val name = stringValue("getName")
        val subsystem = stringValue("getSubsystem")
        val stage = stringValue("getStage")
        val severity = stringValue("getSeverity")
        val outcome = stringValue("getOutcome")
        val errorCode = stringValue("getErrorCode").ifBlank { null }
        val phase = stringValue("getPhase")
        val definition = CORE_EVENT_DEFINITIONS[name] ?: return@runCatching null
        if (definition != Triple(subsystem, stage, phase) ||
            !CORE_TIMESTAMP.matches(occurredAtUtc) ||
            !CORE_UUID.matches(runId) || !CORE_UUID.matches(attemptId) ||
            generation !in 1..Int.MAX_VALUE.toLong() || sequence < 1L ||
            outcome !in CORE_EVENT_OUTCOMES || severity !in CORE_EVENT_SEVERITIES ||
            (outcome == "failed") != (severity == "error") ||
            (outcome != "failed" && errorCode != null) ||
            (outcome == "failed" && errorCode !in CORE_EVENT_ERROR_CODES)
        ) {
            return@runCatching null
        }
        AndroidCoreOperationalEventRecord(
            occurredAtUtc = occurredAtUtc,
            runId = runId,
            attemptId = attemptId,
            generation = generation,
            sequence = sequence,
            name = name,
            subsystem = subsystem,
            stage = stage,
            severity = severity,
            outcome = outcome,
            errorCode = errorCode,
            phase = phase,
        )
    }.getOrNull()
}

private const val CORE_EVENT_SCHEMA_VERSION = 1
private const val CORE_EVENT_ABI_VERSION = 1
private const val MAX_CORE_EVENT_BREADCRUMBS = 128
private const val CORE_EVENT_HANDLER_CLASS =
    "space.pokrov.core.libbox.OperationalEventHandler"
private val CORE_UUID = Regex(
    "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
)
private val CORE_TIMESTAMP = Regex(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\\.[0-9]{1,9})?Z$",
)
private val CORE_EVENT_DEFINITIONS = mapOf(
    "core.runtime.start" to Triple("core", "start", "core_start"),
    "core.runtime.stop" to Triple("core", "stop", "stop"),
    "core.egress.probe" to Triple("egress", "verify", "egress"),
)
private val CORE_EVENT_OUTCOMES = setOf("started", "succeeded", "failed")
private val CORE_EVENT_SEVERITIES = setOf("info", "error")
private val CORE_EVENT_ERROR_CODES = setOf(
    "CORE-003",
    "CORE-005",
    "CORE-006",
    "CORE-008",
    "TRANSPORT-001",
    "TRANSPORT-002",
    "TRANSPORT-003",
    "TRANSPORT-004",
    "EGRESS-001",
)
