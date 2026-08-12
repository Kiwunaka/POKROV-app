package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class PokrovRuntimeNotificationTest {
    @Test
    fun `traffic rate uses compact readable units`() {
        assertEquals("0 Б/с", formatTrafficRate(-5L))
        assertEquals("900 Б/с", formatTrafficRate(900L))
        assertEquals("2 КБ/с", formatTrafficRate(2L * 1024L))
        assertEquals("1.5 МБ/с", formatTrafficRate(1572864L))
    }
}
