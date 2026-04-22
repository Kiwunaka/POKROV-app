package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidSystemDnsPlannerTest {
    @Test
    fun `first usable public dns server prefers first usable public ip`() {
        val resolved = AndroidSystemDnsPlanner.firstUsablePublicDnsServer(
            listOf(
                "local",
                "8.8.8.8",
                "udp://1.1.1.1",
            ),
        )

        assertEquals("8.8.8.8", resolved)
    }

    @Test
    fun `first usable public dns server returns null when only private resolvers exist`() {
        val resolved = AndroidSystemDnsPlanner.firstUsablePublicDnsServer(
            listOf(
                "local",
                "172.19.0.2",
                "127.0.0.1",
            ),
        )

        assertNull(resolved)
    }

    @Test
    fun `normalize address extracts numeric host from uri`() {
        assertEquals(
            "1.1.1.1",
            AndroidSystemDnsPlanner.normalizeAddress("https://1.1.1.1/dns-query"),
        )
    }

    @Test
    fun `normalize address rejects local and hostnames`() {
        assertNull(AndroidSystemDnsPlanner.normalizeAddress("local"))
        assertNull(AndroidSystemDnsPlanner.normalizeAddress("https://one.one.one.one/dns-query"))
    }

    @Test
    fun `private or loopback detection rejects internal addresses`() {
        assertTrue(AndroidSystemDnsPlanner.isPrivateOrLoopback("172.19.0.2"))
        assertTrue(AndroidSystemDnsPlanner.isPrivateOrLoopback("127.0.0.1"))
        assertFalse(AndroidSystemDnsPlanner.isPrivateOrLoopback("8.8.8.8"))
    }

    @Test
    fun `first usable public dns server skips local and private entries`() {
        val resolved = AndroidSystemDnsPlanner.firstUsablePublicDnsServer(
            listOf(
                "local",
                "172.19.0.2",
                "udp://1.1.1.1",
            ),
        )

        assertEquals("1.1.1.1", resolved)
    }
}
