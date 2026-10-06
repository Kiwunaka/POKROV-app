package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AndroidOperationalJournalTest {
    @Test
    fun uplinkProtectionUsesClosedSafeOutcomes() {
        val granted = record(
            sequence = 1L,
            event = AndroidOperationalEvent.UPLINK_SOCKET,
            outcome = AndroidOperationalOutcome.GRANTED,
            generation = 2L,
        ).toJsonLine()

        assertTrue(granted.contains("\"event\":\"uplink_socket\""))
        assertTrue(granted.contains("\"outcome\":\"granted\""))
        assertFalse(granted.contains("fd"))
        assertFalse(granted.contains("address"))
    }

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun recordContainsOnlyClosedFieldsAndNoFreeFormPayload() {
        val line = record(
            sequence = 7L,
            event = AndroidOperationalEvent.VPN_SERVICE,
            outcome = AndroidOperationalOutcome.TUN_ESTABLISHED,
            generation = 3L,
        ).toJsonLine()

        assertTrue(line.contains("\"schema_version\":1"))
        assertTrue(line.contains("\"event\":\"vpn_service\""))
        assertTrue(line.contains("\"outcome\":\"tun_established\""))
        assertTrue(line.contains("\"generation\":3"))
        assertFalse(line.contains("message"))
        assertFalse(line.contains("url"))
        assertFalse(line.contains("profile"))
        assertFalse(line.contains("token"))
        assertFalse(line.contains("phase"))

        val candidateLine = record(
            sequence = 8L,
            event = AndroidOperationalEvent.CANDIDATE_PROBE,
            outcome = AndroidOperationalOutcome.FAILED,
            probeSequence = 2L,
            candidateProbe = AndroidCandidateProbeDiagnostic.fromNativeFields("tls_read", 0, 31_000L),
        ).toJsonLine()
        assertTrue(candidateLine.contains("\"phase\":\"tls_read\""))
        assertTrue(candidateLine.contains("\"phase_started_ms\":0"))
        assertTrue(candidateLine.contains("\"duration_ms\":31000"))
        assertTrue(candidateLine.contains("\"probe_sequence\":2"))
        assertFalse(candidateLine.contains("probe_id"))
        assertFalse(candidateLine.contains("message"))
        assertFalse(candidateLine.contains("url"))
        assertFalse(candidateLine.contains("profile"))
        assertFalse(candidateLine.contains("token"))
    }

    @Test
    fun candidateProbeOmitsFreeFormPhasesAndInvalidNativeTiming() {
        val unknown = AndroidCandidateProbeDiagnostic.fromNativeFields("secret.example/profile", 0L, 5L)
        assertNull(unknown.phase)
        assertNull(unknown.phaseStartedMs)
        assertEquals(5L, unknown.durationMs)
        val line = record(
            sequence = 1L,
            event = AndroidOperationalEvent.CANDIDATE_PROBE,
            outcome = AndroidOperationalOutcome.FAILED,
            probeSequence = 1L,
            candidateProbe = unknown,
        ).toJsonLine()
        assertFalse(line.contains("secret"))
        assertFalse(line.contains("phase"))

        val invalidStarted = AndroidCandidateProbeDiagnostic.fromNativeFields("tls_read", 6L, 5L)
        assertNull(invalidStarted.phase)
        assertNull(invalidStarted.phaseStartedMs)
        val invalidDuration = AndroidCandidateProbeDiagnostic.fromNativeFields("tls_read", 0L, "5")
        assertNull(invalidDuration.phase)
        assertNull(invalidDuration.durationMs)
        val invalidSetup = AndroidCandidateProbeDiagnostic.fromNativeFields("start_instance", 4L, 5L, 1L, 3L, 4L)
        assertEquals(AndroidCandidateProbePhase.START_INSTANCE, invalidSetup.phase)
        assertNull(invalidSetup.parseDurationMs)
        assertNull(AndroidCandidateProbeDiagnostic.fromNativeFields("start_instance", 4L, 5L, 3L, 3L, 1L).createDurationMs)
    }

    @Test(expected = IllegalArgumentException::class)
    fun recordRejectsAnOutcomeOutsideTheEventContract() {
        record(
            sequence = 1L,
            event = AndroidOperationalEvent.VPN_PERMISSION,
            outcome = AndroidOperationalOutcome.TUN_ESTABLISHED,
        )
    }

    @Test
    fun coreEgressProbeUsesOnlyClosedDiagnosticOutcomes() {
        listOf(
            AndroidOperationalOutcome.REQUIRED,
            AndroidOperationalOutcome.VERIFIED,
            AndroidOperationalOutcome.FAILED,
            AndroidOperationalOutcome.STALLED,
        ).forEachIndexed { index, outcome ->
            val line = record(
                sequence = index + 1L,
                event = AndroidOperationalEvent.CORE_EGRESS_PROBE,
                outcome = outcome,
                generation = 1L,
            ).toJsonLine()

            assertTrue(line.contains("\"event\":\"core_egress_probe\""))
            assertFalse(line.contains("endpoint"))
            assertFalse(line.contains("profile"))
            assertFalse(line.contains("key"))
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun recordRejectsInvalidGeneration() {
        record(
            sequence = 1L,
            event = AndroidOperationalEvent.VPN_SERVICE,
            outcome = AndroidOperationalOutcome.CREATED,
            generation = 0L,
        )
    }

    @Test
    fun storeKeepsOnlyCurrentAndPreviousBoundedFiles() {
        val root = temporaryFolder.newFolder("observability")
        val store = AndroidOperationalJournalStore(root, maxFileBytes = 512L)

        repeat(12) { index ->
            store.append(
                record(
                    sequence = index + 1L,
                    event = AndroidOperationalEvent.NETWORK_CALLBACK,
                    outcome = AndroidOperationalOutcome.CAPABILITIES_CHANGED,
                ),
            )
        }

        assertTrue(store.currentFile.isFile)
        assertTrue(store.previousFile.isFile)
        assertTrue(store.currentFile.length() in 1L..512L)
        assertTrue(store.previousFile.length() in 1L..512L)
        assertTrue(
            root.listFiles().orEmpty().map { it.name }.toSet() == setOf(
                "android-operational-v1.jsonl",
                "android-operational-v1.previous.jsonl",
            ),
        )
    }

    @Test
    fun candidateExportKeepsClosedPhasesFromBothFilesWithoutPrivateFields() {
        val store = AndroidOperationalJournalStore(
            temporaryFolder.newFolder("candidate-observability"), maxFileBytes = 1024L,
        )
        store.append(record(
            sequence = 1L,
            event = AndroidOperationalEvent.CANDIDATE_PROBE,
            outcome = AndroidOperationalOutcome.FAILED,
            probeSequence = 1L,
            candidateProbe = AndroidCandidateProbeDiagnostic.fromNativeFields("tls_read", 0L, 31_000L),
        ))
        repeat(4) { index ->
            store.append(record(
                sequence = index + 2L,
                event = AndroidOperationalEvent.NETWORK_CALLBACK,
                outcome = AndroidOperationalOutcome.CAPABILITIES_CHANGED,
            ))
        }
        val completed = record(
            sequence = 6L,
            event = AndroidOperationalEvent.CANDIDATE_PROBE,
            outcome = AndroidOperationalOutcome.VERIFIED,
            probeSequence = 2L,
            candidateProbe = AndroidCandidateProbeDiagnostic.fromNativeFields("http_64k", 10L, 200L, 2L, 6L, 5L),
        ).copy(occurredAtUtc = "2026-08-22T12:00:01.000Z")
        store.append(completed)
        assertTrue(store.previousFile.isFile)
        store.currentFile.appendText(
            completed.toJsonLine().replace("http_64k", "private.example/profile") + "\n" +
                "{\"raw\":\"token=fixture\"}\n",
        )

        assertEquals(listOf(
            mapOf("occurred_at" to "2026-08-22T12:00:00.000Z", "subsystem" to "candidate_probe",
                "stage" to "tls_read", "outcome" to "failed", "duration_ms" to 31_000L, "phase_started_ms" to 0L),
            mapOf("occurred_at" to "2026-08-22T12:00:01.000Z", "subsystem" to "candidate_probe",
                "stage" to "http_64k", "outcome" to "succeeded", "duration_ms" to 200L, "phase_started_ms" to 10L,
                "parse_duration_ms" to 2L, "create_duration_ms" to 6L, "certificate_duration_ms" to 5L),
        ), store.readCandidateDiagnostics())
    }

    @Test
    fun rateLimiterSeparatesClosedEventOutcomePairs() {
        var now = 1_000L
        val limiter = AndroidOperationalRateLimiter(
            intervalMillis = 10_000L,
            clockMillis = { now },
        )

        assertTrue(
            limiter.shouldEmit(
                AndroidOperationalEvent.NETWORK_CALLBACK,
                AndroidOperationalOutcome.AVAILABLE,
            ),
        )
        assertFalse(
            limiter.shouldEmit(
                AndroidOperationalEvent.NETWORK_CALLBACK,
                AndroidOperationalOutcome.AVAILABLE,
            ),
        )
        assertTrue(
            limiter.shouldEmit(
                AndroidOperationalEvent.NETWORK_CALLBACK,
                AndroidOperationalOutcome.LOST,
            ),
        )
        now += 10_000L
        assertTrue(
            limiter.shouldEmit(
                AndroidOperationalEvent.NETWORK_CALLBACK,
                AndroidOperationalOutcome.AVAILABLE,
            ),
        )
    }

    @Test
    fun watchdogRequiresAStallAndCooldown() {
        assertFalse(
            AndroidMainThreadWatchdogPolicy.shouldRecord(
                nowMillis = 9_999L,
                lastHeartbeatMillis = 0L,
                lastRecordMillis = -60_000L,
            ),
        )
        assertTrue(
            AndroidMainThreadWatchdogPolicy.shouldRecord(
                nowMillis = 10_000L,
                lastHeartbeatMillis = 0L,
                lastRecordMillis = -60_000L,
            ),
        )
        assertFalse(
            AndroidMainThreadWatchdogPolicy.shouldRecord(
                nowMillis = 20_000L,
                lastHeartbeatMillis = 0L,
                lastRecordMillis = 10_000L,
            ),
        )
    }

    private fun record(
        sequence: Long,
        event: AndroidOperationalEvent,
        outcome: AndroidOperationalOutcome,
        generation: Long? = null,
        probeSequence: Long? = null,
        candidateProbe: AndroidCandidateProbeDiagnostic? = null,
    ) = AndroidOperationalRecord(
        occurredAtUtc = "2026-08-22T12:00:00.000Z",
        sequence = sequence,
        event = event,
        outcome = outcome,
        generation = generation,
        probeSequence = probeSequence,
        candidateProbe = candidateProbe,
    )
}
