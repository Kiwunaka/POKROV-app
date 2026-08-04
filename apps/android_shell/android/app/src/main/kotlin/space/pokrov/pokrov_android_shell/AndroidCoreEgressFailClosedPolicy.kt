package space.pokrov.pokrov_android_shell

/**
 * Decides whether a selected-outbound probe still owns the active TUN.
 *
 * The probe runs off the runtime executor, so it must not tear down a newer
 * connection after the service has started another generation or stopped.
 */
internal object AndroidCoreEgressFailClosedPolicy {
    fun shouldStopRuntime(
        probeResult: AndroidCoreEgressProbeResult,
        probeGeneration: Long,
        activeGeneration: Long,
        hasActiveTun: Boolean,
    ): Boolean =
        probeResult != AndroidCoreEgressProbeResult.HEALTHY &&
            probeGeneration == activeGeneration &&
            hasActiveTun
}
