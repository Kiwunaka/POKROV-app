import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/emergency_network_contract.dart';

const _installId = 'install-emergency-123';
final _now = DateTime.utc(2026, 8, 15, 12);

String _b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');

Future<Map<String, Object?>> _catalogPayload(
  EmergencyEnvelopeVerifier verifier, {
  int count = 4,
}) async {
  final binding = await verifier.deviceBinding(_installId);
  return <String, Object?>{
    'type': 'pokrov.emergency.catalog',
    'schema_version': 1,
    'catalog_revision': 'emg-${'a' * 32}',
    'issued_at': _now.toIso8601String(),
    'refresh_after': _now.add(const Duration(hours: 2)).toIso8601String(),
    'valid_until': _now.add(const Duration(hours: 24)).toIso8601String(),
    'offline_valid_until': _now.add(const Duration(hours: 6)).toIso8601String(),
    'device_binding': binding,
    'access': <String, Object?>{
      'state': 'trial_premium',
      'expires_at': _now.add(const Duration(days: 5)).toIso8601String(),
    },
    'eligibility': <String, Object?>{
      'eligible': true,
      'source': 'manual_limited_network',
      'country_code': null,
      'valid_until': _now.add(const Duration(hours: 6)).toIso8601String(),
    },
    'disclosure_revision': '2026-08-15.1',
    'items': List<Object?>.generate(
      count,
      (index) => <String, Object?>{
        'id': 'emg_${(index + 1).toRadixString(16).padLeft(24, '0')}',
        'ordinal': index + 1,
        'country_code': 'DE',
        'transport': index.isEven ? 'tcp' : 'grpc',
        'status': 'working',
        'latency_ms': 40 + index,
        'latency_source': 'server_probe',
        'checked_at': _now.toIso8601String(),
        'verification': index == 0 ? 'synthetic_bs' : 'ordinary',
        'verification_at': _now.toIso8601String(),
        'modes': <String>[
          'reserve_direct',
          'reserve_foreign',
          'reserve_ru_foreign',
        ],
      },
    ),
  };
}

Map<String, Object?> _config() => <String, Object?>{
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'vless',
          'tag': 'POKROV emergency reserve',
          'server': 'reserve.example',
          'server_port': 443,
          'uuid': '11111111-1111-4111-8111-111111111111',
          'tls': <String, Object?>{
            'enabled': true,
            'reality': <String, Object?>{'enabled': true},
          },
        },
        <String, Object?>{
          'type': 'vless',
          'tag': 'POKROV owned RU',
          'server': 'ru.example',
          'server_port': 443,
          'uuid': '22222222-2222-4222-8222-222222222222',
          'detour': 'POKROV emergency reserve',
          'tls': <String, Object?>{
            'enabled': true,
            'reality': <String, Object?>{'enabled': true},
          },
        },
        <String, Object?>{
          'type': 'vless',
          'tag': 'POKROV owned foreign',
          'server': 'foreign.example',
          'server_port': 443,
          'uuid': '33333333-3333-4333-8333-333333333333',
          'detour': 'POKROV owned RU',
          'tls': <String, Object?>{
            'enabled': true,
            'reality': <String, Object?>{'enabled': true},
          },
        },
        <String, Object?>{'type': 'direct', 'tag': 'direct'},
        <String, Object?>{'type': 'block', 'tag': 'block'},
        <String, Object?>{'type': 'dns', 'tag': 'dns-out'},
      ],
      'dns': <String, Object?>{
        'servers': <Object?>[
          <String, Object?>{'tag': 'bootstrap', 'address': 'local'},
          <String, Object?>{
            'tag': 'emergency-dns',
            'address': 'https://1.1.1.1/dns-query',
            'detour': 'POKROV owned foreign',
          },
        ],
        'final': 'emergency-dns',
      },
      'route': <String, Object?>{
        'final': 'POKROV owned foreign',
        'rule_set': <Object?>[
          <String, Object?>{
            'type': 'remote',
            'tag': 'geoip-ru',
            'format': 'binary',
            'url': 'https://connect.pokrov.space/rules/geoip-ru.srs',
            'download_detour': 'POKROV owned foreign',
          },
        ],
        'rules': <Object?>[
          <String, Object?>{
            'rule_set': <String>['geoip-ru'],
            'outbound': 'direct',
          },
          <String, Object?>{'protocol': 'dns', 'outbound': 'dns-out'},
          <String, Object?>{'ip_is_private': true, 'outbound': 'direct'},
        ],
      },
      '_meta': <String, Object?>{
        'emergency': true,
        'chain_mode': 'reserve_ru_foreign',
        'route_scope': 'all_except_ru',
        'quick_settings_eligible': false,
        'warp': false,
      },
    };

void main() {
  test('verifies a strict signed catalog and keeps only safe metadata',
      () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final verifier = EmergencyEnvelopeVerifier(
      publicKeysById: <String, String>{'test-key': _b64(publicKey.bytes)},
    );
    final payload = await _catalogPayload(verifier);
    final bytes = utf8.encode(jsonEncode(payload));
    final signature = await algorithm.sign(bytes, keyPair: keyPair);
    final envelope = <String, dynamic>{
      'schema_version': 1,
      'algorithm': 'Ed25519',
      'key_id': 'test-key',
      'payload_b64': _b64(bytes),
      'signature_b64': _b64(signature.bytes),
    };
    final catalog = await verifier.parseCatalog(
      envelope,
      installId: _installId,
      now: _now,
    );
    expect(catalog.items, hasLength(4));
    expect(catalog.items.first.verification,
        EmergencyVerificationLevel.syntheticBs);
    expect(catalog.items.first.modes, EmergencyChainMode.values);
    expect(jsonEncode(catalog.envelope), isNot(contains('reserve.example')));
  });

  test('rejects tamper, unknown key, wrong device and invalid item count',
      () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final verifier = EmergencyEnvelopeVerifier(
      publicKeysById: <String, String>{'test-key': _b64(publicKey.bytes)},
    );
    final payload = await _catalogPayload(verifier);
    final bytes = utf8.encode(jsonEncode(payload));
    final signature = await algorithm.sign(bytes, keyPair: keyPair);
    final envelope = <String, dynamic>{
      'schema_version': 1,
      'algorithm': 'Ed25519',
      'key_id': 'test-key',
      'payload_b64': _b64(bytes),
      'signature_b64': _b64(signature.bytes),
    };
    final tampered = Map<String, dynamic>.from(envelope)
      ..['payload_b64'] = '${envelope['payload_b64']}A';
    await expectLater(
      verifier.parseCatalog(tampered, installId: _installId, now: _now),
      throwsA(isA<EmergencyContractFailure>()),
    );
    await expectLater(
      verifier.parseCatalog(envelope, installId: 'another-install', now: _now),
      throwsA(
        isA<EmergencyContractFailure>().having(
          (error) => error.code,
          'code',
          'catalog_device_mismatch',
        ),
      ),
    );

    final shortPayload = await _catalogPayload(verifier, count: 3);
    final shortBytes = utf8.encode(jsonEncode(shortPayload));
    final shortSignature = await algorithm.sign(shortBytes, keyPair: keyPair);
    await expectLater(
      verifier.parseCatalog(
        <String, dynamic>{
          ...envelope,
          'payload_b64': _b64(shortBytes),
          'signature_b64': _b64(shortSignature.bytes),
        },
        installId: _installId,
        now: _now,
      ),
      throwsA(
        isA<EmergencyContractFailure>().having(
          (error) => error.code,
          'code',
          'catalog_items_invalid',
        ),
      ),
    );
  });

  test('accepts exact three-hop profile and rejects detoured local DNS',
      () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final verifier = EmergencyEnvelopeVerifier(
      publicKeysById: <String, String>{'test-key': _b64(publicKey.bytes)},
    );
    final payload = <String, Object?>{
      'type': 'pokrov.emergency.profile',
      'schema_version': 1,
      'catalog_revision': 'emg-${'a' * 32}',
      'profile_revision': 'emgp-${'b' * 24}',
      'issued_at': _now.toIso8601String(),
      'offline_valid_until':
          _now.add(const Duration(hours: 6)).toIso8601String(),
      'device_binding': await verifier.deviceBinding(_installId),
      'reserve_id': 'emg_${'c' * 24}',
      'chain_mode': 'reserve_ru_foreign',
      'route_scope': 'all_except_ru',
      'access_state': 'paid_unlimited',
      'access_expires_at': _now.add(const Duration(days: 30)).toIso8601String(),
      'eligibility_valid_until':
          _now.add(const Duration(hours: 20)).toIso8601String(),
      'warp': false,
      'quick_settings_eligible': false,
      'config_format': 'singbox-json',
      'config_payload': _config(),
    };

    Future<Map<String, dynamic>> sign(Map<String, Object?> value) async {
      final bytes = utf8.encode(jsonEncode(value));
      final signature = await algorithm.sign(bytes, keyPair: keyPair);
      return <String, dynamic>{
        'schema_version': 1,
        'algorithm': 'Ed25519',
        'key_id': 'test-key',
        'payload_b64': _b64(bytes),
        'signature_b64': _b64(signature.bytes),
      };
    }

    final profile = await verifier.parseProfile(
      await sign(payload),
      installId: _installId,
      catalogRevision: 'emg-${'a' * 32}',
      reserveId: 'emg_${'c' * 24}',
      chainMode: EmergencyChainMode.reserveRuForeign,
      now: _now,
    );
    expect(profile.configPayload['route'],
        containsPair('final', 'POKROV owned foreign'));

    final invalidConfig = _config();
    ((invalidConfig['outbounds'] as List)[1]
        as Map<String, Object?>)['domain_resolver'] = 'bootstrap';
    final invalidPayload = <String, Object?>{
      ...payload,
      'config_payload': invalidConfig,
    };
    await expectLater(
      verifier.parseProfile(
        await sign(invalidPayload),
        installId: _installId,
        catalogRevision: 'emg-${'a' * 32}',
        reserveId: 'emg_${'c' * 24}',
        chainMode: EmergencyChainMode.reserveRuForeign,
        now: _now,
      ),
      throwsA(
        isA<EmergencyContractFailure>().having(
          (error) => error.code,
          'code',
          'profile_detour_dns_invalid',
        ),
      ),
    );

    final bypassConfig = _config();
    ((bypassConfig['route'] as Map<String, Object?>)['rules'] as List)
        .insert(0, <String, Object?>{
      'protocol': 'bittorrent',
      'outbound': 'direct',
    });
    await expectLater(
      verifier.parseProfile(
        await sign(<String, Object?>{
          ...payload,
          'config_payload': bypassConfig,
        }),
        installId: _installId,
        catalogRevision: 'emg-${'a' * 32}',
        reserveId: 'emg_${'c' * 24}',
        chainMode: EmergencyChainMode.reserveRuForeign,
        now: _now,
      ),
      throwsA(
        isA<EmergencyContractFailure>().having(
          (error) => error.code,
          'code',
          'profile_ru_route_invalid',
        ),
      ),
    );
  });

  test('rejects a signed profile whose topology does not match its mode',
      () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final verifier = EmergencyEnvelopeVerifier(
      publicKeysById: <String, String>{'test-key': _b64(publicKey.bytes)},
    );
    final config = _config();
    (config['_meta'] as Map<String, Object?>)['chain_mode'] = 'reserve_foreign';
    final payload = <String, Object?>{
      'type': 'pokrov.emergency.profile',
      'schema_version': 1,
      'catalog_revision': 'emg-${'a' * 32}',
      'profile_revision': 'emgp-${'b' * 24}',
      'issued_at': _now.toIso8601String(),
      'offline_valid_until':
          _now.add(const Duration(hours: 6)).toIso8601String(),
      'device_binding': await verifier.deviceBinding(_installId),
      'reserve_id': 'emg_${'c' * 24}',
      'chain_mode': 'reserve_foreign',
      'route_scope': 'all_except_ru',
      'access_state': 'paid_unlimited',
      'access_expires_at': _now.add(const Duration(days: 30)).toIso8601String(),
      'eligibility_valid_until':
          _now.add(const Duration(hours: 20)).toIso8601String(),
      'warp': false,
      'quick_settings_eligible': false,
      'config_format': 'singbox-json',
      'config_payload': config,
    };
    final bytes = utf8.encode(jsonEncode(payload));
    final signature = await algorithm.sign(bytes, keyPair: keyPair);
    await expectLater(
      verifier.parseProfile(
        <String, dynamic>{
          'schema_version': 1,
          'algorithm': 'Ed25519',
          'key_id': 'test-key',
          'payload_b64': _b64(bytes),
          'signature_b64': _b64(signature.bytes),
        },
        installId: _installId,
        catalogRevision: 'emg-${'a' * 32}',
        reserveId: 'emg_${'c' * 24}',
        chainMode: EmergencyChainMode.reserveForeign,
        now: _now,
      ),
      throwsA(isA<EmergencyContractFailure>()),
    );
  });
}
