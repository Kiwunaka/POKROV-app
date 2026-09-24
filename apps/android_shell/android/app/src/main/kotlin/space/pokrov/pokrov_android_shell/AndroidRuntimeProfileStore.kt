package space.pokrov.pokrov_android_shell

import android.content.Context
import java.io.File

internal data class PersistedRuntimeProfile(
    val configPath: String,
    val configDigest: String = "",
    /** Route mode attached by Flutter to this exact staged config. */
    val routeMode: String = "",
    /**
     * Flutter has confirmed the first-connect route scope for this exact
     * freshly staged profile. Missing legacy metadata is deliberately false.
     */
    val quickSettingsEligible: Boolean = false,
    /** ATS input can start only with a live request/Core/deadline binding. */
    val requiresBoundConnect: Boolean = false,
    /** A catalog app signer snapshot must still exist in this process. */
    val catalogAppIdentityRequired: Boolean = false,
    /** Final client assembler applied explicit LAN scope; legacy profiles need restaging. */
    val lanScopeVersion: Int = 0,
    /** Mandatory for ordinary profiles; false only for signed offline emergency profiles. */
    val coreEgressProbeRequired: Boolean = true,
    /** Safe display-only metadata; never contains provider hosts or credentials. */
    val displayCountry: String = "",
    val displayNodeCode: String = "",
    val displayRouteMode: String = "",
)

internal fun PersistedRuntimeProfile.canStartFromQuickSettings(): Boolean =
    quickSettingsEligible && !requiresBoundConnect && !catalogAppIdentityRequired && lanScopeVersion == 1 &&
        routeMode.isNotBlank() && isRuntimeProfileDigest(configDigest)

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

internal const val RUNTIME_PROFILE_SCHEMA_VERSION = 1

internal enum class RuntimeProfileSchemaRoute {
    LEGACY_V0,
    CURRENT_V1,
    FORWARD_UNKNOWN,
}

internal fun runtimeProfileSchemaRoute(values: Map<String, *>): RuntimeProfileSchemaRoute {
    if (!values.containsKey("schema_version")) {
        return RuntimeProfileSchemaRoute.LEGACY_V0
    }
    return if (values["schema_version"] == RUNTIME_PROFILE_SCHEMA_VERSION) {
        RuntimeProfileSchemaRoute.CURRENT_V1
    } else {
        RuntimeProfileSchemaRoute.FORWARD_UNKNOWN
    }
}

internal fun runtimeProfileStorageValues(profile: PersistedRuntimeProfile): Map<String, Any> = mapOf(
    "schema_version" to RUNTIME_PROFILE_SCHEMA_VERSION,
    "config_path" to profile.configPath,
    "config_digest" to profile.configDigest,
    "route_mode" to profile.routeMode,
    "quick_settings_eligible" to profile.quickSettingsEligible,
    "requires_bound_connect" to profile.requiresBoundConnect,
    "catalog_app_identity_required" to profile.catalogAppIdentityRequired,
    "lan_scope_version" to profile.lanScopeVersion,
    "core_egress_probe_required" to profile.coreEgressProbeRequired,
    "display_country" to profile.displayCountry,
    "display_node_code" to profile.displayNodeCode,
    "display_route_mode" to profile.displayRouteMode,
)

internal fun decodeRuntimeProfileStorage(
    values: Map<String, *>,
    configExists: (String) -> Boolean,
): PersistedRuntimeProfile? {
    if (runtimeProfileSchemaRoute(values) == RuntimeProfileSchemaRoute.FORWARD_UNKNOWN) {
        return null
    }
    val configPath = (values["config_path"] as? String)
        ?.trim()
        ?.takeIf { it.isNotEmpty() && configExists(it) }
        ?: return null
    return PersistedRuntimeProfile(
        configPath = configPath,
        configDigest = (values["config_digest"] as? String)
            ?.takeIf(::isRuntimeProfileDigest).orEmpty(),
        routeMode = (values["route_mode"] as? String).orEmpty(),
        quickSettingsEligible = values["quick_settings_eligible"] as? Boolean ?: false,
        requiresBoundConnect = values.containsKey("requires_bound_connect") &&
            values["requires_bound_connect"] != false,
        catalogAppIdentityRequired = values["catalog_app_identity_required"] == true,
        lanScopeVersion = values["lan_scope_version"] as? Int ?: 0,
        coreEgressProbeRequired = values["core_egress_probe_required"] as? Boolean ?: true,
        displayCountry = (values["display_country"] as? String).orEmpty(),
        displayNodeCode = (values["display_node_code"] as? String).orEmpty(),
        displayRouteMode = (values["display_route_mode"] as? String).orEmpty(),
    )
}

/**
 * Keeps only the private materialized runtime path so the Quick Settings tile
 * can reuse the profile after the Flutter activity has left memory. Access
 * tokens, raw provider payloads and routing preferences never enter this store.
 */
internal object AndroidRuntimeProfileStore {
    private const val PREFERENCES_NAME = "pokrov_runtime_profile"

    @Synchronized
    fun save(context: Context, profile: PersistedRuntimeProfile) {
        val editor = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
        for ((key, value) in runtimeProfileStorageValues(profile)) {
            when (value) {
                is String -> editor.putString(key, value)
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
            }
        }
        check(editor.commit()) { "profile_staging_failed" }
    }

    @Synchronized
    fun load(context: Context): PersistedRuntimeProfile? {
        val preferences = context.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        val values = preferences.all
        val schemaRoute = runtimeProfileSchemaRoute(values)
        if (schemaRoute == RuntimeProfileSchemaRoute.FORWARD_UNKNOWN) {
            // Do not reuse or erase state owned by a newer app. This keeps the
            // current runtime fail-closed while preserving downgrade recovery.
            return null
        }
        val profile = decodeRuntimeProfileStorage(values) { path -> File(path).isFile }
        if (profile == null) {
            clear(context)
            return null
        }
        if (schemaRoute == RuntimeProfileSchemaRoute.LEGACY_V0) {
            if (runCatching { save(context, profile) }.isFailure) return null
        }
        return profile
    }

    @Synchronized
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

    /** A received lease revoke must survive tile/service reuse without Flutter.
     * Keep a concurrently staged different profile and the running TUN intact.
     * A failed commit is not acknowledged as durable invalidation.
     */
    @Synchronized
    fun invalidateMatchingProfile(context: Context, profileDigest: String): Boolean {
        val durable = try {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val values = preferences.all
            when {
                runtimeProfileSchemaRoute(values) == RuntimeProfileSchemaRoute.FORWARD_UNKNOWN -> false
                values["config_digest"] == profileDigest || values.isEmpty() ->
                    // commit() can clear memory even when the disk write fails.
                    // Retry that write instead of treating empty memory as proof.
                    preferences.edit().clear().commit()
                else -> preferences.edit().commit()
            }
        } catch (_: Exception) { false }
        AndroidRuntimeState.invalidateStagedProfile(expectedDigest = profileDigest)
        return durable
    }

    @Synchronized
    fun restoreIntoRuntimeState(context: Context): PersistedRuntimeProfile? {
        val profile = load(context) ?: return null
        AndroidRuntimeState.resolveEnvironment(context) ?: return null
        if (AndroidRuntimeState.stagedConfigPath().isNullOrBlank()) {
            AndroidRuntimeState.markProfileStaged(
                profile.configPath, profileDigest = profile.configDigest,
                requiresBoundConnect = profile.requiresBoundConnect,
            )
        }
        return profile
    }
}
