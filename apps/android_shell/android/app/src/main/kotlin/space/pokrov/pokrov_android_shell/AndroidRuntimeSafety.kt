package space.pokrov.pokrov_android_shell

/**
 * Keeps host-visible runtime failures useful without forwarding native runtime
 * details such as profile values, topology, or credentials.
 */
internal object AndroidRuntimeSafety {
    private val safeCoreFailureTerms = listOf(
        "decode",
        "parse",
        "initialize",
        "create",
        "unknown",
        "missing",
        "failed",
        "unavailable",
        "permission",
        "invalid",
        "unsupported",
        "deprecated",
        "duplicate",
        "empty",
        "field",
        "config",
        "json",
        "log",
        "network",
        "connect",
        "connection",
        "timeout",
        "deadline",
        "resolve",
        "read",
        "write",
        "closed",
        "refused",
        "reset",
        "unreachable",
        "tcp",
        "udp",
        "handshake",
        "certificate",
        "authentication",
        "unauthorized",
        "rejected",
        "exceeded",
        "canceled",
        "platform",
        "interface",
        "router",
        "client",
        "dialer",
        "service",
        "file",
        "path",
        "cache",
        "dns",
        "server",
        "servers",
        "address",
        "inbounds",
        "inbound",
        "outbounds",
        "outbound",
        "endpoints",
        "endpoint",
        "route",
        "rules",
        "rule",
        "rule_set",
        "rule-set",
        "process_name",
        "domain_suffix",
        "protocol",
        "ip_is_private",
        "auto_detect_interface",
        "final",
        "default",
        "experimental",
        "cache_file",
        "type",
        "tag",
        "server_port",
        "uuid",
        "tls",
        "utls",
        "reality",
        "public_key",
        "short_id",
        "packet_encoding",
        "flow",
        "transport",
        "detour",
        "selector",
        "direct",
        "block",
        "mixed",
        "tun",
        "warp",
        "vless",
    )

    fun safeFailureTypes(error: Throwable): String {
        val types = mutableListOf<String>()
        var current: Throwable? = error
        while (current != null && types.size < 4) {
            val name = current.javaClass.simpleName
            types += name.takeIf { it.matches(Regex("[A-Za-z0-9_$]{1,64}")) } ?: "Throwable"
            current = current.cause
        }
        return types.joinToString(">")
    }

    fun safeFailureCategory(error: Throwable): String {
        var current: Throwable? = error
        repeat(4) {
            when (current) {
                is SecurityException -> return "security_exception"
                is LinkageError -> return "native_linkage_error"
                is java.io.IOException -> return "io_exception"
                is IllegalArgumentException -> return "invalid_runtime_config"
                is IllegalStateException -> return "invalid_runtime_state"
            }
            current = current?.cause
        }
        return "runtime_exception"
    }

    fun safeCoreFailureHints(error: Throwable): String {
        val text = generateSequence(error as Throwable?) { it.cause }
            .take(4)
            .mapNotNull { it.message?.lowercase() }
            .joinToString(" ")
        return safeCoreFailureHints(text)
    }

    fun safeCoreFailureHints(text: String): String {
        val normalized = text.lowercase()
        return safeCoreFailureTerms
            .filter { term -> Regex("(^|[^a-z0-9_])${Regex.escape(term)}([^a-z0-9_]|$)").containsMatchIn(normalized) }
            .take(12)
            .joinToString(",")
            .ifEmpty { "unclassified" }
    }

    fun publicFailureMessage(kind: String): String = when {
        kind.startsWith("dns_") ->
            "POKROV подключил системный VPN, но DNS через защищенный канал не работает."
        kind.startsWith("vless_") ||
            kind.startsWith("reality_") ||
            kind == "tls_handshake_failed" ->
            "POKROV подключил системный VPN, но защищенный канал до локации не отвечает."
        else -> publicHostFailureMessage(kind)
    }

    private fun publicHostFailureMessage(kind: String): String = when (kind) {
        "runtime_initialization_failed" ->
            "POKROV не смог подготовить устройство."
        "runtime_start_after_permission_failed",
        "runtime_start_failed",
        "runtime_service_start_failed" ->
            "POKROV не смог подключиться на этом устройстве."
        "foreground_start_failed" ->
            "POKROV не смог запустить системное подключение."
        "runtime_stop_failed" ->
            "POKROV не смог корректно отключиться."
        "core_egress_probe_failed" ->
            "POKROV не подтвердил защищенное подключение и отключил системный VPN."
        "core_egress_probe_unavailable" ->
            "POKROV не завершил проверку защищенного подключения и отключил системный VPN. Попробуйте еще раз."
        "profile_staging_failed" ->
            "POKROV не смог подготовить настройки подключения."
        "config_apply_failed" ->
            "POKROV не смог применить настройки подключения."
        "notification_permission_denied" ->
            "Системное уведомление POKROV скрыто в настройках Android."
        "resolver_response_error",
        "resolver_callback_error",
        "resolver_timeout",
        "default_network_unavailable" ->
            "POKROV не смог подтвердить DNS-подключение устройства."
        else -> "POKROV не смог завершить это действие на устройстве."
    }
}
