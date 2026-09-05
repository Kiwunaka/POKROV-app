package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidCoreOperationalEventsTest {
    @Test
    fun rejectsLateDuplicateAndPreviousAttemptCallbacks() {
        val fence = AndroidCoreOperationalEventFence(capacity = 4)
        val runId = "018f4f2a-6d58-4c11-8c27-4fb77bd28c15"
        val firstAttempt = "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33"
        val secondAttempt = "a69dc69d-fd10-474f-8c63-4bf8b224c184"

        assertTrue(fence.activate(runId, firstAttempt, 7))
        assertTrue(fence.accept(record(runId, firstAttempt, 7, 1)))
        assertFalse(fence.accept(record(runId, firstAttempt, 7, 1)))
        assertFalse(fence.accept(record(runId, firstAttempt, 6, 2)))

        assertTrue(fence.activate(runId, secondAttempt, 7))
        assertFalse(fence.accept(record(runId, firstAttempt, 7, 2)))
        assertTrue(fence.accept(record(runId, secondAttempt, 7, 2)))
        assertEquals(listOf(1L, 2L), fence.snapshot().map { it.sequence })
    }

    @Test
    fun acceptsRestartedSequenceForNewRunAtSameServiceGeneration() {
        val fence = AndroidCoreOperationalEventFence(capacity = 4)
        val firstRunId = "018f4f2a-6d58-4c11-8c27-4fb77bd28c15"
        val secondRunId = "028f4f2a-6d58-4c11-8c27-4fb77bd28c15"
        val firstAttempt = "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33"
        val secondAttempt = "a69dc69d-fd10-474f-8c63-4bf8b224c184"

        assertTrue(fence.activate(firstRunId, firstAttempt, 1))
        assertTrue(fence.accept(record(firstRunId, firstAttempt, 1, 1)))
        assertTrue(fence.accept(record(firstRunId, firstAttempt, 1, 2)))

        assertTrue(fence.activate(secondRunId, secondAttempt, 1))
        assertFalse(fence.accept(record(firstRunId, firstAttempt, 1, 3)))
        assertTrue(fence.accept(record(secondRunId, secondAttempt, 1, 1)))
        assertEquals(listOf(1L, 2L, 1L), fence.snapshot().map { it.sequence })
    }

    @Test
    fun boundsBreadcrumbsAndRejectsStaleGenerationActivation() {
        val fence = AndroidCoreOperationalEventFence(capacity = 2)
        val runId = "018f4f2a-6d58-4c11-8c27-4fb77bd28c15"
        val attemptId = "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33"
        assertTrue(fence.activate(runId, attemptId, 9))
        assertFalse(fence.activate(runId, attemptId, 8))
        assertTrue(fence.accept(record(runId, attemptId, 9, 1)))
        assertTrue(fence.accept(record(runId, attemptId, 9, 2)))
        assertTrue(fence.accept(record(runId, attemptId, 9, 3)))
        assertEquals(listOf(2L, 3L), fence.snapshot().map { it.sequence })
    }

    @Test
    fun acceptsOnlyClosedTransportFailureCodes() {
        listOf(
            "TRANSPORT-001",
            "TRANSPORT-002",
            "TRANSPORT-003",
            "TRANSPORT-004",
        ).forEach { code ->
            assertEquals(
                code,
                AndroidCoreOperationalEvents.parse(FakeCoreOperationalEvent(code))?.errorCode,
            )
        }
        assertEquals(
            null,
            AndroidCoreOperationalEvents.parse(
                FakeCoreOperationalEvent("https://private.example.test?token=secret"),
            ),
        )
    }

    private fun record(
        runId: String,
        attemptId: String,
        generation: Long,
        sequence: Long,
    ) = AndroidCoreOperationalEventRecord(
        occurredAtUtc = "2026-08-21T12:00:00Z",
        runId = runId,
        attemptId = attemptId,
        generation = generation,
        sequence = sequence,
        name = "core.runtime.start",
        subsystem = "core",
        stage = "start",
        severity = "info",
        outcome = "started",
        errorCode = null,
        phase = "core_start",
    )
}

private class FakeCoreOperationalEvent(
    private val errorCode: String,
) {
    fun getSchemaVersion() = 1
    fun getEventABI() = 1
    fun getOccurredAtUTC() = "2026-08-21T12:00:00Z"
    fun getRunID() = "018f4f2a-6d58-4c11-8c27-4fb77bd28c15"
    fun getAttemptID() = "57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33"
    fun getGeneration() = 9L
    fun getSequence() = 1L
    fun getName() = "core.runtime.start"
    fun getSubsystem() = "core"
    fun getStage() = "start"
    fun getSeverity() = "error"
    fun getOutcome() = "failed"
    fun getErrorCode() = errorCode
    fun getPhase() = "core_start"
}
