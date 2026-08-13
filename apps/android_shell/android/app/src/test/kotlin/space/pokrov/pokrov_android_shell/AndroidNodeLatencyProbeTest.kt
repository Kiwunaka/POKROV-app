package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidNodeLatencyProbeTest {
    @Test
    fun parserKeepsOnlyBoundedValidUniqueTargets() {
        val targets = AndroidNodeLatencyProbe.parseTargets(
            listOf(
                mapOf("code" to "DE-FRA-01", "host" to "de.example.test", "port" to 443),
                mapOf("code" to "de-fra-01", "host" to "duplicate.example.test", "port" to 8443),
                mapOf("code" to "bad code", "host" to "bad.example.test", "port" to 443),
                mapOf("code" to "nl-ams-01", "host" to "https://bad.example.test", "port" to 443),
                mapOf("code" to "it-mil-01", "host" to "it.example.test", "port" to 70000),
            ),
        )

        assertEquals(
            listOf(
                AndroidNodeLatencyTarget(
                    code = "de-fra-01",
                    host = "de.example.test",
                    port = 443,
                ),
            ),
            targets,
        )
    }

    @Test
    fun parserCapsTheProbeBatch() {
        val targets = AndroidNodeLatencyProbe.parseTargets(
            (1..30).map { index ->
                mapOf(
                    "code" to "node-$index",
                    "host" to "node-$index.example.test",
                    "port" to 443,
                )
            },
        )

        assertEquals(16, targets.size)
    }
}
