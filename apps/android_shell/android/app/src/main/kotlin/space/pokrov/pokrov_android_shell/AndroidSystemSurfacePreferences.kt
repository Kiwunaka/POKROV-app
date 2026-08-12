package space.pokrov.pokrov_android_shell

import android.content.Context

internal data class AndroidSystemSurfacePreferences(
    val showCountry: Boolean = true,
    val showSpeed: Boolean = true,
    val showRouteMode: Boolean = true,
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
        return AndroidSystemSurfacePreferences(
            showCountry = preferences.getBoolean(KEY_SHOW_COUNTRY, true),
            showSpeed = preferences.getBoolean(KEY_SHOW_SPEED, true),
            showRouteMode = preferences.getBoolean(KEY_SHOW_ROUTE_MODE, true),
        )
    }

    fun save(context: Context, value: AndroidSystemSurfacePreferences) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SHOW_COUNTRY, value.showCountry)
            .putBoolean(KEY_SHOW_SPEED, value.showSpeed)
            .putBoolean(KEY_SHOW_ROUTE_MODE, value.showRouteMode)
            .apply()
    }
}
