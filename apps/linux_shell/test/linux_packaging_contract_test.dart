import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux service packaging keeps UI non-root and mutations behind polkit',
      () {
    final layout = _json('packaging/install-layout.v1.json');
    final socket = _text('packaging/systemd/pokrov-linuxd.socket');
    final service = _text('packaging/systemd/pokrov-linuxd.service');
    final policy = _text('packaging/polkit/space.pokrov.linux.policy');

    expect(layout['ui_user'], 'non-root');
    expect(layout['daemon_user'], 'root');
    expect(layout['runtime_socket'], '/run/pokrov/pokrov-linuxd.sock');
    expect(socket, contains('SocketMode=0666'));
    expect(socket, contains('RemoveOnStop=yes'));
    expect(service, contains('User=root'));
    expect(service, contains('NoNewPrivileges=yes'));
    expect(service, contains('ProtectSystem=strict'));
    expect(service, contains('CapabilityBoundingSet=CAP_NET_ADMIN'));
    expect(service, isNot(contains('AmbientCapabilities=CAP_')));
    expect(policy, contains('space.pokrov.linux.manage'));
    expect(policy, contains('<allow_active>auth_admin_keep</allow_active>'));
    expect(policy, isNot(contains('<allow_any>yes</allow_any>')));
  });

  test('Linux support matrix has one exact foundation row and explicit backlog',
      () {
    final matrix = _json('daemon/internal/host/support-matrix.v1.json');
    final entries = List<Map<String, Object?>>.from(
      (matrix['entries']! as List).map(
        (entry) => Map<String, Object?>.from(entry as Map),
      ),
    );
    final supported = entries
        .where((entry) => entry['status'] == 'foundation_supported')
        .toList(growable: false);
    final pending = entries
        .where(
          (entry) => entry['status'] == 'pending_package_and_runtime_proof',
        )
        .toList(growable: false);

    expect(matrix['schema'], 'pokrov-linux-support-matrix-v1');
    expect(supported, hasLength(1));
    expect(supported.single['id'], 'ubuntu-24.04-amd64');
    expect(
      supported.single['desktop'],
      'exact_vm_session_proof_pending',
    );
    expect(supported.single['network_manager'], 'NetworkManager');
    expect(supported.single['dns_manager'], 'systemd-resolved');
    expect(supported.single['firewall'], 'nftables');
    expect(pending.any((entry) => entry['distro_id'] == 'fedora'), isTrue);
  });

  test('Linux network transaction events stay closed and fail-closed', () {
    final journal = _text('daemon/internal/journal/journal.go');
    final recorder = _text('daemon/internal/networktxn/recorder.go');
    final service = _text('daemon/internal/service/service_linux.go');

    for (final value in <String>[
      'network_transaction',
      'network_manager',
      'resolved',
      'nftables',
      'checkpoint',
      'apply',
      'rollback',
      'linux_network_checkpoint_failed',
      'linux_network_apply_failed',
      'linux_network_rollback_failed',
    ]) {
      expect(journal, contains(value), reason: value);
    }
    expect(recorder, contains('func (recorder Recorder) Checkpoint'));
    expect(recorder, contains('func (recorder Recorder) Apply'));
    expect(recorder, contains('func (recorder Recorder) Rollback'));
    expect(recorder, isNot(contains('exec.Command')));
    expect(recorder, isNot(contains('os/exec')));
    expect(service, contains('recordUnavailableNetworkTransaction'));
    expect(service, contains('networktxn.Unsupported'));
    expect(service, contains('linux_live_connect_unavailable'));
  });

  test('Linux polkit D-Bus decisions use a closed authorization trace', () {
    final auth = _text('daemon/internal/auth/peer_linux.go');
    final journal = _text('daemon/internal/journal/journal.go');
    final service = _text('daemon/internal/service/service_linux.go');

    for (final value in <String>[
      'polkit_dbus',
      'peer_credential',
      'DecisionAuthorized',
      'DecisionDenied',
      'DecisionAgentUnavailable',
      'DecisionDismissed',
      'DecisionTimeout',
      'DecisionUnavailable',
    ]) {
      expect(auth, contains(value), reason: value);
    }
    for (final value in <String>[
      'authorization',
      'POKROV_AUTHORIZATION_BACKEND',
      'linux_authorization_denied',
      'linux_authorization_agent_unavailable',
      'linux_authorization_dismissed',
      'linux_authorization_timeout',
      'linux_authorization_unavailable',
    ]) {
      expect(journal, contains(value), reason: value);
    }
    expect(service, contains('authorizationEvent'));
    expect(journal, isNot(contains('POKROV_PEER_PID')));
    expect(journal, isNot(contains('POKROV_PEER_UID')));
    expect(journal, isNot(contains('POKROV_RAW_ERROR')));
  });
}

Map<String, Object?> _json(String path) {
  return Map<String, Object?>.from(
    jsonDecode(_text(path)) as Map,
  );
}

String _text(String path) {
  return File(path).readAsStringSync();
}
