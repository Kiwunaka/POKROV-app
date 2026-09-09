package space.pokrov.pokrov_android_shell

import java.security.MessageDigest

internal fun isRuntimeProfileDigest(value: String?): Boolean =
    value != null && Regex("^[0-9a-f]{64}$").matches(value)

/** Content and execution options, not a server assignment revision. */
internal fun runtimeProfileDigest(
    content: String,
    routeMode: String,
    coreEgressProbeRequired: Boolean,
): String {
    val request = "${if (coreEgressProbeRequired) 1 else 0}\n$routeMode\n$content"
    return MessageDigest.getInstance("SHA-256")
        .digest(request.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

internal fun runtimeProfileMatchesIntent(
    profile: PersistedRuntimeProfile?,
    expectedDigest: String,
    configPath: String,
    routeMode: String,
    content: String,
): Boolean = profile != null &&
    isRuntimeProfileDigest(expectedDigest) &&
    profile.configDigest == expectedDigest &&
    profile.configPath == configPath &&
    profile.routeMode == routeMode &&
    runtimeProfileDigest(content, routeMode, profile.coreEgressProbeRequired) == expectedDigest
