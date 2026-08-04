package space.pokrov.pokrov_android_shell

/**
 * Keeps host-visible runtime failures useful without forwarding native runtime
 * details such as profile values, topology, or credentials.
 */
internal object AndroidRuntimeSafety {
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
