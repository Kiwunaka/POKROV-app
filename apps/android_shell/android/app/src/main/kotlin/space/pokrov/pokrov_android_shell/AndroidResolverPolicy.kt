package space.pokrov.pokrov_android_shell

/** Fixed, non-sensitive outcomes for the platform DNS bridge. */
internal object AndroidResolverPolicy {
    const val QUERY_FLAGS = 0
    const val RESPONSE_WAIT_MILLIS = 10_000L
    const val SERVFAIL_RCODE = 2
    const val RESPONSE_ERROR = "resolver_response_error"
    const val CALLBACK_ERROR = "resolver_callback_error"
    const val TIMEOUT = "resolver_timeout"

    internal enum class RuntimeOutcome {
        RESPONSE_RCODE,
        CALLBACK_ERROR,
        TIMEOUT,
        CANCELED,
    }

    internal fun shouldFailCloseRuntime(outcome: RuntimeOutcome): Boolean = when (outcome) {
        RuntimeOutcome.CALLBACK_ERROR,
        RuntimeOutcome.TIMEOUT -> true
        RuntimeOutcome.RESPONSE_RCODE,
        RuntimeOutcome.CANCELED -> false
    }
}
