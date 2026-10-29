import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';

void main() {

  test('arbitrary fields, paths and unbounded inputs are not accepted', () {
    expect(
      () => DiagnosticNetworkSummary(
        routeMode: '../../profile',
        connectionState: 'verified',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'healthy',
        warpState: 'disabled',
      ),
      throwsArgumentError,
    );
    expect(
      () => CollectedDiagnosticFile(
        path: '../raw/config.json',
        category: DiagnosticCategory.system,
        bytes: utf8.encode('{}'),
      ),
      throwsArgumentError,
    );
    for (final diagnostic in [
      {'endpoint': 'private.invalid'},
      {'egress_target': 'https://private.invalid'},
      {'egress_error_code': -1},
      {'dns_ready': 'false'},
    ]) {
      expect(() => DiagnosticNetworkSummary(
        routeMode: 'full_tunnel', connectionState: 'degraded', hostHealth: 'failed',
        dnsState: 'failed', egressState: 'failed', warpState: 'disabled',
        connectionDiagnostic: diagnostic,
      ), throwsArgumentError);
    }
  });

}

