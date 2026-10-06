package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidSystemCertificatesTest {
    @Test fun reusesCompleteRootsAndRejectsStaleFailedOrEmptyLoads() {
        var reads = 0
        val first = mutableListOf("first-root")
        lateinit var snapshot: AndroidCertificateSnapshot
        snapshot = AndroidCertificateSnapshot {
            when (++reads) {
                1 -> first
                2 -> { snapshot.invalidate(); listOf("stale-root") }
                3 -> throw IllegalStateException("read failed")
                4 -> listOf("current-root")
                5 -> emptyList()
                else -> listOf("next-root")
            }
        }
        snapshot.prepare()
        first.add("not-in-snapshot")
        snapshot.prepare()
        assertEquals(listOf("first-root"), snapshot.read())
        assertEquals(1, reads)

        snapshot.invalidate()
        snapshot.prepare()
        assertTrue(snapshot.read().isEmpty())
        snapshot.prepare()
        assertTrue(snapshot.read().isEmpty())
        snapshot.prepare()
        snapshot.prepare()
        assertEquals(listOf("current-root"), snapshot.read())
        assertEquals(4, reads)

        snapshot.invalidate()
        snapshot.prepare()
        assertTrue(snapshot.read().isEmpty())
        snapshot.prepare()
        snapshot.prepare()
        assertEquals(listOf("next-root"), snapshot.read())
        assertEquals(6, reads)
    }
}
