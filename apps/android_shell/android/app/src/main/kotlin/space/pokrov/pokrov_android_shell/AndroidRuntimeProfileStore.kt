package space.pokrov.pokrov_android_shell

import android.content.Context
import java.io.File

internal data class PersistedRuntimeProfile(
    val configPath: String,
    /** Route mode attached by Flutter to this exact staged config. */
    val routeMode: String = "",
    /**
     * Flutter has confirmed the first-connect route scope for this exact
     * freshly staged profile. Missing legacy metadata is deliberately false.
     */
    val quickSettingsEligible: Boolean = false,
    /** Mandatory for ordinary profiles; false only for signed offline emergency profiles. */
    val coreEgressProbeRequired: Boolean = true,
    /** Safe display-only metadata; never contains provider hosts or credentials. */
    val displayCountry: String = "",
    val displayNodeCode: String = "",
    val displayRouteMode: String = "",
)

internal fun PersistedRuntimeProfile.canStartFromQuickSettings(): Boolean =
    quickSettingsEligible && routeMode.isNotBlank()

internal fun coreEgressProbeRequiredForRuntime(
    profile: PersistedRuntimeProfile?,
    configPath: String,
): Boolean = profile
    ?.takeIf { it.configPath == configPath }
    ?.coreEgressProbeRequired
    ?: true

internal fun ownsLatestRuntimeServiceCommand(
    completedGeneration: Long?,
    currentGeneration: Long,
): Boolean = completedGeneration == null || completedGeneration == currentGeneration

/**
 * Keeps only the private materialized runtime path so the Quick Settings tile
 * can reuse the profile after the Flutter activity has left memory. Access
 * tokens, raw provider payloads and routing preferences never enter this store.
 */
internal object AndroidRuntimeProfileStore {
    private const val PREFERENCES_NAME = "pokrov_runtime_profile"
    private const val KEY_CONFIG_PATH = "config_path"
    private const val KEY_QUICK_SETTINGS_ELIGIBLE = "quick_settings_eligible"
    private const val KEY_CORE_EGRESS_PROBE_REQUIRED = "core_egress_probe_required"
    private const val KEY_ROUTE_MODE = "route_mode"
    private const val KEY_DISPLAY_COUNTRY = "display_country"
    private const val KEY_DISPLAY_NODE_CODE = "display_node_code"
    private const val KEY_DISPLAY_ROUTE_MODE = "display_route_mode"

    fun save(context: Context, profile: PersistedRuntimeProfile) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .putString(KEY_CONFIG_PATH, profile.configPath)
            .putString(KEY_ROUTE_MODE, profile.routeMode)
            .putBoolean(KEY_QUICK_SETTINGS_ELIGIBLE, profile.quickSettingsEligible)
            .putBoolean(KEY_CORE_EGRESS_PROBE_REQUIRED, profile.coreEgressProbeRequired)
            .putString(KEY_DISPLAY_COUNTRY, profile.displayCountry)
            .putString(KEY_DISPLAY_NODE_CODE, profile.displayNodeCode)
            .putString(KEY_DISPLAY_ROUTE_MODE, profile.displayRouteMode)
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
            routeMode = preferences.getString(KEY_ROUTE_MODE, "").orEmpty(),
            quickSettingsEligible = preferences.getBoolean(
                KEY_QUICK_SETTINGS_ELIGIBLE,
                false,
            ),
            coreEgressProbeRequired = preferences.getBoolean(
                KEY_CORE_EGRESS_PROBE_REQUIRED,
                true,
            ),
            displayCountry = preferences.getString(KEY_DISPLAY_COUNTRY, "").orEmpty(),
            displayNodeCode = preferences.getString(KEY_DISPLAY_NODE_CODE, "").orEmpty(),
            displayRouteMode = preferences.getString(KEY_DISPLAY_ROUTE_MODE, "").orEmpty(),
        )
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    /**
     * The egress probe has rejected the selected outbound. Commit the profile
     * deletion synchronously before dropping the in-memory staged pointer, so
     * a Quick Settings click cannot revive this configuration while Flutter is
     * absent.
     */
    @Synchronized
    fun failClosedAfterCoreEgressFailure(
        context: Context,
        failureKind: String,
        message: String,
        stopReason: String,
    ) {
        clear(context)
        AndroidRuntimeState.markStoppedAfterCoreEgressFailure(
            failureKind = failureKind,
            message = message,
            stopReason = stopReason,
        )
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
