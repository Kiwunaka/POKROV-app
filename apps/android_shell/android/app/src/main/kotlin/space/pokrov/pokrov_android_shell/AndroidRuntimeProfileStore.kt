package space.pokrov.pokrov_android_shell

import android.content.Context
import java.io.File

internal data class PersistedRuntimeProfile(
    val configPath: String,
)

/**
 * Keeps only the private materialized runtime path so the Quick Settings tile
 * can reuse the profile after the Flutter activity has left memory. Access
 * tokens, raw provider payloads and routing preferences never enter this store.
 */
internal object AndroidRuntimeProfileStore {
    private const val PREFERENCES_NAME = "pokrov_runtime_profile"
    private const val KEY_CONFIG_PATH = "config_path"

    fun save(context: Context, profile: PersistedRuntimeProfile) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .putString(KEY_CONFIG_PATH, profile.configPath)
            .apply()
    }

    fun load(context: Context): PersistedRuntimeProfile? {
        val preferences = context.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        val configPath = preferences.getString(KEY_CONFIG_PATH, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: return null
        if (!File(configPath).isFile) {
            clear(context)
            return null
        }
        return PersistedRuntimeProfile(
            configPath = configPath,
        )
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    fun restoreIntoRuntimeState(context: Context): PersistedRuntimeProfile? {
        val profile = load(context) ?: return null
        AndroidRuntimeState.resolveEnvironment(context) ?: return null
        if (AndroidRuntimeState.stagedConfigPath().isNullOrBlank()) {
            AndroidRuntimeState.markProfileStaged(profile.configPath)
        }
        return profile
    }
}
