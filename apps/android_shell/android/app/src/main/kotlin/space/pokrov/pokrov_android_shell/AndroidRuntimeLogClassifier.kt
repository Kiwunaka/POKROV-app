package space.pokrov.pokrov_android_shell

/** Maps sensitive native runtime messages to a fixed, non-sensitive category. */
internal object AndroidRuntimeLogClassifier {
    fun parseAwgSafeDiagnostic(message: String): AndroidAwgSafeDiagnostic? {
        val match = AWG_SAFE_DIAGNOSTIC_PATTERN.matchEntire(message) ?: return null
        val code = match.groupValues[1]
        if (code !in AWG_SAFE_DIAGNOSTIC_CODES) {
            return null
        }
        return AndroidAwgSafeDiagnostic(
            code = code,
            occurrence = match.groupValues[2].toInt(),
        )
    }

    fun classify(message: String): String? {
        val normalized = message.lowercase()
        return when {
            "reality verification failed" in normalized ->
                "reality_verification_failed"
            "reality" in normalized && "utls" in normalized &&
                ("required" in normalized || "unavailable" in normalized || hasFailureMarker(normalized)) ->
                "reality_utls_unavailable"
            "reality" in normalized &&
                ("connection reset" in normalized || "reset by peer" in normalized) ->
                "reality_connection_reset"
            "reality" in normalized && "eof" in normalized ->
                "reality_unexpected_eof"
            "reality" in normalized &&
                ("timeout" in normalized ||
                    "timed out" in normalized ||
                    "deadline exceeded" in normalized) ->
                "reality_timeout"
            "reality" in normalized && hasFailureMarker(normalized) ->
                "reality_handshake_failed"
            "vless" in normalized &&
                ("dns" in normalized || "lookup" in normalized || "resolve" in normalized) &&
                hasFailureMarker(normalized) ->
                "vless_dns_failed"
            "vless" in normalized &&
                ("connection reset" in normalized || "reset by peer" in normalized) ->
                "vless_connection_reset"
            "vless" in normalized && "eof" in normalized ->
                "vless_unexpected_eof"
            "vless" in normalized &&
                ("tls" in normalized || "certificate" in normalized) &&
                hasFailureMarker(normalized) ->
                "vless_tls_failed"
            "vless" in normalized && "handshake" in normalized && hasFailureMarker(normalized) ->
                "vless_handshake_failed"
            "vless" in normalized && "connection refused" in normalized ->
                "vless_connection_refused"
            "vless" in normalized &&
                ("network is unreachable" in normalized || "no route to host" in normalized) ->
                "vless_network_unreachable"
            "vless" in normalized &&
                ("timeout" in normalized ||
                    "timed out" in normalized ||
                    "deadline exceeded" in normalized) ->
                "vless_timeout"
            "vless" in normalized &&
                ("authentication" in normalized || "unauthorized" in normalized) &&
                hasFailureMarker(normalized) ->
                "vless_authentication_failed"
            "vless" in normalized && "invalid" in normalized ->
                "vless_invalid_response"
            "vless" in normalized && "rejected" in normalized ->
                "vless_rejected"
            "vless" in normalized &&
                ("context canceled" in normalized || "context cancelled" in normalized) ->
                "vless_context_cancelled"
            "vless" in normalized &&
                ("closed network connection" in normalized ||
                    "connection closed" in normalized ||
                    "connection aborted" in normalized) ->
                "vless_connection_closed"
            "vless" in normalized && "broken pipe" in normalized ->
                "vless_broken_pipe"
            "vless" in normalized && "upload" in normalized && hasFailureMarker(normalized) ->
                "vless_upload_failed"
            "vless" in normalized && "download" in normalized && hasFailureMarker(normalized) ->
                "vless_download_failed"
            "vless" in normalized && "packet conn" in normalized && hasFailureMarker(normalized) ->
                "vless_packet_session_failed"
            "vless" in normalized && "connection to" in normalized && hasFailureMarker(normalized) ->
                "vless_outbound_connect_failed"
            "vless" in normalized && "process connection" in normalized && hasFailureMarker(normalized) ->
                "vless_process_failed"
            "vless" in normalized && hasFailureMarker(normalized) ->
                "vless_session_failed"
            "tls" in normalized && "handshake" in normalized && hasFailureMarker(normalized) ->
                "tls_handshake_failed"
            "dns" in normalized && hasFailureMarker(normalized) -> classifyDns(normalized)
            "connection reset" in normalized || "reset by peer" in normalized ->
                "outbound_connection_reset"
            "network is unreachable" in normalized || "no route to host" in normalized ->
                "outbound_network_unreachable"
            "timeout" in normalized || "timed out" in normalized || "deadline exceeded" in normalized ->
                "outbound_timeout"
            else -> null
        }
    }

    /**
     * Core debug callbacks are request-scoped and do not identify the selected
     * outbound. They remain observable categories only; Android VPN validation
     * and explicit platform prerequisite failures own the global tunnel health.
     */
    fun affectsRuntimeHealth(category: String): Boolean = false

    private fun classifyDns(message: String): String = when {
        "missing default interface" in message -> "dns_default_interface_missing"
        "connection refused" in message -> "dns_connection_refused"
        "network is unreachable" in message || "no route to host" in message ->
            "dns_network_unreachable"
        "timeout" in message || "timed out" in message || "deadline exceeded" in message ->
            "dns_timeout"
        "lookup" in message || "resolve" in message -> "dns_lookup_failed"
        "exchange" in message -> "dns_exchange_failed"
        "context canceled" in message || "context cancelled" in message ->
            "dns_context_cancelled"
        else -> "dns_runtime_error"
    }

    private fun hasFailureMarker(message: String): Boolean =
        "failed" in message ||
            "failure" in message ||
            "error" in message ||
            "rejected" in message ||
            "invalid" in message ||
            "reset" in message ||
            "eof" in message

    private val AWG_SAFE_DIAGNOSTIC_PATTERN =
        Regex("awg_safe_diag code=([a-z_]+) occurrence=([1-4])")

    private val AWG_SAFE_DIAGNOSTIC_CODES = setOf(
        "receive_unknown_type",
        "receive_invalid_mac1",
        "receive_invalid_response",
        "receive_decode_response",
        "receive_handshake_response",
        "send_handshake_initiation",
        "handshake_give_up",
        "handshake_retry",
        "receive_error",
        "send_handshake_error",
        "upstream_error",
    )
}

internal data class AndroidAwgSafeDiagnostic(
    val code: String,
    val occurrence: Int,
) {
    fun canonicalMessage(): String = "awg_safe_diag code=$code occurrence=$occurrence"
}

internal data class AndroidRuntimeLogEvent(
    val category: String,
    val suppressedSinceLastEmission: Long,
)

/** Keeps request-scoped Core failures observable without flooding logcat. */
internal class AndroidRuntimeLogLimiter(
    private val emissionIntervalMillis: Long = DEFAULT_EMISSION_INTERVAL_MILLIS,
    private val clockMillis: () -> Long = { System.nanoTime() / 1_000_000L },
) {
    private data class CategoryState(
        var lastEmissionMillis: Long,
        var suppressedSinceLastEmission: Long,
    )

    private val categories = mutableMapOf<String, CategoryState>()

    init {
        require(emissionIntervalMillis > 0L)
    }

    @Synchronized
    fun record(category: String): AndroidRuntimeLogEvent? {
        val now = clockMillis()
        val state = categories[category]
        if (state == null) {
            categories[category] = CategoryState(
                lastEmissionMillis = now,
                suppressedSinceLastEmission = 0L,
            )
            return AndroidRuntimeLogEvent(category, 0L)
        }
        if (now - state.lastEmissionMillis < emissionIntervalMillis) {
            state.suppressedSinceLastEmission += 1L
            return null
        }
        val suppressed = state.suppressedSinceLastEmission
        state.lastEmissionMillis = now
        state.suppressedSinceLastEmission = 0L
        return AndroidRuntimeLogEvent(category, suppressed)
    }

    @Synchronized
    fun reset() {
        categories.clear()
    }

    private companion object {
        const val DEFAULT_EMISSION_INTERVAL_MILLIS = 10_000L
    }
}
