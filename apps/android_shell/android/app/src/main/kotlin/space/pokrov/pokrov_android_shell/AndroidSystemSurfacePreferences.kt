package space.pokrov.pokrov_android_shell

import android.content.Context

internal data class AndroidSystemSurfacePreferences(
    val showCountry: Boolean = false,
    val showSpeed: Boolean = false,
    val showRouteMode: Boolean = false,
) {
    fun toMap(): Map<String, Boolean> = mapOf(
        "showCountry" to showCountry,
        "showSpeed" to showSpeed,
        "showRouteMode" to showRouteMode,
    )
}

internal object AndroidSystemSurfacePreferencesStore {
    private const val PREFERENCES_NAME = "pokrov_system_surfaces"
    private const val KEY_SHOW_COUNTRY = "show_country"
    private const val KEY_SHOW_SPEED = "show_speed"
    private const val KEY_SHOW_ROUTE_MODE = "show_route_mode"

    fun load(context: Context): AndroidSystemSurfacePreferences {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        if (preferences.getBoolean(KEY_SHOW_COUNTRY, false) ||
            preferences.getBoolean(KEY_SHOW_SPEED, false) ||
            preferences.getBoolean(KEY_SHOW_ROUTE_MODE, false)
        ) {
            save(context)
        }
        return AndroidSystemSurfacePreferences()
    }

    fun save(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SHOW_COUNTRY, false)
            .putBoolean(KEY_SHOW_SPEED, false)
            .putBoolean(KEY_SHOW_ROUTE_MODE, false)
            .apply()
    }
}
