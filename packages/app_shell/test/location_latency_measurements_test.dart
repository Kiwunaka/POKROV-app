import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const serverCatalog = ClientLocationsCatalog(
    auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra-01'),
    countries: <ClientLocationCountry>[
      ClientLocationCountry(
        code: 'de',
        country: 'Germany',
        cities: <ClientLocationCity>[
          ClientLocationCity(
            code: 'de-fra-01',
            city: 'Frankfurt',
            healthScore: 0.95,
            latencyMs: 1,
            premium: true,
            load: 0.07,
            measuredAt: '2026-08-13T08:00:00Z',
            latencySource: 'brain',
            probeHost: 'de.example.test',
            probePort: 443,
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
    freePoolCode: '',
    profileRevision: 'revision-1',
    transportProfile: 'reality',
    query: '',
  );

  test('server-side RTT is hidden until the device measures the node', () {
    final catalog = applyPokrovDeviceLatencies(serverCatalog, const {});
    final city = catalog.countries.single.cities.single;

    expect(city.latencyMs, isNull);
    expect(city.latencySource, 'unavailable');
    expect(city.measuredAt, '2026-08-13T08:00:00Z');
    expect(city.load, 0.07);
    expect(
        city.variants.map((variant) => variant.id), <String>['direct', 'mini']);
  });

  test('device RTT replaces the brain measurement with a local timestamp', () {
    final catalog = applyPokrovDeviceLatencies(
      serverCatalog,
      const {'DE-FRA-01': 47},
      measuredAt: DateTime.utc(2026, 8, 13, 12, 30),
    );
    final city = catalog.countries.single.cities.single;

    expect(city.latencyMs, 47);
    expect(city.latencySource, 'device');
    expect(city.measuredAt, '2026-08-13T12:30:00.000Z');
    expect(city.load, 0.07);
  });

  test('probe targets are bounded to valid endpoint metadata', () {
    expect(
      pokrovLocationLatencyTargets(serverCatalog)
          .map((target) => target.toJson())
          .toList(),
      <Map<String, Object?>>[
        <String, Object?>{
          'code': 'de-fra-01',
          'host': 'de.example.test',
          'port': 443,
        },
      ],
    );
  });

  test('variant probe exposes only safe ids, status, latency and active id',
      () async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final observedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runtimeEngine.measureLocationVariants');
      return <String, Object?>{
        'observedAtMs': observedAt,
        'activeVariantId': 'mini',
        'results': <Object?>[
          <String, Object?>{
            'id': 'direct',
            'status': 'unavailable',
            'latencyMs': null,
            'errorCategory': 'url_test_failed',
          },
          <String, Object?>{
            'id': 'mini',
            'status': 'available',
            'latencyMs': 74,
            'measuredAtMs': observedAt,
            'errorCategory': '',
          },
          <String, Object?>{
            'id': '../../unsafe',
            'status': 'available',
            'latencyMs': 1,
          },
        ],
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final snapshot = await measurePokrovLocationVariants(HostPlatform.android);

    expect(snapshot.results.keys, <String>{'direct', 'mini'});
    expect(snapshot.activeVariantId, 'mini');
    expect(snapshot.results['direct']?.status,
        PokrovLocationVariantProbeStatus.unavailable);
    expect(snapshot.results['mini']?.status,
        PokrovLocationVariantProbeStatus.available);
    expect(snapshot.results['mini']?.latencyMs, 74);
  });
}
