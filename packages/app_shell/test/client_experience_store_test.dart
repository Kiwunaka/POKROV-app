import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

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
    );

    await store.write(state);
    final restored = await store.read();

    expect(restored.favoriteNodeCodes, <String>['nl-ams-01']);
    expect(restored.recentNodeCodes, <String>['nl-ams-01']);
    expect(restored.protectionEvents.single.kind, 'connected');
    expect(restored.postConnectShortcuts.single.href.scheme, 'https');
    expect(
      restored.cachedLocations!.countries.single.cities.single.measuredAt,
      '2026-07-23T10:15:00Z',
    );
    expect(restored.cachedNotifications!.unreadCount, 1);
    expect(
      restored.routingPreferences.purposeRoutes,
      contains(PokrovPurposeRoute.video),
    );
    expect(restored.routingPreferences.dnsPreset, PokrovDnsPreset.cloudflare);
    expect(restored.routingPreferences.allowLan, isFalse);
    expect(restored.routingPreferences.overrides.single.value, 'private.example');

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
}
