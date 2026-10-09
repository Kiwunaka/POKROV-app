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
  });

}

