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
}

Map<String, Object?> _json(String path) {
  return Map<String, Object?>.from(
    jsonDecode(_text(path)) as Map,
  );
}

String _text(String path) {
  return File(path).readAsStringSync();
}
