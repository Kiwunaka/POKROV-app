import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('coordinator serializes checks and deduplicates the same release',
      () async {
    final coordinator = ClientUpdateCoordinator();
    final firstMetadata = Completer<ClientAppsMetadata>();
    var loadCalls = 0;
    var availableReports = 0;
    var presentations = 0;
    var failures = 0;

    Future<void> check() => coordinator.checkAndPresent(
          loadMetadata: () {
            loadCalls += 1;
            return loadCalls == 1
                ? firstMetadata.future
                : Future<ClientAppsMetadata>.value(_updateMetadata);
          },
          hostPlatform: HostPlatform.android,
          isActive: () => true,
          onUpdateAvailable: () => availableReports += 1,
          presentUpdate: (_) async {
            presentations += 1;
          },
          onFailure: (_, __) => failures += 1,
        );

    final firstCheck = check();
    final overlappingCheck = check();
    expect(loadCalls, 1);

    firstMetadata.complete(_updateMetadata);
    await Future.wait([firstCheck, overlappingCheck]);
    expect(availableReports, 1);
    expect(presentations, 1);
    expect(failures, 0);

    await check();
    expect(loadCalls, 2);
    expect(availableReports, 1);
    expect(presentations, 1);
  });

  test('coordinator releases its check gate after a metadata failure',
      () async {
    final coordinator = ClientUpdateCoordinator();
    var loadCalls = 0;
    var failures = 0;
    var presentations = 0;

    Future<void> check() => coordinator.checkAndPresent(
          loadMetadata: () async {
            loadCalls += 1;
            if (loadCalls == 1) {
              throw StateError('offline');
            }
            return _updateMetadata;
          },
          hostPlatform: HostPlatform.android,
          isActive: () => true,
          onUpdateAvailable: () {},
          presentUpdate: (_) async {
            presentations += 1;
          },
          onFailure: (_, __) => failures += 1,
        );

    await check();
    await check();

    expect(loadCalls, 2);
    expect(failures, 1);
    expect(presentations, 1);
  });
}

const _updateMetadata = ClientAppsMetadata(
  android: ClientAppPlatformMetadata(
    platform: 'android',
    primaryUrl:
        'https://github.com/Kiwunaka/pokrov/releases/download/v1.2.0/pokrov-android-universal.apk',
    mirrorUrl: '',
    version: '1.2.0',
    sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    size: 123456,
    releaseNotes: 'Исправления.',
    releaseNotesUrl: '',
    publishedAt: '2026-08-22T00:00:00Z',
    update: ClientAppUpdateInfo(
      platform: 'android',
      channel: 'stable',
      latestVersion: '1.2.0',
      minSupportedVersion: '1.1.6',
      updatePolicy: 'recommended',
      url:
          'https://github.com/Kiwunaka/pokrov/releases/download/v1.2.0/pokrov-android-universal.apk',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      size: 123456,
      releaseNotes: 'Исправления.',
      releaseNotesUrl: '',
      publishedAt: '2026-08-22T00:00:00Z',
    ),
  ),
  windows: ClientAppPlatformMetadata.emptyWindows,
  docsUrl: 'https://pokrov.space/install/',
  updatedAt: '2026-08-22T00:00:00Z',
  updateCheckMode: 'prompt',
  silentUpdate: false,
);
