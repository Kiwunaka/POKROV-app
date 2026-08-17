import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('client experience store survives restart without runtime secrets',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'pokrov-client-experience-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = PokrovFileClientExperienceStore(
      supportDirectoryResolver: () async => directory,
    );
    final shortcut = PokrovPostConnectShortcut.tryCreate(
      label: 'Почта',
      href: 'https://mail.example/inbox',
    );
    expect(shortcut, isNotNull);

    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'nl-ams-01'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'nl',
          country: 'Netherlands',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'nl-ams-01',
              city: 'Amsterdam',
              healthScore: 0.94,
              latencyMs: 38,
              premium: true,
              load: 0.31,
              measuredAt: '2026-07-23T10:15:00Z',
              variants: <ClientLocationVariant>[
                ClientLocationVariant(
                  id: 'direct',
                  label: 'Обычный',
                  description: 'Прямое подключение',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini',
                  label: 'Белые списки',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
              ],
            ),
          ],
        ),
      ],
      freePoolCode: 'nl-free',
      profileRevision: 'rev-1',
      transportProfile: 'reality',
      query: '',
    );
    const inbox = ClientNotificationInbox(
      items: <ClientNotificationItem>[
        ClientNotificationItem(
          id: 'incident-1',
          kind: 'incident',
          title: 'Работы завершены',
          body: 'Сервис восстановлен.',
          createdAt: '2026-07-23T10:20:00Z',
          ctaLabel: '',
          ctaHref: null,
          read: false,
        ),
      ],
      nextCursor: '',
      unreadCount: 1,
    );
    final state = PokrovClientExperienceState(
      favoriteNodeCodes: const <String>['nl-ams-01'],
      recentNodeCodes: const <String>['nl-ams-01'],
      protectionEvents: const <PokrovProtectionEvent>[
        PokrovProtectionEvent(
          id: 'event-1',
          kind: 'connected',
          title: 'Защита включена',
          detail: 'Туннель и host-health подтверждены.',
          occurredAt: '2026-07-23T10:21:00Z',
          tone: PokrovProtectionEventTone.success,
        ),
      ],
      postConnectShortcuts: <PokrovPostConnectShortcut>[shortcut!],
      cachedLocations: catalog,
      locationsCachedAt: '2026-07-23T10:15:01Z',
      cachedNotifications: inbox,
      notificationsCachedAt: '2026-07-23T10:20:01Z',
      preferredNodeCode: 'nl-ams-01',
      preferredVariantId: 'mini',
      automaticNodeQuarantineUntil: const <String, String>{
        'de-fra-01': '2026-07-23T10:35:00Z',
      },
      selectedAppIds: const <String>[
        'org.telegram.messenger',
        'pokrov.exe',
      ],
      routingPreferences: PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.video},
        dnsPreset: PokrovDnsPreset.cloudflare,
        allowLan: false,
        overrides: <PokrovRouteOverride>[
          PokrovRouteOverride.tryCreate(
            value: 'private.example',
            action: PokrovRouteAction.vpn,
          )!,
        ],
      ),
      emergencyReserveId: 'emg_000000000000000000000001',
      emergencyChainMode: EmergencyChainMode.reserveRuForeign.wireValue,
      emergencyAutomaticRoute: false,
    );

    await store.write(state);
    final restored = await store.read();

    expect(restored.favoriteNodeCodes, <String>['nl-ams-01']);
    expect(restored.recentNodeCodes, <String>['nl-ams-01']);
    expect(restored.preferredNodeCode, 'nl-ams-01');
    expect(restored.preferredVariantId, 'mini');
    expect(
      restored.automaticNodeQuarantineUntil,
      <String, String>{'de-fra-01': '2026-07-23T10:35:00Z'},
    );
    expect(
      restored.selectedAppIds,
      <String>['org.telegram.messenger', 'pokrov.exe'],
    );
    expect(restored.protectionEvents.single.kind, 'connected');
    expect(restored.postConnectShortcuts.single.href.scheme, 'https');
    expect(
      restored.cachedLocations!.countries.single.cities.single.measuredAt,
      '2026-07-23T10:15:00Z',
    );
    expect(
      restored.cachedLocations!.countries.single.cities.single.variants
          .map((variant) => variant.id),
      <String>['direct', 'mini'],
    );
    expect(restored.cachedNotifications!.unreadCount, 1);
    expect(
      restored.routingPreferences.purposeRoutes,
      contains(PokrovPurposeRoute.video),
    );
    expect(restored.routingPreferences.dnsPreset, PokrovDnsPreset.cloudflare);
    expect(restored.routingPreferences.allowLan, isFalse);
    expect(
        restored.routingPreferences.overrides.single.value, 'private.example');
    expect(restored.emergencyAutomaticRoute, isFalse);
    expect(
      restored.emergencyChainMode,
      EmergencyChainMode.reserveRuForeign.wireValue,
    );

    final file =
        await directory.list().where((item) => item is File).single as File;
    final raw = await file.readAsString();
    expect(raw, isNot(contains('configPayload')));
    expect(raw, isNot(contains('accessToken')));
    expect(raw, isNot(contains('privateKey')));

    await file.writeAsString('{broken json', flush: true);
    final recovered = await store.read();
    expect(recovered.favoriteNodeCodes, isEmpty);
    expect(recovered.cachedLocations, isNull);
  });

  test('post-connect shortcuts accept only owned HTTPS destinations', () {
    expect(
      PokrovPostConnectShortcut.tryCreate(
        label: 'HTTP',
        href: 'http://example.com',
      ),
      isNull,
    );
    expect(
      PokrovPostConnectShortcut.tryCreate(
        label: 'Credentials',
        href: 'https://user:secret@example.com',
      ),
      isNull,
    );
    expect(
      PokrovPostConnectShortcut.tryCreate(
        label: 'Cabinet',
        href: 'https://app.pokrov.space/',
      ),
      isNotNull,
    );
  });

  test(
      'selected app persistence normalizes Android packages, Windows exe, and caps at 128',
      () {
    final identifiers = <Object?>[
      'ORG.Telegram.Messenger',
      'POKROV.EXE',
      'bad/path',
      for (var index = 0; index < 140; index += 1) 'com.example.app$index',
    ];
    final restored = PokrovClientExperienceState.fromJson(<String, dynamic>{
      'selectedAppIds': identifiers,
    });

    expect(restored.selectedAppIds.first, 'org.telegram.messenger');
    expect(restored.selectedAppIds, contains('pokrov.exe'));
    expect(restored.selectedAppIds, isNot(contains('bad/path')));
    expect(restored.selectedAppIds, hasLength(128));
  });

  test('automatic node quarantine ignores malformed data and caps at eight',
      () {
    final restored = PokrovClientExperienceState.fromJson(<String, dynamic>{
      'automaticNodeQuarantineUntil': <String, Object?>{
        'BAD/NODE': '2026-07-23T10:35:00Z',
        'bad-date': 'tomorrow',
        for (var index = 0; index < 12; index += 1)
          'node-$index': '2026-07-23T10:${35 + index}:00Z',
      },
    });

    expect(restored.automaticNodeQuarantineUntil, hasLength(8));
    expect(restored.automaticNodeQuarantineUntil, contains('node-0'));
    expect(restored.automaticNodeQuarantineUntil, isNot(contains('bad/node')));
    expect(restored.automaticNodeQuarantineUntil, isNot(contains('bad-date')));
  });

  test('selected app identifiers use the same bounded platform rules', () {
    expect(
      normalizePokrovSelectedAppIdentifier(
        'COM.FOO',
        hostPlatform: HostPlatform.android,
      ),
      'com.foo',
    );
    expect(
      normalizePokrovSelectedAppIdentifier(
        'com.foo',
        hostPlatform: HostPlatform.windows,
      ),
      isNull,
    );
    expect(
      normalizePokrovSelectedAppIdentifier(
        'POKROV.EXE',
        hostPlatform: HostPlatform.windows,
      ),
      'pokrov.exe',
    );
    for (final invalid in <String>[
      '../bad.exe',
      'com.bad/name',
      '${'a' * 93}.exe',
    ]) {
      expect(normalizePokrovSelectedAppIdentifier(invalid), isNull);
    }
  });

  test('location variants parse tolerantly and keep only safe stable ids', () {
    final catalog = ClientLocationsCatalog.fromJson(<String, dynamic>{
      'countries': <Object?>[
        <String, Object?>{
          'code': 'de',
          'country': 'Germany',
          'cities': <Object?>[
            <String, Object?>{
              'code': 'de-ber',
              'city': 'Berlin',
              'variants': <Object?>[
                <String, Object?>{
                  'id': 'DIRECT',
                  'label': 'Обычный',
                  'description': 'Прямое подключение',
                },
                <String, Object?>{
                  'id': 'ru_spb',
                  'label': 'Белые списки',
                  'description': 'Для ограниченных сетей',
                  'available': false,
                },
                <String, Object?>{'id': '../raw', 'label': 'Сырой'},
                <String, Object?>{'id': 'duplicate', 'label': ''},
                'not-an-object',
              ],
            },
          ],
        },
      ],
    });

    final variants = catalog.countries.single.cities.single.variants;
    expect(variants.map((variant) => variant.id), <String>['direct', 'ru_spb']);
    expect(variants.first.available, isTrue);
    expect(variants.last.available, isFalse);
    expect(
      ClientLocationsCatalog.fromJson(catalog.toJson())
          .countries
          .single
          .cities
          .single
          .variants
          .map((variant) => variant.label),
      <String>['Обычный', 'Белые списки'],
    );
  });
}
