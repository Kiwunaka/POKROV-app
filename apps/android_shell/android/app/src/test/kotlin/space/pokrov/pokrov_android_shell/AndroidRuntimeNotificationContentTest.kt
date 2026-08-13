package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidRuntimeNotificationContentTest {
    @Test
    fun activeNotificationKeepsCollapsedTextShortAndExpandedDetailsReadable() {
        val content = androidRuntimeNotificationContent(
            country = "Нидерланды",
            routeLabel = "РФ напрямую",
            speedLabel = "↓ 12 Мбит/с  ↑ 3 Мбит/с",
        )

        assertEquals("POKROV включен", content.title)
        assertEquals("Нидерланды · РФ напрямую", content.compactText)
        assertEquals(
            listOf(
                "Страна: Нидерланды",
                "Режим: РФ напрямую",
                "Скорость: ↓ 12 Мбит/с  ↑ 3 Мбит/с",
            ),
            content.expandedLines,
        )
    }

    @Test
    fun speedOnlyPreferenceKeepsAUsefulCollapsedNotification() {
        val content = androidRuntimeNotificationContent(
            country = "",
            routeLabel = "",
            speedLabel = "Скорость: измеряем…",
        )

        assertEquals("Скорость: измеряем…", content.compactText)
        assertEquals(listOf("Скорость: измеряем…"), content.expandedLines)
    }

    @Test
    fun warpNotificationUsesCompactStatusAndLocalizesApiCountry() {
        val content = androidRuntimeNotificationContent(
            country = "Italy",
            routeLabel = "Выбранные приложения",
            speedLabel = "",
            enhancedProtectionActive = true,
        )

        assertEquals("POKROV · WARP", content.title)
        assertEquals("Италия · Выбранные приложения", content.compactText)
        assertEquals(
            listOf("Страна: Италия", "Режим: Выбранные приложения"),
            content.expandedLines,
        )
    }

    @Test
    fun statusOnlyPreferenceNeverProducesAnEmptyNotification() {
        val content = androidRuntimeNotificationContent(
            country = "",
            routeLabel = "",
            speedLabel = "",
        )

        assertEquals("Защита включена", content.compactText)
        assertEquals(listOf("Защита включена"), content.expandedLines)
    }
}
