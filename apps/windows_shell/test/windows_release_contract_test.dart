import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows release contract requires POKROV Core 1.1.0', () async {
    final releaseConfig = File('../../config/windows-release.seed.json');
    final runtimeConfig = File('../../config/runtime-artifacts.seed.json');

    expect(await releaseConfig.exists(), isTrue);
    expect(await runtimeConfig.exists(), isTrue);

    final releaseJson =
        jsonDecode(await releaseConfig.readAsString()) as Map<String, dynamic>;
    final runtimeJson =
        jsonDecode(await runtimeConfig.readAsString()) as Map<String, dynamic>;

    final requiredFiles =
        (releaseJson['required_files'] as List<dynamic>).cast<String>();
    expect(releaseJson['channel'], 'outside_store_stable');
    expect(releaseJson['binary_name'], 'pokrov_windows.exe');
    expect(releaseJson['public_approved'], isTrue);
    expect(releaseJson['artifact_status'], 'unsigned_direct');
    expect(requiredFiles, contains('pokrov-core.dll'));
    expect(requiredFiles, contains('libcronet.dll'));
    expect(requiredFiles, contains('pokrov_tray.ico'));
    expect(requiredFiles, contains('pokrov_windows.exe'));
    expect(requiredFiles, contains('pokrov_service.exe'));
    expect(requiredFiles, isNot(contains('pokrov_windows_seed.exe')));

    final signing = releaseJson['signing'] as Map<String, dynamic>;
    expect(signing['status'], 'MISSING');
    expect(signing['blocker_code'], 'MISSING_TRUSTED_WINDOWS_SIGNATURE');
    expect(signing['required_for_candidate'], isTrue);
    expect(signing['contract'], 'AUTHENTICODE_SHA256_RFC3161_HTTPS_V1');
    expect(
      signing['required_signed_files'],
      containsAll(<String>[
        'pokrov_windows.exe',
        'pokrov_service.exe',
        'pokrov-windows-x64-{version}-setup.exe',
        'unins???.exe',
      ]),
    );
    expect(
      (signing['user_warning'] as String).toLowerCase(),
      contains('smartscreen'),
    );

    final runtime = releaseJson['runtime'] as Map<String, dynamic>;
    expect(runtime.containsKey('helper_binary'), isFalse);
    expect(runtime['service_binary'], 'pokrov_service.exe');
    expect(runtime['core_binary'], 'pokrov-core.dll');
    expect(runtime['release_tag'], 'v1.1.0');
    expect(runtime['desktop_abi'], 2);
    final crashProfile = runtime['crash_profile'] as Map<String, dynamic>;
    expect(crashProfile['format'], 'POKROV_WINDOWS_CRASH_V1');
    expect(crashProfile['mode'], 'stack_only');
    expect(crashProfile['max_frames'], 32);
    expect(crashProfile['full_memory_dump_default'], isFalse);
    expect(crashProfile['ui_storage'], 'per_user_private');
    expect(crashProfile['service_storage'], 'protected_service_private');
    expect(
      (runtime['runtime_dependencies'] as List<dynamic>).cast<String>(),
      contains('libcronet.dll'),
    );

    final core = runtimeJson['core'] as Map<String, dynamic>;
    final assets = core['assets'] as Map<String, dynamic>;
    final windows = assets['windows'] as Map<String, dynamic>;
    expect(windows.containsKey('helper'), isFalse);
    expect(core['release_tag'], 'v1.1.0');
    expect(core['release_tag_created'], isFalse);
    expect(core['activation_state'], 'active_pre_candidate_local');
    expect((core['desktop_abi'] as Map<String, dynamic>)['version'], 2);
    expect(windows['sync_policy'], 'exact_pre_candidate_build');
    expect(
      (windows['runtime_dependencies'] as List<dynamic>).cast<String>(),
      contains('libcronet.dll'),
    );
    expect(
      (releaseJson['portable_zip'] as Map<String, dynamic>)['supported'],
      isFalse,
    );
  });

  test('windows candidate signing is fail closed and secretless', () async {
    final buildScript = File('../../scripts/build-windows-release.ps1');
    final content = await buildScript.readAsString();

    for (final requiredMarker in <String>[
      'RequireTrustedWindowsSigning',
      'POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT',
      'POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT',
      'POKROV_WINDOWS_SIGNING_TIMESTAMP_URL',
      'Self-signed certificates cannot satisfy trusted Windows signing.',
      '1.3.6.1.5.5.7.3.3',
      '/fd", "SHA256',
      r'/tr", $SigningContext.timestamp_url',
      '/td", "SHA256',
      'Get-AuthenticodeSignature',
      'TimeStamperCertificate',
      'SignTool=POKROV',
      'SignedUninstaller=yes',
      'SignedUninstallerDir=',
      '/SPOKROV=',
      '"PASS"',
      'MISSING_TRUSTED_WINDOWS_SIGNATURE',
    ]) {
      expect(content, contains(requiredMarker));
    }
    for (final forbiddenMarker in <String>[
      'PFX_PASSWORD',
      'SIGNING_PASSWORD',
      'SecureStringToBSTR',
    ]) {
      expect(content, isNot(contains(forbiddenMarker)));
    }
  });

  test('windows setup registers bounded POKROV continuation protocol',
      () async {
    final buildScript = File('../../scripts/build-windows-release.ps1');
    final runner = File('windows/runner/main.cpp');
    final window = File('windows/runner/flutter_window.cpp');
    final activation = File('windows/runner/activation_protocol.cpp');
    final activationHeader = File('windows/runner/activation_protocol.h');
    final activationTest = File('windows/runner/activation_protocol_test.cpp');
    final cmake = File('windows/CMakeLists.txt');
    final trayIcon = File('windows/runner/resources/pokrov_tray.ico');
    final scriptContent = await buildScript.readAsString();
    final runnerContent = await runner.readAsString();
    final windowContent = await window.readAsString();
    final activationContent = await activation.readAsString();
    final activationHeaderContent = await activationHeader.readAsString();
    final activationTestContent = await activationTest.readAsString();
    final cmakeContent = await cmake.readAsString();

    expect(scriptContent, contains('Inno Setup 6'));
    expect(scriptContent, contains('DisableDirPage=no'));
    expect(scriptContent, contains('Languages\\Russian.isl'));
    expect(scriptContent, contains('#pragma code_page 65001'));
    expect(scriptContent, contains('Write-Utf8BomFile -Path \$issPath'));
    expect(scriptContent, contains('Name: "desktopicon"'));
    expect(scriptContent, isNot(contains('Name: "autostart"')));
    expect(scriptContent, contains('PrivilegesRequired=admin'));
    expect(scriptContent, contains('InstallOwnerSid'));
    expect(scriptContent, contains('ExecAsOriginalUser'));
    expect(scriptContent, contains('create POKROVService'));
    expect(scriptContent, contains('portable_zip.supported'));
    expect(windowContent, contains('Software\\\\Classes\\\\pokrov'));
    expect(windowContent, contains('URL Protocol'));
    expect(
      scriptContent,
      isNot(contains('Class=IEXPRESS')),
    );
    expect(activationContent, contains('pokrov://acquisition/continue?'));
    expect(runnerContent, contains('CreateMutexW'));
    expect(runnerContent, contains('Local\\\\POKROV.UI.'));
    expect(runnerContent, contains('POKROV_WINDOWS_UI_WINDOW_V1'));
    expect(runnerContent, contains('SendMessageTimeoutW'));
    expect(windowContent, contains('case WM_COPYDATA'));
    expect(windowContent, contains('pokrov::activation::Decode'));
    expect(activationHeaderContent, contains('kFrameVersion = 1'));
    expect(activationHeaderContent, contains('kMaxPayloadSize = 512'));
    expect(activationContent, contains('frame_size != kFrameHeaderSize'));
    expect(
        activationTestContent, contains('future frame version was accepted'));
    expect(
      windowContent,
      contains('space.pokrov/acquisition-links'),
    );
    expect(await trayIcon.exists(), isTrue);
    expect(await trayIcon.length(), greaterThan(1024));
    expect(cmakeContent, contains('pokrov_tray.ico'));
  });

  test('windows shell delegates TUN privilege and owns user preferences',
      () async {
    final window = File('windows/runner/flutter_window.cpp');
    final sharedShell =
        File('../../packages/app_shell/lib/src/shell/seed_shell.dart');
    final content = await window.readAsString();
    final sharedContent = await sharedShell.readAsString();

    expect(content, contains('space.pokrov/windows-shell'));
    expect(content, contains('readServiceStatus'));
    expect(content, isNot(contains('TokenElevation')));
    expect(content, isNot(contains('ShellExecuteW')));
    expect(content, isNot(contains('L"--connect"')));
    expect(sharedContent, contains('requestPokrovWindowsTunnelAuthorization'));
    expect(sharedContent, isNot(contains('systemProxy')));
    expect(content, contains('CloseToTray'));
    expect(content, contains('CurrentVersion\\\\Run'));
    expect(content, contains('executable + L" --startup"'));
    final authorizationIndex = sharedContent.indexOf(
      '!await _authorizeWindowsTunnelConnect()',
    );
    final actionInFlightIndex = sharedContent.indexOf(
      '_connectionCoordinator.beginAction(',
      authorizationIndex,
    );
    final coreConnectIndex = sharedContent.indexOf(
      '_runtimeEngine.connect',
      authorizationIndex,
    );
    expect(authorizationIndex, greaterThanOrEqualTo(0));
    expect(actionInFlightIndex, greaterThan(authorizationIndex));
    expect(coreConnectIndex, greaterThan(actionInFlightIndex));
  });

  test('windows service bootstrap owns a typed authenticated pipe', () async {
    final rootCmake = File('windows/CMakeLists.txt');
    final serviceCmake = File('windows/service/CMakeLists.txt');
    final serviceMain = File('windows/service/service_main.cpp');
    final server = File('windows/service/service_server.cpp');
    final client = File('windows/service/service_client.cpp');
    final window = File('windows/runner/flutter_window.cpp');
    final security = File('windows/service/service_security.cpp');
    final protocol = File('windows/service/service_protocol.h');
    final recovery = File('windows/service/service_recovery.cpp');
    final networkState = File('windows/service/service_network_state.cpp');
    final events = File('windows/service/service_events.cpp');
    final eventsHeader = File('windows/service/service_events.h');
    final eventsTest = File('windows/service/service_events_test.cpp');
    final runtime = File('windows/service/service_runtime.cpp');
    final integration = File(
      'windows/service/service_integration_test.cpp',
    );

    final rootContent = await rootCmake.readAsString();
    final cmakeContent = await serviceCmake.readAsString();
    final mainContent = await serviceMain.readAsString();
    final serverContent = await server.readAsString();
    final clientContent = await client.readAsString();
    final windowContent = await window.readAsString();
    final securityContent = await security.readAsString();
    final protocolContent = await protocol.readAsString();
    final recoveryContent = await recovery.readAsString();
    final networkStateContent = await networkState.readAsString();
    final eventsContent = await events.readAsString();
    final eventsHeaderContent = await eventsHeader.readAsString();
    final eventsTestContent = await eventsTest.readAsString();
    final runtimeContent = await runtime.readAsString();
    final integrationContent = await integration.readAsString();

    expect(rootContent, contains('add_subdirectory("service")'));
    expect(rootContent, contains('install(TARGETS pokrov_service'));
    expect(cmakeContent, contains('add_executable(pokrov_service'));
    expect(cmakeContent, contains('service_recovery.cpp'));
    expect(cmakeContent, contains('service_network_state.cpp'));
    expect(cmakeContent, contains('service_events.cpp'));
    expect(mainContent, contains('POKROVService'));
    expect(mainContent, contains('InstalledOwnerSid'));
    expect(mainContent, contains('StartServiceCtrlDispatcherW'));
    expect(mainContent, contains('SERVICE_ACCEPT_POWEREVENT'));
    expect(mainContent, contains('SERVICE_CONTROL_PRESHUTDOWN'));
    expect(mainContent, contains('PBT_APMSUSPEND'));
    expect(mainContent, contains('PBT_APMRESUMEAUTOMATIC'));
    expect(mainContent, contains('SystemBootEpochFileTime'));
    expect(mainContent, contains('RecordSystemBoot'));
    expect(securityContent, contains('ImpersonateNamedPipeClient'));
    expect(serverContent, contains('operation_replay'));
    expect(serverContent, contains('session_nonce_capacity'));
    expect(serverContent, contains('RecordIpcRequest'));
    expect(serverContent, contains('RecordIpcResponse'));
    expect(clientContent, contains('GetNamedPipeServerProcessId'));
    expect(clientContent, contains('QueryFullProcessImageNameW'));
    expect(clientContent, contains('WinLocalSystemSid'));
    expect(clientContent, contains('pokrov_service.exe'));
    expect(windowContent, contains('readServiceStatus'));
    expect(windowContent, contains('runtimeReady'));
    expect(securityContent, contains('(A;;GA;;;SY)'));
    expect(securityContent, contains('(A;;GA;;;BA)'));
    expect(securityContent, isNot(contains(';;;WD')));
    expect(securityContent, isNot(contains(';;;AN')));
    expect(protocolContent, contains('kProtocolVersion = 1'));
    expect(protocolContent, contains('kFrameHeaderSize = 80'));
    expect(protocolContent, contains('kMaxControlBodySize = 512'));
    expect(protocolContent, contains('kMaxProfileBodySize = 256 * 1024'));
    expect(recoveryContent, contains('POKROV_RECOVERY_V1'));
    expect(recoveryContent, contains('MOVEFILE_WRITE_THROUGH'));
    expect(recoveryContent, contains('RecoveryStage::kCommitted'));
    expect(recoveryContent, contains('network_state='));
    expect(networkStateContent, contains('POKROV_NETWORK_V1'));
    expect(networkStateContent, contains('kOwnedInterfaceName[] = L"POKROV"'));
    expect(networkStateContent, contains('GetInterfaceDnsSettings'));
    expect(networkStateContent, contains('DeleteIpForwardEntry2'));
    expect(networkStateContent, contains('DeleteUnicastIpAddressEntry'));
    expect(runtimeContent, contains('RecoverPendingRuntime'));
    expect(runtimeContent, contains('recovery_->BeginRollback()'));
    expect(runtimeContent, contains('recovery_->RestoreNetworkState()'));
    expect(runtimeContent, contains('Phase::kRecoveryRequired'));
    expect(runtimeContent, contains('kRuntimeAdapterApply'));
    expect(runtimeContent, contains('kRuntimeWintunStart'));
    expect(runtimeContent, contains('kRuntimeRouteApply'));
    expect(runtimeContent, contains('kRuntimeDnsApply'));
    expect(runtimeContent, contains('kRuntimeRollbackComplete'));
    expect(runtimeContent, contains('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'));
    expect(eventsHeaderContent, contains('kMaximumServiceEventJournalSize'));
    expect(eventsHeaderContent, contains('kMaximumPendingServiceEvents'));
    expect(eventsContent, contains('POKROV_SERVICE_EVENT_V1'));
    expect(eventsContent, contains('std::thread'));
    expect(eventsContent, contains('FlushFileBuffers'));
    expect(eventsContent, contains('MOVEFILE_WRITE_THROUGH'));
    expect(eventsTestContent,
        contains('event journal retained forbidden runtime material'));
    expect(integrationContent, contains('Status::kReplay'));
  });

  test('windows native crash profile is bounded and stack-only', () async {
    final runner = File('windows/runner/main.cpp');
    final serviceMain = File('windows/service/service_main.cpp');
    final source = File('windows/service/windows_crash_profile.cpp');
    final header = File('windows/service/windows_crash_profile.h');
    final nativeTest = File(
      'windows/service/windows_crash_profile_test.cpp',
    );
    final cmake = File('windows/service/CMakeLists.txt');

    final runnerContent = await runner.readAsString();
    final serviceMainContent = await serviceMain.readAsString();
    final sourceContent = await source.readAsString();
    final headerContent = await header.readAsString();
    final testContent = await nativeTest.readAsString();
    final cmakeContent = await cmake.readAsString();

    expect(runnerContent, contains('WindowsCrashProcess::kUi'));
    expect(serviceMainContent, contains('WindowsCrashProcess::kService'));
    expect(headerContent, contains('kMaximumWindowsCrashFrames = 32'));
    expect(headerContent, contains('kMaximumWindowsCrashRecordBytes = 2048'));
    expect(headerContent, contains('POKROV_WINDOWS_CRASH_V1'));
    expect(sourceContent, contains('SetUnhandledExceptionFilter'));
    expect(sourceContent, contains('RtlVirtualUnwind'));
    expect(sourceContent, contains('PROTECTED_DACL_SECURITY_INFORMATION'));
    expect(sourceContent, contains('ui-crash-profile.v1.previous.log'));
    expect(sourceContent, contains('service-crash-profile.v1.previous.log'));
    for (final forbidden in <String>[
      'MiniDumpWriteDump',
      'MiniDumpWithFullMemory',
      'LocalDumps',
      'WerFault',
      'SymFromAddr',
      'GetModuleFileName',
    ]) {
      expect(sourceContent, isNot(contains(forbidden)));
    }
    expect(testContent,
        contains('safe crash record retained forbidden runtime material'));
    expect(cmakeContent, contains('pokrov_windows_crash_profile_test'));
  });
}
