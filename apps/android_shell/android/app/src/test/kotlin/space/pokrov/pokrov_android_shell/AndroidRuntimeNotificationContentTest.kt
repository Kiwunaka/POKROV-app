package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AndroidRuntimeNotificationContentTest {
    @Test
    fun egressValidationPreventsFalseGreenNotification() {
        assertEquals(
            AndroidRuntimeNotificationState.CONNECTING,
            androidRuntimeNotificationStateForEgress(
                validationRequired = true,
                validated = null,
            ),
        )
        assertEquals(
            AndroidRuntimeNotificationState.FAILED,
            androidRuntimeNotificationStateForEgress(
                validationRequired = true,
                validated = false,
            ),
        )
        assertEquals(
            AndroidRuntimeNotificationState.CONNECTED,
            androidRuntimeNotificationStateForEgress(
                validationRequired = true,
                validated = true,
            ),
        )
        assertEquals(
            AndroidRuntimeNotificationState.CONNECTED,
            androidRuntimeNotificationStateForEgress(
                validationRequired = false,
                validated = null,
            ),
        )
    }

    @Test
    fun everyRuntimeStateUsesOnlyGenericPrivacySafeText() {
        val expected = mapOf(
            AndroidRuntimeNotificationState.CONNECTING to "Защита подключается",
            AndroidRuntimeNotificationState.CONNECTED to "Защита включена",
            AndroidRuntimeNotificationState.RECONNECTING to "Защита восстанавливается",
            AndroidRuntimeNotificationState.FAILED to "Защита требует внимания",
        )

        expected.forEach { (state, text) ->
            val content = androidRuntimeNotificationContent(state)
            assertEquals("POKROV", content.title)
            assertEquals(text, content.text)
            val rendered = "${content.title} ${content.text}".lowercase()
            listOf(
                "страна",
                "германия",
                "маршрут",
                "режим",
                "прилож",
                "скорост",
                "мбит",
                "warp",
                "endpoint",
            ).forEach { forbidden ->
                assertFalse("notification leaked $forbidden", rendered.contains(forbidden))
            }
        }
    }
}
