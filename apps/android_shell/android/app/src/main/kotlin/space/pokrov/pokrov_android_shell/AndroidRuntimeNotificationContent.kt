package space.pokrov.pokrov_android_shell

internal enum class AndroidRuntimeNotificationState {
    CONNECTING,
    CONNECTED,
    RECONNECTING,
    FAILED,
}

internal data class AndroidRuntimeNotificationContent(
    val title: String,
    val text: String,
)

internal fun androidRuntimeNotificationContent(
    state: AndroidRuntimeNotificationState,
): AndroidRuntimeNotificationContent = AndroidRuntimeNotificationContent(
    title = "POKROV",
    text = when (state) {
        AndroidRuntimeNotificationState.CONNECTING -> "Защита подключается"
        AndroidRuntimeNotificationState.CONNECTED -> "Защита включена"
        AndroidRuntimeNotificationState.RECONNECTING -> "Защита восстанавливается"
        AndroidRuntimeNotificationState.FAILED -> "Защита требует внимания"
    },
)
