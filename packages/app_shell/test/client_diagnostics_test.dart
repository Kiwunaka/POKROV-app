import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/features/diagnostics/client_diagnostics.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

PokrovDiagnosticsReport _report(WindowsLocalDpiRuntime? observation) {
  return PokrovDiagnosticsPresenter.fromRuntime(
    hostPlatform: HostPlatform.windows,
    routeMode: RouteMode.selectiveServices,
    snapshot: RuntimeSnapshot(
      hostPlatform: HostPlatform.windows,
      lane: RuntimeLane.windowsService,
      phase: RuntimePhase.running,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: true,
      canInitialize: true,
      canConnect: false,
      message: '',
      windowsLocalDpiAdmissionVersion: 1,
      windowsLocalDpiRuntime: observation,
    ),
    statusLabel: 'Подключено',
    warpState: 'disabled',
    now: DateTime.utc(2026, 10, 9),
    appVersion: '1.5.0',
    buildNumber: '4108',
    releaseChannel: 'private',
    candidateLabel: 'test',
    encryptedDeliveryAvailable: false,
  );
}

void main() {
  testWidgets('Windows selective Diagnostics separates unknown, withdrawal and VPN handoffs',
      (tester) async {
    var report = _report(null);
    await tester.pumpWidget(MaterialApp(
      home: PokrovDiagnosticsScreen(
        initialReport: report,
        onRefresh: () async => report,
        onOpenProtection: () {},
        onOpenSupport: () {},
      ),
    ));
    await tester.pumpAndSettle();
    final runtimeText = find.byKey(
      const ValueKey('diagnostics-windows-local-dpi-runtime'),
    );
    await tester.scrollUntilVisible(
      runtimeText,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<Text>(runtimeText).data,
        contains('Сведения о путях выбранных сервисов текущей сессии недоступны'));
    expect(tester.widget<Text>(runtimeText).data,
        isNot(contains('Сервисы текущей сессии: 0')));

    final counts = <String, int>{
      'services': 1,
      'admitted': 0,
      'failed': 0,
      'withdraw_completed': 1,
      'local_handoffs': 2,
      'vpn_handoffs': 0,
    };
    report = _report(WindowsLocalDpiRuntime.fromWire(counts)).copyWith(
      checkedAtUtc: DateTime.utc(2026, 10, 9),
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    final withdrawnText = tester.widget<Text>(runtimeText).data!;
    expect(withdrawnText,
        contains('Прямой путь снят, новый VPN-путь ещё не наблюдался'));
    expect(withdrawnText, contains('прямой путь — 2 · VPN-путь — 0'));

    counts['vpn_handoffs'] = 1;
    report = _report(WindowsLocalDpiRuntime.fromWire(counts));
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    final vpnText = tester.widget<Text>(runtimeText).data!;
    expect(vpnText,
        contains('Наблюдались передачи TCP выбранных сервисов в VPN-путь'));
    expect(vpnText, contains('VPN-путь — 1'));
    expect(vpnText, contains('TLS и доставка данных ими не подтверждаются'));
    expect(vpnText, isNot(contains('новый VPN-путь ещё не наблюдался')));
  });
}
