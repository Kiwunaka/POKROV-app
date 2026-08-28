package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertFalse
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
    ) = AndroidOperationalRecord(
        occurredAtUtc = "2026-08-22T12:00:00.000Z",
        sequence = sequence,
        event = event,
        outcome = outcome,
        generation = generation,
    )
}
