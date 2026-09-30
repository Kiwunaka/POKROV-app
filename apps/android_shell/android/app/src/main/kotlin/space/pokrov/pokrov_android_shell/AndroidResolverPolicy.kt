package space.pokrov.pokrov_android_shell

/** Fixed, non-sensitive outcomes for the platform DNS bridge. */
internal object AndroidResolverPolicy {
    const val QUERY_FLAGS = 0
    const val RESPONSE_WAIT_MILLIS = 10_000L
    const val SERVFAIL_RCODE = 2
    const val RESPONSE_ERROR = "resolver_response_error"
    const val CALLBACK_ERROR = "resolver_callback_error"
    const val TIMEOUT = "resolver_timeout"

    internal fun isSingleIpv6Question(message: ByteArray): Boolean {
        if (message.size < 12 || (message[2].toInt() and 0xf8) != 0 ||
            message[4].toInt() != 0 || message[5].toInt() != 1) return false
        var offset = 12
        while (offset < message.size) {
            val length = message[offset++].toInt() and 0xff
            if (length == 0) {
                return offset - 12 <= 255 && offset + 4 <= message.size &&
                    message[offset].toInt() == 0 && message[offset + 1].toInt() == 28 &&
                    message[offset + 2].toInt() == 0 && message[offset + 3].toInt() == 1
            }
            // Compressed or malformed questions remain unknown at this boundary.
            if (length > 63 || offset + length >= message.size || offset - 12 + length > 255) return false
            offset += length
        }
        return false
    }

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
