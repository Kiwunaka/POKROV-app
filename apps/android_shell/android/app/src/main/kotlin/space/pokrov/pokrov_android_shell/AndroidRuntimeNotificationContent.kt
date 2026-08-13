package space.pokrov.pokrov_android_shell

internal data class AndroidRuntimeNotificationContent(
    val title: String,
    val compactText: String,
    val expandedLines: List<String>,
)

internal fun androidRuntimeNotificationContent(
    country: String,
    routeLabel: String,
    speedLabel: String,
    enhancedProtectionActive: Boolean = false,
): AndroidRuntimeNotificationContent {
    val normalizedCountry = androidRuntimeCountryLabel(country)
    val normalizedRoute = routeLabel.trim()
    val normalizedSpeed = speedLabel.trim()
    val compactParts = listOf(normalizedCountry, normalizedRoute)
        .filter(String::isNotEmpty)
    val expandedLines = buildList {
        if (normalizedCountry.isNotEmpty()) {
            add("Страна: $normalizedCountry")
        }
        if (normalizedRoute.isNotEmpty()) {
            add("Режим: $normalizedRoute")
        }
        if (normalizedSpeed.isNotEmpty()) {
            add(
                if (normalizedSpeed.startsWith("Скорость:")) {
                    normalizedSpeed
                } else {
                    "Скорость: $normalizedSpeed"
                },
            )
        }
    }.ifEmpty { listOf("Защита включена") }

    return AndroidRuntimeNotificationContent(
        title = if (enhancedProtectionActive) "POKROV · WARP" else "POKROV включен",
        compactText = compactParts.joinToString(" · ").ifEmpty {
            normalizedSpeed.ifEmpty { "Защита включена" }
        },
        expandedLines = expandedLines,
    )
}

internal fun androidRuntimeCountryLabel(value: String): String {
    val normalized = value.trim()
    return when (normalized.lowercase()) {
        "de", "germany", "deutschland" -> "Германия"
        "it", "italy", "italia" -> "Италия"
        "nl", "netherlands", "the netherlands", "nederland" -> "Нидерланды"
        "pl", "poland", "polska" -> "Польша"
        "ru", "russia", "russian federation" -> "Россия"
        "us", "usa", "united states", "united states of america" -> "США"
        else -> normalized
    }
}
