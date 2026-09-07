import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

import 'emergency_network_contract.dart';
import 'src/emergency/emergency_network_store.dart';
import 'src/observability/release_health_baseline.dart';
import 'src/shell/managed_profile_cache.dart';

/// Build identity shared by provisioning, update checks, and diagnostics.
///
/// Release builds pass `--dart-define=POKROV_APP_VERSION=<package-version>`.
/// The fallback keeps ordinary local runs aligned with the current host
/// package base version (without Android's build number).
const pokrovClientVersion = String.fromEnvironment(
  'POKROV_APP_VERSION',
  defaultValue: '1.2.0',
);
const pokrovSupportSigningKeyId = String.fromEnvironment(
  'POKROV_SUPPORT_SIGNING_KEY_ID',
);
const pokrovSupportSigningPublicKeyB64 = String.fromEnvironment(
  'POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64',
);

const _platformErrorCodeHeader = 'X-POKROV-Auth-Error';
const _correlationIdHeader = 'X-Correlation-ID';
const _androidCoreEgressProbeUrl =
    'https://api.pokrov.space/api/public/authenticated-egress-probe';
const _smartConnectProfileRefreshTimeout = Duration(seconds: 6);
const _ownedTransportLabProfiles = <String>{
  'awg2_lab',
  'awg31_lab',
  'hy2_lab',
};
const _appFirstSessionCredentialsVersion = 1;
const _appFirstBootstrapStateVersion = 1;
final _platformErrorCodePattern = RegExp(r'^[a-z0-9_]{1,64}$');

/// Selects the managed TUN MTU before handing the profile to a native host.
///
/// Integer values inside the IPv6-safe 1280..1500 interval are preserved.
/// Missing, malformed, and out-of-range control-plane values fail closed to
/// the conservative default. Native hosts apply their platform interface
/// ceiling again immediately before creating the TUN device.
int selectSafeTunMtu(Object? value) {
  if (value is! int || value < 1280 || value > 1500) {
    return 1280;
  }
  return value;
}

abstract interface class ManagedProfileBootstrapper {
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const <String>{},
    String tcpFallbackFromRevision = '',
    Duration? timeout,
  });
}

class ManagedProfileCacheInputs {
  const ManagedProfileCacheInputs({
    required this.hostPlatform,
    required this.routeMode,
    this.selectedApps = const <String>[],
    this.preferredNodeCode = '',
    this.preferredVariantId = 'direct',
  });

  final HostPlatform hostPlatform;
  final RouteMode routeMode;
  final List<String> selectedApps;
  final String preferredNodeCode;
  final String preferredVariantId;

  String binding(String accountId, String installId) {
    final apps = selectedApps.map((app) => app.trim()).toSet().toList()..sort();
    final node = preferredNodeCode.trim().toLowerCase();
    return jsonEncode([
      accountId, installId, hostPlatform.name, routeMode.name, apps, node,
      node.isEmpty ? 'direct' : preferredVariantId.trim().toLowerCase(),
    ]);
  }
}

abstract interface class CachedManagedProfileBootstrapper {
  Future<ManagedProfilePayload?> loadCachedManagedProfile(
    ManagedProfileCacheInputs inputs, {
    bool preferProven = false,
  });
  Future<void> markManagedProfileProven(
    ManagedProfileCacheInputs inputs,
    String entryId,
  );
}

typedef SmartConnectLatencyProbe = Future<int?> Function(
  SmartConnectNode node,
);

typedef AppFirstDeviceNameResolver = Future<String?> Function(
  HostPlatform hostPlatform,
);

typedef AppFirstAndroidAbiResolver = Future<String?> Function(
  HostPlatform hostPlatform,
);

const MethodChannel _appFirstRuntimeEngineChannel = MethodChannel(
  'space.pokrov/runtime_engine',
);
const _supportedAndroidUpdateAbis = <String>{
  'arm64-v8a',
  'armeabi-v7a',
  'x86_64',
};

Future<String?> _resolveAndroidUpdateAbi(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.android) {
    return null;
  }
  try {
    final values = await _appFirstRuntimeEngineChannel.invokeListMethod<String>(
      'runtimeEngine.supportedAbis',
    );
    for (final value in values ?? const <String>[]) {
      final normalized = value.trim().toLowerCase();
      if (_supportedAndroidUpdateAbis.contains(normalized)) {
        return normalized;
      }
    }
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
  return null;
}

typedef AppFirstStateFileWriter = Future<void> Function(
  File file,
  String contents,
);

final Map<String, Future<void>> _appFirstStateFileWriteQueues =
    <String, Future<void>>{};

Future<T> _withAppFirstStateFileLock<T>(
  File file,
  Future<T> Function() operation,
) async {
  final target = file.absolute.path.toLowerCase();
  final previous = _appFirstStateFileWriteQueues[target];
  final completion = Completer<void>();
  _appFirstStateFileWriteQueues[target] = completion.future;
  if (previous != null) {
    try {
      await previous;
    } catch (_) {
      // A prior writer has already surfaced its failure to its caller.
    }
  }
  try {
    return await operation();
  } finally {
    completion.complete();
    if (identical(_appFirstStateFileWriteQueues[target], completion.future)) {
      _appFirstStateFileWriteQueues.remove(target);
    }
  }
}

Future<void> _writeAppFirstStateFileAtomically(
  File file,
  String contents,
) async {
  final nextFile = File('${file.path}.next');
  final backupFile = File('${file.path}.bak');
  await file.parent.create(recursive: true);

  if (await nextFile.exists()) {
    await nextFile.delete();
  }
  await nextFile.writeAsString(contents, flush: true);
  final decoded = jsonDecode(await nextFile.readAsString());
  if (decoded is! Map) {
    throw const FormatException('App-first state must be a JSON object.');
  }

  if (await backupFile.exists()) {
    await backupFile.delete();
  }
  if (await file.exists()) {
    await file.rename(backupFile.path);
  }

  try {
    await nextFile.rename(file.path);
  } catch (_) {
    if (!await file.exists() && await backupFile.exists()) {
      await backupFile.rename(file.path);
    }
    rethrow;
  }

  if (await backupFile.exists()) {
    await backupFile.delete();
  }
}

abstract interface class AppFirstSessionSecretStore {
  Future<String?> readSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  });

  Future<void> writeSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
    required String sessionToken,
  });

  Future<void> deleteSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  });

  Future<AppFirstSessionCredentials?> readSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
  });

  Future<void> writeSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
    required AppFirstSessionCredentials pair,
  });
}

class AppFirstSessionCredentials {
  const AppFirstSessionCredentials({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  bool get hasAccessToken => accessToken.trim().isNotEmpty;

  String _encode() => jsonEncode(<String, Object?>{
        'version': _appFirstSessionCredentialsVersion,
        'access_token': accessToken.trim(),
        if (refreshToken.trim().isNotEmpty)
          'refresh_token': refreshToken.trim(),
      });

  static AppFirstSessionCredentials? _decode(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final version = decoded['version'];
        if (version is! int || version != _appFirstSessionCredentialsVersion) {
          return null;
        }
        final accessToken = (decoded['access_token'] ?? '').toString().trim();
        final refreshToken = (decoded['refresh_token'] ?? '').toString().trim();
        return accessToken.isEmpty
            ? null
            : AppFirstSessionCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
              );
      }
    } on FormatException {
      // Legacy secure entries contain only the access token.
    }
    return AppFirstSessionCredentials(accessToken: raw, refreshToken: '');
  }

  static bool _isLegacyEncoding(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return false;
    }
    try {
      return jsonDecode(raw) is! Map;
    } on FormatException {
      return true;
    }
  }
}

class FlutterSecureAppFirstSessionSecretStore
    implements AppFirstSessionSecretStore {
  FlutterSecureAppFirstSessionSecretStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key({
    required HostPlatform hostPlatform,
    required String installId,
  }) =>
      'pokrov.app_first.session.${hostPlatform.name}.${installId.trim()}';

  @override
  Future<String?> readSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async =>
      (await _readSessionPairAndMigrate(
        hostPlatform: hostPlatform,
        installId: installId,
      ))
          ?.accessToken;

  @override
  Future<void> writeSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
    required String sessionToken,
  }) async {
    final value = sessionToken.trim();
    if (value.isEmpty) {
      await deleteSessionToken(
          hostPlatform: hostPlatform, installId: installId);
      return;
    }
    await writeSessionPair(
      hostPlatform: hostPlatform,
      installId: installId,
      pair: AppFirstSessionCredentials(accessToken: value, refreshToken: ''),
    );
  }

  @override
  Future<void> deleteSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    await _storage.delete(key: key);
  }

  @override
  Future<AppFirstSessionCredentials?> readSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
  }) =>
      _readSessionPairAndMigrate(
        hostPlatform: hostPlatform,
        installId: installId,
      );

  Future<AppFirstSessionCredentials?> _readSessionPairAndMigrate({
    required HostPlatform hostPlatform,
    required String installId,
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    final raw = await _storage.read(key: key) ?? '';
    final pair = AppFirstSessionCredentials._decode(raw);
    if (pair != null && AppFirstSessionCredentials._isLegacyEncoding(raw)) {
      try {
        await _storage.write(key: key, value: pair._encode());
      } on Object {
        // The legacy credential remains usable and untouched when its
        // idempotent schema rewrite cannot be persisted.
      }
    }
    return pair;
  }

  @override
  Future<void> writeSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
    required AppFirstSessionCredentials pair,
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    if (!pair.hasAccessToken) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: pair._encode());
  }
}

class MemoryAppFirstSessionSecretStore implements AppFirstSessionSecretStore {
  final Map<String, String> _values = <String, String>{};

  String _key(HostPlatform hostPlatform, String installId) =>
      '${hostPlatform.name}:${installId.trim()}';

  @override
  Future<String?> readSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async =>
      AppFirstSessionCredentials._decode(
        _values[_key(hostPlatform, installId)] ?? '',
      )?.accessToken;

  @override
  Future<void> writeSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
    required String sessionToken,
  }) async {
    await writeSessionPair(
      hostPlatform: hostPlatform,
      installId: installId,
      pair: AppFirstSessionCredentials(
        accessToken: sessionToken,
        refreshToken: '',
      ),
    );
  }

  @override
  Future<void> deleteSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async {
    _values.remove(_key(hostPlatform, installId));
  }

  @override
  Future<AppFirstSessionCredentials?> readSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
  }) async =>
      AppFirstSessionCredentials._decode(
        _values[_key(hostPlatform, installId)] ?? '',
      );

  @override
  Future<void> writeSessionPair({
    required HostPlatform hostPlatform,
    required String installId,
    required AppFirstSessionCredentials pair,
  }) async {
    if (!pair.hasAccessToken) {
      _values.remove(_key(hostPlatform, installId));
      return;
    }
    _values[_key(hostPlatform, installId)] = pair._encode();
  }
}

abstract interface class AppFirstAccountActionService {
  Future<DevicePairingClaimResult> claimDevicePairingCode({
    required HostPlatform hostPlatform,
    required String code,
  });

  Future<AppFirstRedeemResult> redeemCode({
    required HostPlatform hostPlatform,
    required String code,
  });

  Future<CabinetHandoff> createCabinetHandoff({
    required HostPlatform hostPlatform,
    String targetPath = '/',
  });
}

abstract interface class AppFirstBonusActionService {
  Future<TelegramLinkResult> createTelegramLink({
    required HostPlatform hostPlatform,
  });

  Future<void> reportTelegramLinkEvent({
    required HostPlatform hostPlatform,
    required String eventName,
  });

  Future<ChannelBonusStatus> checkChannelBonus({
    required HostPlatform hostPlatform,
  });

  Future<ChannelBonusClaimResult> claimChannelBonus({
    required HostPlatform hostPlatform,
  });

  Future<AppFirstBonusSummary> fetchBonusSummary({
    required HostPlatform hostPlatform,
  });

  Future<AppFirstBonusRewardResult> spinBonusWheel({
    required HostPlatform hostPlatform,
  });

  Future<AppFirstBonusRewardResult> checkInBonusCalendar({
    required HostPlatform hostPlatform,
  });
}

abstract interface class AppFirstWarpActionService {
  Future<WarpControlStatus> fetchWarpStatus({
    required HostPlatform hostPlatform,
  });

  Future<WarpControlStatus> setWarpConsent({
    required HostPlatform hostPlatform,
    required bool enabled,
    String reasonCode = '',
  });

  Future<WarpControlStatus> requestWarpRotation({
    required HostPlatform hostPlatform,
    String reasonCode = 'user_requested',
  });

  Future<WarpControlStatus> reportWarpRuntimeEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    String state = '',
    String reasonCode = '',
    String message = '',
    Map<String, Object?> meta = const <String, Object?>{},
  });
}

abstract interface class AppFirstReleaseActionService {
  Future<ClientAppsMetadata> fetchClientApps({
    required HostPlatform hostPlatform,
    required String currentVersion,
    String channel = 'stable',
  });
}

/// Best-effort app UX telemetry. The platform must not treat this as trusted
/// connection evidence; observer traffic remains the verification authority.
abstract interface class AppFirstExperienceService {
  Future<void> reportRuntimeStats({
    required HostPlatform hostPlatform,
    required String runtimePhase,
    required bool connected,
    String errorCode = '',
    String selectedNodeCode = '',
    String routeMode = '',
    int? durationMs,
    int? attemptNumber,
    bool? retryable,
    String networkClass = '',
  });

  Future<void> completeAccountOnboarding({
    required HostPlatform hostPlatform,
  });
}

/// Authenticated first-session analytics. Account and device correlation are
/// resolved server-side from the app session; callers must not pass session,
/// profile, acquisition-handle, or other raw identifiers in this envelope.
abstract interface class AppFirstFirstSessionEventService {
  Future<void> reportFirstSessionEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required String stage,
    required String result,
    String errorCode = '',
    bool? retryable,
  });
}

abstract interface class AppFirstReleaseHealthService {
  Future<bool> submitReleaseHealthBatch({
    required HostPlatform hostPlatform,
    required Map<String, Object?> batch,
    required String correlationId,
  });

  Future<ClientReleaseHealthBaseline> fetchReleaseHealthBaseline({
    required HostPlatform hostPlatform,
    required OperationalBuildIdentity build,
  });
}

/// Consumes an opaque, short-lived acquisition handoff after a person opens
/// the installed app from a POKROV-owned continuation link. The handle is not
/// an identity token and must never be logged or persisted by the client.
abstract interface class AppFirstAcquisitionService {
  Future<void> consumeAcquisitionHandoff({
    required HostPlatform hostPlatform,
    required String handle,
    required String purpose,
  });
}

String? pokrovAcquisitionPurposeForHost(HostPlatform hostPlatform) {
  return switch (hostPlatform) {
    HostPlatform.android => 'android_install',
    HostPlatform.windows => 'windows_install',
    _ => null,
  };
}

final class PokrovAcquisitionHandoff {
  const PokrovAcquisitionHandoff({
    required this.handle,
    required this.purpose,
  });

  final String handle;
  final String purpose;

  static PokrovAcquisitionHandoff? tryParse(
    Uri uri, {
    required HostPlatform hostPlatform,
  }) {
    final expectedPurpose = pokrovAcquisitionPurposeForHost(hostPlatform);
    final keys = uri.queryParametersAll.keys.toSet();
    final handle = uri.queryParameters['handle']?.trim() ?? '';
    final purpose = uri.queryParameters['purpose']?.trim().toLowerCase() ?? '';
    if (expectedPurpose == null ||
        uri.scheme.toLowerCase() != 'pokrov' ||
        uri.host.toLowerCase() != 'acquisition' ||
        uri.path != '/continue' ||
        keys.length != 2 ||
        !keys.containsAll(const <String>{'handle', 'purpose'}) ||
        !RegExp(r'^[A-Za-z0-9_-]{32,160}$').hasMatch(handle) ||
        purpose != expectedPurpose) {
      return null;
    }
    return PokrovAcquisitionHandoff(handle: handle, purpose: purpose);
  }
}

abstract interface class AppFirstNodePreferenceService {
  Future<SmartConnectPreferenceResult> setPreferredSmartConnectNode({
    required HostPlatform hostPlatform,
    required SmartConnectProfile smartConnect,
    required String nodeCode,
  });
}

abstract interface class AppFirstClientDataService {
  Future<ClientLocationsCatalog> fetchLocationsCatalog({
    required HostPlatform hostPlatform,
    String query = '',
  });

  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform,
  });

  Future<ClientDeviceList> fetchClientDevices({
    required HostPlatform hostPlatform,
  });

  Future<bool> revokeClientDevice({
    required HostPlatform hostPlatform,
    required String deviceId,
  });

  Future<ClientDevicePairingCode> issueDevicePairingCode({
    required HostPlatform hostPlatform,
  });

  Future<bool> cancelDevicePairingCode({
    required HostPlatform hostPlatform,
    required String pairingId,
  });

  Future<ClientNotificationInbox> fetchClientNotifications({
    required HostPlatform hostPlatform,
    String after = '',
  });

  Future<bool> markClientNotificationsRead({
    required HostPlatform hostPlatform,
    required List<String> ids,
  });

  Future<bool> dismissClientNotifications({
    required HostPlatform hostPlatform,
    required List<String> ids,
  });

  Future<ClientPushRegistration> registerClientPushToken({
    required HostPlatform hostPlatform,
    required String token,
    required String provider,
  });

  Future<ClientSupportAssistantReply> askSupportAssistant({
    required HostPlatform hostPlatform,
    required String message,
    int? ticketId,
    String? assistantSessionId,
    Map<String, Object?> safeDiagnostics = const <String, Object?>{},
  });
}

class AppFirstEmergencyCatalogResult {
  const AppFirstEmergencyCatalogResult({
    required this.catalog,
    required this.reason,
    required this.eligibilitySource,
    required this.usingCache,
  });

  final EmergencyCatalog? catalog;
  final String reason;
  final String eligibilitySource;
  final bool usingCache;

  bool get available => catalog != null;
}

class AppFirstEmergencyProfileResult {
  const AppFirstEmergencyProfileResult({
    required this.profile,
    required this.managedProfile,
    required this.usingCache,
  });

  final EmergencyProfile profile;
  final ManagedProfilePayload managedProfile;
  final bool usingCache;
}

abstract interface class AppFirstEmergencyNetworkService {
  Future<AppFirstEmergencyCatalogResult> fetchEmergencyCatalog({
    required HostPlatform hostPlatform,
    required bool manualLimitedNetwork,
    bool forceRefresh = false,
  });

  Future<void> prepareEmergencyOfflineCache({
    required HostPlatform hostPlatform,
    bool manualLimitedNetwork = false,
  });

  Future<AppFirstEmergencyProfileResult> resolveEmergencyProfile({
    required HostPlatform hostPlatform,
    required String catalogRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
    required bool manualLimitedNetwork,
  });
}

class BootstrapFailure implements Exception {
  const BootstrapFailure(
    this.message, {
    this.statusCode,
    this.operation,
    this.code = '',
    this.operationalCode,
  });

  final String message;
  final int? statusCode;
  final String? operation;
  final String code;
  final String? operationalCode;

  String get operationalErrorCode =>
      operationalCode ??
      OperationalFailureMapper.portal(
        statusCode: statusCode,
        platformCode: code,
      );

  @override
  String toString() => message;
}

Map<String, dynamic> _clientMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

Map<String, Object?> _clientObjectMap(Object? value) {
  return _clientMap(value).map((key, item) => MapEntry(key, item));
}

List<Map<String, dynamic>> _clientListOfMaps(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

String _clientText(Object? value, {String fallback = ''}) {
  final text = value == null ? '' : value.toString().trim();
  return text.isEmpty ? fallback : text;
}

final RegExp _assistantSessionIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

String? _clientAssistantSessionId(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.trim();
  return _assistantSessionIdPattern.hasMatch(text) ? text : null;
}

bool _clientBool(Object? value) {
  if (value is bool) {
    return value;
  }
  final text = value == null ? '' : value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}

int _clientInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int? _clientNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _clientInt(value);
}

double? _clientNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().trim());
}

Uri? _clientUri(Object? value) {
  final text = _clientText(value);
  if (text.isEmpty) {
    return null;
  }
  return Uri.tryParse(text);
}

class ClientLocationsCatalog {
  const ClientLocationsCatalog({
    required this.auto,
    required this.countries,
    required this.freePoolCode,
    required this.profileRevision,
    required this.transportProfile,
    required this.query,
  });

  final ClientLocationAuto auto;
  final List<ClientLocationCountry> countries;
  final String freePoolCode;
  final String profileRevision;
  final String transportProfile;
  final String query;

  factory ClientLocationsCatalog.fromJson(Map<String, dynamic> json) {
    return ClientLocationsCatalog(
      auto: ClientLocationAuto.fromJson(_clientMap(json['auto'])),
      countries: _clientListOfMaps(json['countries'])
          .map(ClientLocationCountry.fromJson)
          .toList(growable: false),
      freePoolCode: _clientText(json['freePoolCode'] ?? json['free_pool_code']),
      profileRevision:
          _clientText(json['profileRevision'] ?? json['profile_revision']),
      transportProfile:
          _clientText(json['transportProfile'] ?? json['transport_profile']),
      query: _clientText(json['query']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'auto': auto.toJson(),
        'countries':
            countries.map((item) => item.toJson()).toList(growable: false),
        'freePoolCode': freePoolCode,
        'profileRevision': profileRevision,
        'transportProfile': transportProfile,
        'query': query,
      };
}

class ClientLocationAuto {
  const ClientLocationAuto({
    required this.enabled,
    required this.currentCode,
  });

  final bool enabled;
  final String currentCode;

  factory ClientLocationAuto.fromJson(Map<String, dynamic> json) {
    return ClientLocationAuto(
      enabled: _clientBool(json['enabled']),
      currentCode: _clientText(json['currentCode'] ?? json['current_code']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'currentCode': currentCode,
      };
}

class ClientLocationCountry {
  const ClientLocationCountry({
    required this.code,
    required this.country,
    required this.cities,
  });

  final String code;
  final String country;
  final List<ClientLocationCity> cities;

  factory ClientLocationCountry.fromJson(Map<String, dynamic> json) {
    return ClientLocationCountry(
      code: _clientText(json['code']),
      country: _clientText(json['country']),
      cities: _clientListOfMaps(json['cities'])
          .map(ClientLocationCity.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'country': country,
        'cities': cities.map((item) => item.toJson()).toList(growable: false),
      };
}

class ClientLocationCity {
  const ClientLocationCity({
    required this.code,
    required this.city,
    required this.healthScore,
    required this.latencyMs,
    required this.premium,
    required this.load,
    this.measuredAt = '',
    this.latencySource = '',
    this.probeHost = '',
    this.probePort = 0,
    this.variants = const <ClientLocationVariant>[],
  });

  final String code;
  final String city;
  final double? healthScore;
  final int? latencyMs;
  final bool premium;
  final double? load;
  final String measuredAt;
  final String latencySource;
  final String probeHost;
  final int probePort;
  final List<ClientLocationVariant> variants;

  factory ClientLocationCity.fromJson(Map<String, dynamic> json) {
    final probe = _clientMap(json['probe']);
    return ClientLocationCity(
      code: _clientText(json['code']),
      city: _clientText(json['city']),
      healthScore: _clientNullableDouble(
        json['healthScore'] ?? json['health_score'],
      ),
      latencyMs: _clientNullableInt(json['latencyMs'] ?? json['latency_ms']),
      premium: _clientBool(json['premium']),
      load: _clientNullableDouble(json['load']),
      measuredAt: _clientText(json['measuredAt'] ?? json['measured_at']),
      latencySource: _clientText(
        json['latencySource'] ?? json['latency_source'],
      ),
      probeHost: _clientText(probe['host']),
      probePort: _clientInt(probe['port']),
      variants: ClientLocationVariant.parseList(json['variants']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'city': city,
        if (healthScore != null) 'healthScore': healthScore,
        if (latencyMs != null) 'latencyMs': latencyMs,
        'premium': premium,
        if (load != null) 'load': load,
        if (measuredAt.isNotEmpty) 'measuredAt': measuredAt,
        if (latencySource.isNotEmpty) 'latencySource': latencySource,
        if (probeHost.isNotEmpty && probePort > 0)
          'probe': <String, Object?>{
            'host': probeHost,
            'port': probePort,
          },
        if (variants.isNotEmpty)
          'variants': variants.map((item) => item.toJson()).toList(
                growable: false,
              ),
      };
}

final _clientLocationVariantIdPattern = RegExp(
  r'^[a-z0-9][a-z0-9._-]{0,63}$',
);

String? normalizeClientLocationVariantId(String value) {
  final normalized = value.trim().toLowerCase();
  return _clientLocationVariantIdPattern.hasMatch(normalized)
      ? normalized
      : null;
}

String _clientLocationVariantText(Object? value, {required int maxLength}) {
  final raw = _clientText(value);
  if (raw.runes.any((codePoint) => codePoint < 32 || codePoint == 127)) {
    return '';
  }
  final normalized = raw.split(RegExp(r'\s+')).join(' ').trim();
  return normalized.length <= maxLength ? normalized : '';
}

class ClientLocationVariant {
  const ClientLocationVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.available,
  });

  final String id;
  final String label;
  final String description;
  final bool available;

  static List<ClientLocationVariant> parseList(Object? value) {
    final variants = <ClientLocationVariant>[];
    final seenIds = <String>{};
    for (final json in _clientListOfMaps(value)) {
      final id = normalizeClientLocationVariantId(_clientText(json['id']));
      final label = _clientLocationVariantText(
        json['label'],
        maxLength: 48,
      );
      if (id == null || label.isEmpty || !seenIds.add(id)) {
        continue;
      }
      variants.add(
        ClientLocationVariant(
          id: id,
          label: label,
          description: _clientLocationVariantText(
            json['description'],
            maxLength: 120,
          ),
          available:
              !json.containsKey('available') || _clientBool(json['available']),
        ),
      );
      if (variants.length == 8) {
        break;
      }
    }
    return List<ClientLocationVariant>.unmodifiable(variants);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'description': description,
        'available': available,
      };
}

class ClientSubscriptionInfo {
  const ClientSubscriptionInfo({
    required this.lane,
    required this.expiresAt,
    required this.daysLeft,
    required this.autoRenew,
    required this.renewUrl,
    required this.plans,
    required this.trafficPolicy,
    this.trafficUsedBytes = 0,
    this.activeConnections = 0,
    this.lastOnlineAt = '',
    this.usageSource = '',
    this.telegramLinked = false,
    this.telegramUsername = '',
    this.emailAddress = '',
    this.emailVerified = false,
  });

  final String lane;
  final String expiresAt;
  final int daysLeft;
  final bool autoRenew;
  final Uri? renewUrl;
  final List<ClientSubscriptionPlan> plans;
  final Map<String, Object?> trafficPolicy;
  final int trafficUsedBytes;
  final int activeConnections;
  final String lastOnlineAt;
  final String usageSource;
  final bool telegramLinked;
  final String telegramUsername;
  final String emailAddress;
  final bool emailVerified;

  factory ClientSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final usage = _clientObjectMap(json['usage']);
    final identities = _clientObjectMap(json['identities']);
    final telegram = _clientObjectMap(identities['telegram']);
    final email = _clientObjectMap(identities['email']);
    return ClientSubscriptionInfo(
      lane: _clientText(json['lane']),
      expiresAt: _clientText(json['expiresAt'] ?? json['expires_at']),
      daysLeft: _clientInt(json['daysLeft'] ?? json['days_left']),
      autoRenew: _clientBool(json['autoRenew'] ?? json['auto_renew']),
      renewUrl: _clientUri(json['renewUrl'] ?? json['renew_url']),
      plans: _clientListOfMaps(json['plans'])
          .map(ClientSubscriptionPlan.fromJson)
          .toList(growable: false),
      trafficPolicy: _clientObjectMap(
        json['trafficPolicy'] ?? json['traffic_policy'],
      ),
      trafficUsedBytes: _clientInt(
        usage['trafficUsedBytes'] ?? usage['traffic_used_bytes'],
      ),
      activeConnections: _clientInt(
        usage['activeConnections'] ?? usage['active_connections'],
      ),
      lastOnlineAt: _clientText(
        usage['lastOnlineAt'] ?? usage['last_online_at'],
      ),
      usageSource: _clientText(usage['source']),
      telegramLinked: _clientBool(telegram['linked']),
      telegramUsername: _clientText(telegram['username']),
      emailAddress: _clientText(email['address']),
      emailVerified: _clientBool(email['verified']),
    );
  }
}

class ClientSubscriptionPlan {
  const ClientSubscriptionPlan({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;

  factory ClientSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return ClientSubscriptionPlan(
      id: _clientText(json['id']),
      title: _clientText(json['title']),
      price: _clientText(json['price']),
    );
  }
}

class ClientDeviceList {
  const ClientDeviceList({required this.items});

  final List<ClientDeviceInfo> items;

  factory ClientDeviceList.fromJson(Map<String, dynamic> json) {
    return ClientDeviceList(
      items: _clientListOfMaps(json['items'])
          .map(ClientDeviceInfo.fromJson)
          .toList(growable: false),
    );
  }
}

class ClientDeviceInfo {
  const ClientDeviceInfo({
    required this.id,
    required this.label,
    required this.platform,
    required this.lastSeen,
    required this.current,
  });

  final String id;
  final String label;
  final String platform;
  final String lastSeen;
  final bool current;

  factory ClientDeviceInfo.fromJson(Map<String, dynamic> json) {
    return ClientDeviceInfo(
      id: _clientText(json['id']),
      label: _clientText(json['label']),
      platform: _clientText(json['platform']),
      lastSeen: _clientText(json['lastSeen'] ?? json['last_seen']),
      current: _clientBool(json['current']),
    );
  }
}

class ClientNotificationInbox {
  const ClientNotificationInbox({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });

  final List<ClientNotificationItem> items;
  final String nextCursor;
  final int unreadCount;

  factory ClientNotificationInbox.fromJson(Map<String, dynamic> json) {
    final items = _clientListOfMaps(json['items'])
        .map(ClientNotificationItem.fromJson)
        .toList(growable: false);
    return ClientNotificationInbox(
      items: items,
      nextCursor: _clientText(json['nextCursor'] ?? json['next_cursor']),
      unreadCount: _clientInt(json['unreadCount'] ?? json['unread_count']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'nextCursor': nextCursor,
        'unreadCount': unreadCount,
      };
}

class ClientNotificationItem {
  const ClientNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.ctaLabel,
    required this.ctaHref,
    required this.read,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String createdAt;
  final String ctaLabel;
  final Uri? ctaHref;
  final bool read;

  factory ClientNotificationItem.fromJson(Map<String, dynamic> json) {
    return ClientNotificationItem(
      id: _clientText(json['id']),
      kind: _clientText(json['kind']),
      title: _clientText(json['title']),
      body: _clientText(json['body']),
      createdAt: _clientText(json['createdAt'] ?? json['created_at']),
      ctaLabel: _clientText(json['ctaLabel'] ?? json['cta_label']),
      ctaHref: _clientUri(json['ctaHref'] ?? json['cta_href']),
      read: _clientBool(json['read']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'ctaLabel': ctaLabel,
        if (ctaHref != null) 'ctaHref': ctaHref.toString(),
        'read': read,
      };
}

class ClientPushRegistration {
  const ClientPushRegistration({
    required this.ok,
    required this.provider,
    required this.tokenHash,
  });

  final bool ok;
  final String provider;
  final String tokenHash;

  factory ClientPushRegistration.fromJson(Map<String, dynamic> json) {
    return ClientPushRegistration(
      ok: json['ok'] != false,
      provider: _clientText(json['provider']),
      tokenHash: _clientText(json['tokenHash'] ?? json['token_hash']),
    );
  }
}

enum ClientSupportAssistantSource {
  pokrovAssistant,
  localFallback;

  String get consumerLabel => switch (this) {
        ClientSupportAssistantSource.pokrovAssistant => 'Помощник POKROV',
        ClientSupportAssistantSource.localFallback => 'Локальная подсказка',
      };

  static ClientSupportAssistantSource fromJson(Object? value) {
    switch (_clientText(value).toLowerCase()) {
      case 'support_agent':
      case 'support_ai':
        return ClientSupportAssistantSource.pokrovAssistant;
      case 'local_fallback':
      default:
        return ClientSupportAssistantSource.localFallback;
    }
  }
}

class ClientSupportAssistantReply {
  const ClientSupportAssistantReply({
    required this.reply,
    required this.shouldEscalate,
    required this.suggestedActions,
    this.assistantSessionId,
    this.source = ClientSupportAssistantSource.localFallback,
  });

  final String reply;
  final bool shouldEscalate;
  final List<ClientSupportAssistantAction> suggestedActions;
  final String? assistantSessionId;
  final ClientSupportAssistantSource source;

  factory ClientSupportAssistantReply.fromJson(Map<String, dynamic> json) {
    return ClientSupportAssistantReply(
      reply: _clientText(json['reply']),
      assistantSessionId: _clientAssistantSessionId(
        json['assistantSessionId'] ?? json['assistant_session_id'],
      ),
      source: ClientSupportAssistantSource.fromJson(json['source']),
      shouldEscalate:
          _clientBool(json['shouldEscalate'] ?? json['should_escalate']),
      suggestedActions: _clientListOfMaps(
        json['suggestedActions'] ?? json['suggested_actions'],
      ).map(ClientSupportAssistantAction.fromJson).toList(growable: false),
    );
  }
}

class ClientSupportAssistantAction {
  const ClientSupportAssistantAction({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;

  factory ClientSupportAssistantAction.fromJson(Map<String, dynamic> json) {
    return ClientSupportAssistantAction(
      key: _clientText(json['key']),
      label: _clientText(json['label']),
    );
  }
}

class SmartConnectPreferenceResult {
  const SmartConnectPreferenceResult({
    required this.preferredNodeCode,
    required this.acceptedSamples,
  });

  final String preferredNodeCode;
  final int acceptedSamples;

  static SmartConnectPreferenceResult tryParse(Object? value) {
    if (value is! Map) {
      return const SmartConnectPreferenceResult(
        preferredNodeCode: '',
        acceptedSamples: 0,
      );
    }
    final json = value.map((key, value) => MapEntry(key.toString(), value));
    return SmartConnectPreferenceResult(
      preferredNodeCode: _readText(
        json['preferred_node_code'] ?? json['selected_node_code'],
      ),
      acceptedSamples: _readInt(json['accepted_samples']),
    );
  }

  static String _readText(Object? value, {String fallback = ''}) {
    final text = value == null ? '' : value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}

class WarpControlStatus {
  const WarpControlStatus({
    required this.feature,
    required this.publicLabel,
    required this.technicalLabel,
    required this.enabled,
    required this.runtimeReady,
    required this.canEnable,
    required this.consented,
    required this.state,
    required this.mode,
    required this.source,
    this.policyState = '',
    this.wireguardConfigAvailable = false,
    this.consentedAt = '',
    this.revokedAt = '',
    this.lastEvent = const <String, Object?>{},
  });

  final String feature;
  final String publicLabel;
  final String technicalLabel;
  final bool enabled;
  final bool runtimeReady;
  final bool canEnable;
  final bool consented;
  final String state;
  final String mode;
  final String source;
  final String policyState;
  final bool wireguardConfigAvailable;
  final String consentedAt;
  final String revokedAt;
  final Map<String, Object?> lastEvent;

  static const unavailable = WarpControlStatus(
    feature: 'extended_protection',
    publicLabel: 'WARP',
    technicalLabel: 'WARP',
    enabled: false,
    runtimeReady: false,
    canEnable: false,
    consented: false,
    state: 'not_ready',
    mode: 'proxy_over_warp',
    source: 'backend_managed',
  );

  WarpControlStatus copyWith({
    String? feature,
    String? publicLabel,
    String? technicalLabel,
    bool? enabled,
    bool? runtimeReady,
    bool? canEnable,
    bool? consented,
    String? state,
    String? mode,
    String? source,
    String? policyState,
    bool? wireguardConfigAvailable,
    String? consentedAt,
    String? revokedAt,
    Map<String, Object?>? lastEvent,
  }) {
    return WarpControlStatus(
      feature: feature ?? this.feature,
      publicLabel: publicLabel ?? this.publicLabel,
      technicalLabel: technicalLabel ?? this.technicalLabel,
      enabled: enabled ?? this.enabled,
      runtimeReady: runtimeReady ?? this.runtimeReady,
      canEnable: canEnable ?? this.canEnable,
      consented: consented ?? this.consented,
      state: state ?? this.state,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      policyState: policyState ?? this.policyState,
      wireguardConfigAvailable:
          wireguardConfigAvailable ?? this.wireguardConfigAvailable,
      consentedAt: consentedAt ?? this.consentedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  WarpRuntimePolicy applyTo(WarpRuntimePolicy policy) {
    final localPolicy = policy.withClientLocalDefaults();
    final backendReady = enabled && runtimeReady;
    final keepLocalRuntime = localPolicy.isClientLocal ||
        (!backendReady && localPolicy.canOfferRuntime);
    final nextEnabled =
        keepLocalRuntime ? localPolicy.enabled : localPolicy.enabled || enabled;
    final nextRuntimeReady = keepLocalRuntime
        ? localPolicy.runtimeReady
        : localPolicy.runtimeReady && runtimeReady;
    final nextSource = keepLocalRuntime
        ? localPolicy.source
        : (source.isEmpty ? localPolicy.source : source);
    final nextState = state.isEmpty
        ? localPolicy.state
        : keepLocalRuntime &&
                (state == 'not_ready' ||
                    state == 'disabled_until_runtime_proof')
            ? localPolicy.state
            : state;
    return policy.copyWith(
      enabled: nextEnabled,
      runtimeReady: nextRuntimeReady,
      state: nextState,
      mode: keepLocalRuntime
          ? localPolicy.mode
          : (mode.isEmpty ? localPolicy.mode : mode),
      source: nextSource,
      userConsented: consented && nextEnabled && nextRuntimeReady,
      id: localPolicy.id,
      licenseKey: localPolicy.licenseKey,
      wireguardConfigJson: localPolicy.wireguardConfigJson,
      accountId: localPolicy.accountId,
      accessToken: localPolicy.accessToken,
      cleanIp: localPolicy.cleanIp,
      cleanPort: localPolicy.cleanPort,
      noise: localPolicy.noise,
      noiseSize: localPolicy.noiseSize,
      noiseDelay: localPolicy.noiseDelay,
      noiseMode: localPolicy.noiseMode,
    );
  }

  static WarpControlStatus fromPolicy(WarpRuntimePolicy policy) {
    return WarpControlStatus(
      feature: 'extended_protection',
      publicLabel: 'WARP',
      technicalLabel: 'WARP',
      enabled: policy.enabled,
      runtimeReady: policy.runtimeReady,
      canEnable: policy.canOfferRuntime && !policy.userConsented,
      consented: policy.userConsented,
      state: policy.userConsented ? 'consented' : policy.state,
      mode: policy.mode,
      source: policy.source,
      wireguardConfigAvailable: policy.wireguardConfigJson.trim().isNotEmpty,
    );
  }

  static WarpControlStatus tryParse(Object? value) {
    final map = _readObjectMap(value);
    if (map.isEmpty) {
      return unavailable;
    }
    return WarpControlStatus(
      feature: _readText(
        map['feature'],
        fallback: 'extended_protection',
      ),
      publicLabel: _readText(
        map['public_label'] ?? map['publicLabel'],
        fallback: 'WARP',
      ),
      technicalLabel: _readText(
        map['technical_label'] ?? map['technicalLabel'],
        fallback: 'WARP',
      ),
      enabled: _readBool(map['enabled']),
      runtimeReady: _readBool(map['runtime_ready'] ?? map['runtimeReady']),
      canEnable: _readBool(map['can_enable'] ?? map['canEnable']),
      consented: _readBool(map['consented']),
      state: _readText(map['state'], fallback: 'not_ready'),
      mode: _readText(map['mode'], fallback: 'proxy_over_warp'),
      source: _readText(map['source'], fallback: 'backend_managed'),
      policyState: _readText(map['policy_state'] ?? map['policyState']),
      wireguardConfigAvailable: _readBool(
        map['wireguard_config_available'] ?? map['wireguardConfigAvailable'],
      ),
      consentedAt: _readText(map['consented_at'] ?? map['consentedAt']),
      revokedAt: _readText(map['revoked_at'] ?? map['revokedAt']),
      lastEvent: _readMap(map['last_event'] ?? map['lastEvent']),
    );
  }

  static Map<String, Object?> _readObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, Object?>{};
  }

  static Map<String, Object?> _readMap(Object? value) {
    return _readObjectMap(value);
  }

  static String _readText(Object? value, {String fallback = ''}) {
    final text = value == null ? '' : value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final text = value == null ? '' : value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}

class AppFirstRedeemResult {
  const AppFirstRedeemResult({
    required this.ok,
    required this.kind,
    required this.codePreview,
    required this.result,
  });

  final bool ok;
  final String kind;
  final String codePreview;
  final Map<String, dynamic> result;
}

class ClientDevicePairingCode {
  const ClientDevicePairingCode({
    required this.id,
    required this.code,
    required this.pairingUri,
    required this.expiresAt,
    required this.ttlSeconds,
  });

  final String id;
  final String code;
  final String pairingUri;
  final String expiresAt;
  final int ttlSeconds;

  factory ClientDevicePairingCode.fromJson(Map<String, dynamic> json) {
    return ClientDevicePairingCode(
      id: _clientText(json['id']),
      code: _clientText(json['code']),
      pairingUri: _clientText(json['pairing_uri']),
      expiresAt: _clientText(json['expires_at']),
      ttlSeconds: _clientInt(json['ttl_seconds']),
    );
  }
}

class DevicePairingClaimResult {
  const DevicePairingClaimResult({
    required this.ok,
    required this.accountId,
    required this.installId,
  });

  final bool ok;
  final String accountId;
  final String installId;
}

class CabinetHandoff {
  const CabinetHandoff({
    required this.token,
    required this.handoffUrl,
    required this.expiresIn,
    required this.targetPath,
    required this.scope,
  });

  final String token;
  final Uri handoffUrl;
  final Duration expiresIn;
  final String targetPath;
  final String scope;
}

class TelegramLinkResult {
  const TelegramLinkResult({
    required this.ok,
    required this.linked,
    required this.linkedTelegramId,
    required this.linkedTelegramUsername,
    required this.startCode,
    required this.botUrl,
    required this.channelUrl,
  });

  final bool ok;
  final bool linked;
  final int? linkedTelegramId;
  final String linkedTelegramUsername;
  final String startCode;
  final Uri botUrl;
  final Uri? channelUrl;
}

class ChannelBonusStatus {
  const ChannelBonusStatus({
    required this.ok,
    required this.subscriber,
    required this.reason,
    required this.pointsGranted,
    required this.campaignMarked,
    required this.linkRequired,
    required this.claimRequired,
    required this.alreadyClaimed,
    required this.bonusDays,
  });

  final bool ok;
  final bool subscriber;
  final String reason;
  final int pointsGranted;
  final bool campaignMarked;
  final bool linkRequired;
  final bool claimRequired;
  final bool alreadyClaimed;
  final int bonusDays;
}

class ChannelBonusClaimResult {
  const ChannelBonusClaimResult({
    required this.ok,
    required this.alreadyClaimed,
    required this.premiumDays,
    required this.claimedAt,
    required this.expiryAt,
    required this.subType,
    required this.channel,
    required this.linkedTelegramId,
    required this.linkedTelegramUsername,
  });

  final bool ok;
  final bool alreadyClaimed;
  final int premiumDays;
  final String claimedAt;
  final String expiryAt;
  final String subType;
  final String channel;
  final int? linkedTelegramId;
  final String linkedTelegramUsername;
}

class AppFirstBonusSummary {
  const AppFirstBonusSummary({
    required this.referralCount,
    required this.referralCode,
    required this.referralBonusDays,
    required this.streakMonths,
    required this.lastWheelSpin,
    required this.channelBonusPremiumDays,
    required this.channelBonusClaimedAt,
    required this.openingBonusPremiumDays,
    required this.openingBonusClaimed,
    required this.channelUsername,
    required this.tierKey,
    required this.tierPercent,
    required this.paidReferrals,
    required this.nextTierKey,
    required this.nextTierAt,
    this.rewardAccess = AppFirstRewardAccess.unknown,
    this.channelBonusEligible = true,
    this.channelBonusCanClaim = true,
    this.channelBonusReason = '',
    this.wheelState = AppFirstBonusFeatureState.wheelDisabled,
    this.calendarState = AppFirstBonusFeatureState.calendarDisabled,
    this.referralSummary = AppFirstReferralSummary.empty,
    this.promoSlots = AppFirstPromoSlots.empty,
    this.historyItems = const <AppFirstBonusHistoryItem>[],
    this.achievementItems = const <AppFirstAchievementItem>[],
    this.questItems = const <AppFirstQuestItem>[],
  });

  final int referralCount;
  final String referralCode;
  final int referralBonusDays;
  final int streakMonths;
  final String lastWheelSpin;
  final int channelBonusPremiumDays;
  final String channelBonusClaimedAt;
  final int openingBonusPremiumDays;
  final bool openingBonusClaimed;
  final String channelUsername;
  final String tierKey;
  final double tierPercent;
  final int paidReferrals;
  final String nextTierKey;
  final int? nextTierAt;
  final AppFirstRewardAccess rewardAccess;
  final bool channelBonusEligible;
  final bool channelBonusCanClaim;
  final String channelBonusReason;
  final AppFirstBonusFeatureState wheelState;
  final AppFirstBonusFeatureState calendarState;
  final AppFirstReferralSummary referralSummary;
  final AppFirstPromoSlots promoSlots;
  final List<AppFirstBonusHistoryItem> historyItems;
  final List<AppFirstAchievementItem> achievementItems;
  final List<AppFirstQuestItem> questItems;

  bool get channelBonusClaimed => channelBonusClaimedAt.trim().isNotEmpty;
}

String _clientShortDateTime(String value) {
  final parsed = DateTime.tryParse(value.trim())?.toLocal();
  if (parsed == null) {
    return value.trim();
  }
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)} в '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

class AppFirstRewardAccess {
  const AppFirstRewardAccess({
    required this.eligible,
    required this.state,
    required this.reason,
    required this.message,
  });

  static const unknown = AppFirstRewardAccess(
    eligible: false,
    state: 'unknown',
    reason: '',
    message: '',
  );

  final bool eligible;
  final String state;
  final String reason;
  final String message;

  bool get paidRequired => !eligible && state == 'paid_required';
}

abstract interface class AppFirstQuestEventService {
  Future<void> completeRoutingLesson({
    required HostPlatform hostPlatform,
  });
}

abstract interface class AppFirstPromoEventService {
  Future<void> reportPromoEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required AppFirstPromoSlot slot,
  });
}

class AppFirstAchievementItem {
  const AppFirstAchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final bool unlocked;
}

class AppFirstQuestItem {
  const AppFirstQuestItem({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.completed,
    required this.actionHref,
    required this.verification,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;
  final bool completed;
  final String actionHref;
  final String verification;
}

class AppFirstBonusRewardResult {
  const AppFirstBonusRewardResult({
    required this.ok,
    required this.rewardDays,
    required this.rewardKey,
    required this.expiryAt,
    required this.summary,
    this.rewardKind = 'days',
    this.rewardValue = 0,
    this.discountPct = 0,
  });

  final bool ok;
  final int rewardDays;
  final String rewardKey;
  final String expiryAt;
  final AppFirstBonusSummary summary;
  final String rewardKind;
  final int rewardValue;
  final int discountPct;
}

class AppFirstReferralSummary {
  const AppFirstReferralSummary({
    required this.count,
    required this.code,
    required this.link,
    required this.bonusDays,
    required this.tierKey,
    required this.tierPercent,
    required this.paidReferrals,
    required this.nextTierKey,
    required this.nextTierAt,
    this.conversion = AppFirstReferralConversion.empty,
    this.history = const <AppFirstReferralHistoryItem>[],
    this.privacy = '',
  });

  static const empty = AppFirstReferralSummary(
    count: 0,
    code: '',
    link: '',
    bonusDays: 0,
    tierKey: '',
    tierPercent: 0,
    paidReferrals: 0,
    nextTierKey: '',
    nextTierAt: null,
    conversion: AppFirstReferralConversion.empty,
    history: <AppFirstReferralHistoryItem>[],
    privacy: '',
  );

  final int count;
  final String code;
  final String link;
  final int bonusDays;
  final String tierKey;
  final double tierPercent;
  final int paidReferrals;
  final String nextTierKey;
  final int? nextTierAt;
  final AppFirstReferralConversion conversion;
  final List<AppFirstReferralHistoryItem> history;
  final String privacy;

  String get shareLink {
    final direct = link.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final safeCode = code.trim();
    if (safeCode.isEmpty) {
      return '';
    }
    return 'https://t.me/pokrov_vpnbot?start=ref_$safeCode';
  }
}

class AppFirstReferralConversion {
  const AppFirstReferralConversion({
    required this.invited,
    required this.activated,
    required this.paid,
    required this.rewarded,
    required this.activationPct,
    required this.paidPct,
  });

  static const empty = AppFirstReferralConversion(
    invited: 0,
    activated: 0,
    paid: 0,
    rewarded: 0,
    activationPct: 0,
    paidPct: 0,
  );

  final int invited;
  final int activated;
  final int paid;
  final int rewarded;
  final double activationPct;
  final double paidPct;
}

class AppFirstReferralHistoryItem {
  const AppFirstReferralHistoryItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.activatedAt,
    required this.paidAt,
    required this.holdUntil,
    required this.rewardedAt,
  });

  final String id;
  final String status;
  final String createdAt;
  final String activatedAt;
  final String paidAt;
  final String holdUntil;
  final String rewardedAt;
}

class AppFirstBonusFeatureState {
  const AppFirstBonusFeatureState({
    required this.ok,
    required this.enabled,
    required this.state,
    required this.featureFlag,
    required this.featureFlagEnabled,
    required this.actionEndpoint,
    required this.lastActionAt,
    required this.streakMonths,
    this.eligible = true,
    this.actionAllowed = true,
    this.reason = '',
    this.nextActionAt = '',
    this.cooldownHours = 0,
  });

  static const wheelDisabled = AppFirstBonusFeatureState(
    ok: true,
    enabled: false,
    state: 'disabled_until_feature_flag',
    featureFlag: 'BONUS_WHEEL_ENABLED',
    featureFlagEnabled: false,
    actionEndpoint: '/api/bonuses/wheel/spin',
    lastActionAt: '',
    streakMonths: 0,
    eligible: false,
    actionAllowed: false,
    reason: 'bonus_feature_disabled',
  );

  static const calendarDisabled = AppFirstBonusFeatureState(
    ok: true,
    enabled: false,
    state: 'disabled_until_feature_flag',
    featureFlag: 'BONUS_CALENDAR_ENABLED',
    featureFlagEnabled: false,
    actionEndpoint: '/api/bonuses/calendar/checkin',
    lastActionAt: '',
    streakMonths: 0,
    eligible: false,
    actionAllowed: false,
    reason: 'bonus_feature_disabled',
  );

  final bool ok;
  final bool enabled;
  final String state;
  final String featureFlag;
  final bool featureFlagEnabled;
  final String actionEndpoint;
  final String lastActionAt;
  final int streakMonths;
  final bool eligible;
  final bool actionAllowed;
  final String reason;
  final String nextActionAt;
  final int cooldownHours;

  bool get isVisible =>
      ok && enabled && featureFlagEnabled && actionEndpoint.trim().isNotEmpty;

  bool get canRun => isVisible && eligible && actionAllowed;

  String get statusLabel {
    if (canRun) {
      return 'Готово';
    }
    if (!eligible && reason == 'active_paid_required') {
      return 'После оплаты';
    }
    if (isVisible && state == 'cooldown') {
      return 'Уже получено';
    }
    if (featureFlagEnabled) {
      return 'На проверке';
    }
    return 'Недоступно';
  }

  String get availabilityText {
    if (canRun) {
      return 'Можно использовать';
    }
    if (!eligible && reason == 'active_paid_required') {
      return 'Откроется после первой оплаты';
    }
    if (isVisible && state == 'cooldown') {
      return nextActionAt.trim().isEmpty
          ? 'Следующая попытка откроется позже'
          : 'Следующая попытка: ${_clientShortDateTime(nextActionAt)}';
    }
    if (featureFlagEnabled) {
      return 'Пока недоступно';
    }
    return 'POKROV покажет эту возможность, когда она станет доступна';
  }
}

class AppFirstPromoSlots {
  const AppFirstPromoSlots({
    required this.surface,
    required this.accessState,
    required this.remoteAvailable,
    required this.fallbackBehavior,
    required this.mode,
    this.serverTime = '',
    required this.slots,
  });

  static const empty = AppFirstPromoSlots(
    surface: 'app',
    accessState: '',
    remoteAvailable: false,
    fallbackBehavior: 'contextual_only_when_remote_unavailable',
    mode: 'whitelist_slots',
    serverTime: '',
    slots: <AppFirstPromoSlot>[],
  );

  final String surface;
  final String accessState;
  final bool remoteAvailable;
  final String fallbackBehavior;
  final String mode;
  final String serverTime;
  final List<AppFirstPromoSlot> slots;

  List<AppFirstPromoSlot> get visibleSlots => slots
      .where(
        (slot) =>
            slot.enabled &&
            (slot.contentId.trim() != 'winback_offer' ||
                slot.hasReadyCommercialOffer) &&
            (slot.title.trim().isNotEmpty ||
                slot.body.trim().isNotEmpty ||
                slot.mediaUrl.trim().isNotEmpty ||
                slot.imageUrl.trim().isNotEmpty),
      )
      .toList(growable: false);

  List<AppFirstPromoSlot> visibleForPlacement(String placement) => visibleSlots
      .where(
        (slot) => slot.placement.trim() == placement.trim(),
      )
      .toList(growable: false);
}

class AppFirstPromoSlot {
  const AppFirstPromoSlot({
    required this.slotId,
    required this.contentId,
    required this.enabled,
    required this.title,
    required this.body,
    this.badgeLabel = '',
    this.imageUrl = '',
    this.imageLayout = 'logo',
    this.mediaType = '',
    this.mediaUrl = '',
    this.posterUrl = '',
    this.fallbackImageUrl = '',
    this.mediaMime = '',
    this.mediaWidth,
    this.mediaHeight,
    this.mediaBytes,
    this.mediaDurationSeconds,
    this.autoplay = false,
    this.loop = true,
    required this.ctaLabel,
    required this.ctaHref,
    this.accentColor = '',
    this.backgroundColor = '',
    this.textColor = '',
    this.buttonColor = '',
    this.buttonTextColor = '',
    this.placement = '',
    this.dismissible = true,
    this.wholeCardClickable = true,
    this.startsAt = '',
    this.endsAt = '',
    this.countdownMode = 'none',
    this.countdownLabel = '',
    this.serverTimeOffsetMs = 0,
    this.pilotId = '',
    this.pilotRevision = '',
    this.pilotContractSha256 = '',
    this.commercialRevision = '',
    this.campaignId = '',
    this.offerId = '',
    this.creativeId = '',
    this.variant = '',
    this.assignmentId = '',
    this.impressionId = '',
    this.clickId = '',
    this.offerState = '',
    this.reasonCode = '',
    this.planCode = '',
    this.currency = '',
    this.basePriceRub,
    this.finalPriceRub,
    this.benefitPercent,
    this.remainingQuotaLowerBound,
    this.termsUrl = '',
    required this.kind,
    required this.goal,
  });

  final String slotId;
  final String contentId;
  final bool enabled;
  final String title;
  final String body;
  final String badgeLabel;
  final String imageUrl;
  final String imageLayout;
  final String mediaType;
  final String mediaUrl;
  final String posterUrl;
  final String fallbackImageUrl;
  final String mediaMime;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaBytes;
  final int? mediaDurationSeconds;
  final bool autoplay;
  final bool loop;
  final String ctaLabel;
  final String ctaHref;
  final String accentColor;
  final String backgroundColor;
  final String textColor;
  final String buttonColor;
  final String buttonTextColor;
  final String placement;
  final bool dismissible;
  final bool wholeCardClickable;
  final String startsAt;
  final String endsAt;
  final String countdownMode;
  final String countdownLabel;
  final int serverTimeOffsetMs;
  final String pilotId;
  final String pilotRevision;
  final String pilotContractSha256;
  final String commercialRevision;
  final String campaignId;
  final String offerId;
  final String creativeId;
  final String variant;
  final String assignmentId;
  final String impressionId;
  final String clickId;
  final String offerState;
  final String reasonCode;
  final String planCode;
  final String currency;
  final int? basePriceRub;
  final int? finalPriceRub;
  final int? benefitPercent;
  final int? remainingQuotaLowerBound;
  final String termsUrl;
  final String kind;
  final String goal;

  bool get hasCommercialLineage =>
      _validPromoCommercialLineage(<String, String>{
        'pilot_id': pilotId,
        'pilot_revision': pilotRevision,
        'pilot_contract_sha256': pilotContractSha256,
        'commercial_revision': commercialRevision,
        'campaign_id': campaignId,
        'offer_id': offerId,
        'creative_id': creativeId,
        'variant': variant,
        'assignment_id': assignmentId,
        'impression_id': impressionId,
        'click_id': clickId,
      });

  bool get hasReadyCommercialOffer {
    final terms = Uri.tryParse(termsUrl.trim());
    final end = DateTime.tryParse(endsAt.trim());
    return hasCommercialLineage &&
        offerState.trim().toLowerCase() == 'ready' &&
        reasonCode.trim().toLowerCase() == 'ready' &&
        planCode.trim().isNotEmpty &&
        currency.trim().toUpperCase() == 'RUB' &&
        basePriceRub != null &&
        finalPriceRub != null &&
        basePriceRub! > finalPriceRub! &&
        finalPriceRub! > 0 &&
        benefitPercent != null &&
        benefitPercent! > 0 &&
        benefitPercent! < 100 &&
        remainingQuotaLowerBound != null &&
        remainingQuotaLowerBound! > 0 &&
        terms != null &&
        terms.scheme == 'https' &&
        terms.host.toLowerCase() == 'pokrov.space' &&
        end != null;
  }
}

const _promoCommercialLineageKeys = <String>{
  'pilot_id',
  'pilot_revision',
  'pilot_contract_sha256',
  'commercial_revision',
  'campaign_id',
  'offer_id',
  'creative_id',
  'variant',
  'assignment_id',
  'impression_id',
  'click_id',
};

bool _validPromoCommercialLineage(Map<String, String> lineage) {
  if (lineage.keys.toSet().containsAll(_promoCommercialLineageKeys) == false) {
    return false;
  }
  bool matches(String key, String pattern) =>
      RegExp(pattern).hasMatch(lineage[key]?.trim().toLowerCase() ?? '');
  return matches('pilot_id', r'^[a-z0-9_]{3,96}$') &&
      matches('pilot_revision', r'^[a-z0-9_.-]{3,64}$') &&
      matches('pilot_contract_sha256', r'^[a-f0-9]{64}$') &&
      matches('commercial_revision', r'^[a-z0-9_.-]{3,64}$') &&
      matches('campaign_id', r'^cmp_[a-f0-9]{32}$') &&
      matches('offer_id', r'^off_[a-f0-9]{32}$') &&
      matches('creative_id', r'^crv_[a-f0-9]{32}$') &&
      matches('variant', r'^[a-z0-9_]{1,32}$') &&
      matches('assignment_id', r'^asg_[a-f0-9]{32}$') &&
      matches('impression_id', r'^imp_[a-f0-9]{32}$') &&
      matches('click_id', r'^clk_[a-f0-9]{32}$');
}

Map<String, String> _readPromoCommercialLineage(Map<String, dynamic> slot) {
  final present = _promoCommercialLineageKeys
      .where((key) => (slot[key]?.toString().trim() ?? '').isNotEmpty)
      .toSet();
  if (present.isEmpty || present.length != _promoCommercialLineageKeys.length) {
    return const <String, String>{};
  }
  final lineage = <String, String>{
    for (final key in _promoCommercialLineageKeys)
      key: slot[key].toString().trim().toLowerCase(),
  };
  return _validPromoCommercialLineage(lineage)
      ? Map<String, String>.unmodifiable(lineage)
      : const <String, String>{};
}

class ClientAppsMetadata {
  const ClientAppsMetadata({
    required this.android,
    required this.windows,
    required this.docsUrl,
    required this.updatedAt,
    required this.updateCheckMode,
    required this.silentUpdate,
  });

  static const empty = ClientAppsMetadata(
    android: ClientAppPlatformMetadata.emptyAndroid,
    windows: ClientAppPlatformMetadata.emptyWindows,
    docsUrl: '',
    updatedAt: '',
    updateCheckMode: 'prompt',
    silentUpdate: false,
  );

  final ClientAppPlatformMetadata android;
  final ClientAppPlatformMetadata windows;
  final String docsUrl;
  final String updatedAt;
  final String updateCheckMode;
  final bool silentUpdate;

  ClientAppUpdateInfo updateFor(HostPlatform hostPlatform) {
    return switch (hostPlatform) {
      HostPlatform.android => android.update,
      HostPlatform.windows => windows.update,
      HostPlatform.ios ||
      HostPlatform.linux ||
      HostPlatform.macos =>
        ClientAppUpdateInfo.none,
    };
  }
}

class ClientAppPlatformMetadata {
  const ClientAppPlatformMetadata({
    required this.platform,
    required this.primaryUrl,
    required this.mirrorUrl,
    required this.version,
    required this.sha256,
    required this.size,
    required this.releaseNotes,
    required this.releaseNotesUrl,
    required this.publishedAt,
    required this.update,
  });

  static const emptyAndroid = ClientAppPlatformMetadata(
    platform: 'android',
    primaryUrl: '',
    mirrorUrl: '',
    version: '',
    sha256: '',
    size: 0,
    releaseNotes: '',
    releaseNotesUrl: '',
    publishedAt: '',
    update: ClientAppUpdateInfo.none,
  );

  static const emptyWindows = ClientAppPlatformMetadata(
    platform: 'windows',
    primaryUrl: '',
    mirrorUrl: '',
    version: '',
    sha256: '',
    size: 0,
    releaseNotes: '',
    releaseNotesUrl: '',
    publishedAt: '',
    update: ClientAppUpdateInfo.none,
  );

  final String platform;
  final String primaryUrl;
  final String mirrorUrl;
  final String version;
  final String sha256;
  final int size;
  final String releaseNotes;
  final String releaseNotesUrl;
  final String publishedAt;
  final ClientAppUpdateInfo update;
}

class ClientAppUpdateInfo {
  const ClientAppUpdateInfo({
    required this.platform,
    required this.channel,
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.updatePolicy,
    required this.url,
    required this.sha256,
    required this.size,
    required this.releaseNotes,
    required this.releaseNotesUrl,
    required this.publishedAt,
  });

  static const none = ClientAppUpdateInfo(
    platform: '',
    channel: 'stable',
    latestVersion: '',
    minSupportedVersion: '',
    updatePolicy: 'none',
    url: '',
    sha256: '',
    size: 0,
    releaseNotes: '',
    releaseNotesUrl: '',
    publishedAt: '',
  );

  final String platform;
  final String channel;
  final String latestVersion;
  final String minSupportedVersion;
  final String updatePolicy;
  final String url;
  final String sha256;
  final int size;
  final String releaseNotes;
  final String releaseNotesUrl;
  final String publishedAt;

  static final RegExp _sha256Pattern = RegExp(r'^[a-fA-F0-9]{64}$');
  static final RegExp _versionPattern =
      RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$');
  static const _maxApkBytes = 256 * 1024 * 1024;
  static const _maxReleaseUrlLength = 2048;
  static const _maxVersionLength = 64;
  static const _canonicalReleaseHost = 'github.com';
  static const _canonicalReleaseOwner = 'kiwunaka';
  static const _canonicalReleaseRepository = 'pokrov';

  /// Validates server metadata before any download starts. The Android host
  /// separately verifies the exact size and SHA-256 before opening the system
  /// package installer.
  Uri? get trustedHandoffUri {
    final normalizedVersion = latestVersion.trim();
    final normalizedUrl = url.trim();
    if (!_sha256Pattern.hasMatch(sha256.trim()) ||
        size <= 0 ||
        size > _maxApkBytes ||
        normalizedUrl.length > _maxReleaseUrlLength ||
        normalizedVersion.length > _maxVersionLength ||
        !_versionPattern.hasMatch(normalizedVersion)) {
      return null;
    }
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.toLowerCase() != _canonicalReleaseHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0].toLowerCase() != _canonicalReleaseOwner ||
        segments[1].toLowerCase() != _canonicalReleaseRepository ||
        segments[2].toLowerCase() != 'releases' ||
        segments[3].toLowerCase() != 'download' ||
        segments[4].trim().isEmpty ||
        segments[5].trim().isEmpty ||
        (platform.trim().toLowerCase() == 'android' &&
            !segments[5].toLowerCase().endsWith('.apk'))) {
      return null;
    }
    return uri;
  }

  bool get shouldPrompt =>
      trustedHandoffUri != null &&
      (updatePolicy == 'recommended' || updatePolicy == 'required');

  bool get isRequired => updatePolicy == 'required';
}

class AppFirstBonusHistoryItem {
  const AppFirstBonusHistoryItem({
    required this.kind,
    required this.source,
    required this.title,
    required this.occurredAt,
    required this.days,
    required this.discountPct,
    required this.codePreview,
  });

  final String kind;
  final String source;
  final String title;
  final String occurredAt;
  final int days;
  final int discountPct;
  final String codePreview;

  String get compactValue {
    if (days > 0) {
      return '+$days дней';
    }
    if (discountPct > 0) {
      return '-$discountPct%';
    }
    if (codePreview.isNotEmpty) {
      return codePreview;
    }
    return occurredAt.isEmpty ? source : occurredAt;
  }
}

class AppFirstRuntimeBootstrapper
    implements
        ManagedProfileBootstrapper,
        CachedManagedProfileBootstrapper,
        AppFirstAccountActionService,
        AppFirstBonusActionService,
        AppFirstWarpActionService,
        AppFirstReleaseActionService,
        AppFirstReleaseHealthService,
        AppFirstExperienceService,
        AppFirstFirstSessionEventService,
        AppFirstAcquisitionService,
        AppFirstQuestEventService,
        AppFirstPromoEventService,
        AppFirstNodePreferenceService,
        AppFirstClientDataService,
        AppFirstEmergencyNetworkService {
  AppFirstRuntimeBootstrapper({
    String apiBaseUrl = 'https://app.pokrov.space',
    List<String>? apiFallbackBaseUrls,
    Future<Directory> Function()? supportDirectoryResolver,
    HttpClient Function()? httpClientFactory,
    Future<void> Function(Duration delay)? delayScheduler,
    this.connectionTimeout = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 15),
    this.supportAssistantRequestTimeout = const Duration(seconds: 65),
    this.smartConnectProbeTimeout = const Duration(milliseconds: 900),
    this.smartConnectTelemetryDeadline = const Duration(seconds: 3),
    this.smartConnectProbeConcurrency = 3,
    this.maxRequestAttempts = 3,
    Duration allExceptRuRuleSetCacheMaxAge = const Duration(hours: 6),
    List<String> Function(String tag)? allExceptRuRuleSetUrlsResolver,
    this.smartConnectLatencyProbe,
    this.deviceNameResolver,
    AppFirstSessionSecretStore? sessionSecretStore,
    AppFirstStateFileWriter? stateFileWriter,
    AppFirstAndroidAbiResolver? androidAbiResolver,
    EmergencyEnvelopeVerifier? emergencyEnvelopeVerifier,
    EmergencyNetworkStore? emergencyNetworkStore,
    ManagedProfileCache? managedProfileCache,
  })  : apiBaseUrl = _normalizeApiBaseUrl(apiBaseUrl),
        _apiBaseUrls = _buildApiBaseUrls(
          apiBaseUrl,
          apiFallbackBaseUrls,
        ),
        _supportDirectoryResolver =
            supportDirectoryResolver ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _delayScheduler = delayScheduler ?? Future<void>.delayed,
        _allExceptRuRuleSetCacheMaxAge = allExceptRuRuleSetCacheMaxAge,
        _allExceptRuRuleSetUrlsResolver = allExceptRuRuleSetUrlsResolver,
        _sessionSecretStore =
            sessionSecretStore ?? FlutterSecureAppFirstSessionSecretStore(),
        _stateFileWriter = stateFileWriter ?? _writeAppFirstStateFileAtomically,
        _androidAbiResolver = androidAbiResolver ?? _resolveAndroidUpdateAbi,
        _emergencyEnvelopeVerifier =
            emergencyEnvelopeVerifier ?? EmergencyEnvelopeVerifier.pinned(),
        _emergencyNetworkStore =
            emergencyNetworkStore ?? EncryptedEmergencyNetworkStore(),
        _managedProfileCache = managedProfileCache ?? ManagedProfileCache();

  final String apiBaseUrl;
  final List<String> _apiBaseUrls;
  final Future<Directory> Function() _supportDirectoryResolver;
  final HttpClient Function() _httpClientFactory;
  final Future<void> Function(Duration delay) _delayScheduler;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final Duration supportAssistantRequestTimeout;
  final Duration smartConnectProbeTimeout;
  final Duration smartConnectTelemetryDeadline;
  final int smartConnectProbeConcurrency;
  final int maxRequestAttempts;
  final Duration _allExceptRuRuleSetCacheMaxAge;
  final List<String> Function(String tag)? _allExceptRuRuleSetUrlsResolver;
  final SmartConnectLatencyProbe? smartConnectLatencyProbe;
  final AppFirstDeviceNameResolver? deviceNameResolver;
  final AppFirstSessionSecretStore _sessionSecretStore;
  final AppFirstStateFileWriter _stateFileWriter;
  final AppFirstAndroidAbiResolver _androidAbiResolver;
  final EmergencyEnvelopeVerifier _emergencyEnvelopeVerifier;
  final EmergencyNetworkStore _emergencyNetworkStore;
  final ManagedProfileCache _managedProfileCache;
  bool _networkContextInFlight = false;
  DateTime? _lastNetworkContextAt;
  String _lastNetworkContextAccount = '';
  final Map<String, Future<_StoredBootstrapState>> _initialStateFlights =
      <String, Future<_StoredBootstrapState>>{};
  final Map<String, Future<_StoredBootstrapState>> _initialTrialFlights =
      <String, Future<_StoredBootstrapState>>{};
  final Map<String, Future<_StoredBootstrapState>> _refreshFlights =
      <String, Future<_StoredBootstrapState>>{};
  final Map<String, Future<void>> _emergencyOfflineCacheFlights =
      <String, Future<void>>{};
  String? _activeApiBaseUrl;
  Future<String>? _apiBaseUrlFlight;
  int _activeSmartConnectProbes = 0;

  static const _defaultManagedManifestPath = '/api/client/profile/managed';
  // Current managed manifests are compact JSON and the checked-in rule-set
  // fixtures are well below these limits. Keep a bounded margin for releases
  // while preventing an untrusted response from growing without limit.
  static const _maxJsonResponseBytes = 8 * 1024 * 1024;
  static const _maxRuleSetResponseBytes = 32 * 1024 * 1024;
  static const _androidShellPackageName = 'space.pokrov.pokrov_android_shell';
  static const _ownedApiHosts = <String>{
    'app.pokrov.space',
    'api.pokrov.space',
  };

  @override
  Future<bool> submitReleaseHealthBatch({
    required HostPlatform hostPlatform,
    required Map<String, Object?> batch,
    required String correlationId,
  }) async {
    final state = await _loadOrCreateState(hostPlatform);
    if (!state.hasSession) {
      return false;
    }
    final client = _createHttpClient(hostPlatform);
    try {
      await PortalCorrelationScope.run(
        correlationId,
        () => _requestJson(
          method: 'POST',
          path: '/api/client/observability/release-health/batches',
          hostPlatform: hostPlatform,
          client: client,
          bearerToken: state.sessionToken,
          body: batch,
        ),
      );
      return true;
    } on BootstrapFailure {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<ClientReleaseHealthBaseline> fetchReleaseHealthBaseline({
    required HostPlatform hostPlatform,
    required OperationalBuildIdentity build,
  }) async {
    final state = await _loadOrCreateState(hostPlatform);
    if (!state.hasSession) {
      return const ClientReleaseHealthBaseline.unavailable();
    }
    final parameters = <String, String>{
      'app_version': build.appVersion,
      'build_number': build.buildNumber,
      'channel': build.channel,
      'candidate_label': build.candidateLabel,
      'git_revision': build.gitRevision,
      if (build.coreAbi != null) 'core_abi': build.coreAbi.toString(),
      'platform': build.platform,
      'architecture': build.architecture,
    };
    final path = Uri(
      path: '/api/client/observability/release-health/baseline',
      queryParameters: parameters,
    ).toString();
    final client = _createHttpClient(hostPlatform);
    try {
      final response = await _requestJson(
        method: 'GET',
        path: path,
        hostPlatform: hostPlatform,
        client: client,
        bearerToken: state.sessionToken,
      );
      return ClientReleaseHealthBaseline.parse(
        response.cast<String, Object?>(),
        expectedBuild: build,
      );
    } on BootstrapFailure {
      return const ClientReleaseHealthBaseline.unavailable();
    } on FormatException {
      return const ClientReleaseHealthBaseline.unavailable();
    } finally {
      client.close(force: true);
    }
  }

  static const _allExceptRuRuleSetCacheDirectoryName =
      'all-except-ru-rule-sets';
  static const _smartConnectTelemetryMaxNodes = 8;
  static const _ruDomainWhitelistRuleSetTag = 'pokrov-ru-domain-whitelist';
  static const _ruDomainCategoryRuleSetTag = 'pokrov-ru-domain-category';
  static const _ruIpCountryRuleSetTag = 'pokrov-ru-ip-country';
  static const _ruIpWhitelistRuleSetTag = 'pokrov-ru-ip-whitelist';
  static const Map<String, List<String>> _defaultAllExceptRuRuleSetUrlsByTag =
      <String, List<String>>{
    _ruDomainWhitelistRuleSetTag: <String>[
      'https://cdn.jsdelivr.net/gh/hydraponique/roscomvpn-geosite/release/sing-box/whitelist.srs',
      'https://fastly.jsdelivr.net/gh/hydraponique/roscomvpn-geosite/release/sing-box/whitelist.srs',
      'https://raw.githubusercontent.com/hydraponique/roscomvpn-geosite/master/release/sing-box/whitelist.srs',
    ],
    _ruDomainCategoryRuleSetTag: <String>[
      'https://cdn.jsdelivr.net/gh/hydraponique/roscomvpn-geosite/release/sing-box/category-ru.srs',
      'https://fastly.jsdelivr.net/gh/hydraponique/roscomvpn-geosite/release/sing-box/category-ru.srs',
      'https://raw.githubusercontent.com/hydraponique/roscomvpn-geosite/master/release/sing-box/category-ru.srs',
    ],
    _ruIpCountryRuleSetTag: <String>[
      'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs',
      'https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs',
      'https://cdn.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-ru.srs',
    ],
    _ruIpWhitelistRuleSetTag: <String>[
      'https://cdn.jsdelivr.net/gh/hydraponique/roscomvpn-geoip/release/sing-box/whitelist.srs',
      'https://fastly.jsdelivr.net/gh/hydraponique/roscomvpn-geoip/release/sing-box/whitelist.srs',
      'https://raw.githubusercontent.com/hydraponique/roscomvpn-geoip/master/release/sing-box/whitelist.srs',
    ],
  };

  @override
  Future<ManagedProfilePayload?> loadCachedManagedProfile(
    ManagedProfileCacheInputs inputs, {
    bool preferProven = false,
  }) async {
    try {
      final state = await _loadState(inputs.hostPlatform);
      if (state == null || !state.hasSession || state.accountId.isEmpty) {
        return null;
      }
      final value = await _managedProfileCache.read(
        platform: inputs.hostPlatform.name,
        binding: inputs.binding(state.accountId, state.installId),
        preferProven: preferProven,
      );
      if (value == null) return null;
      final config = value['config_payload'];
      final revision = _readText(value['revision']);
      if (config is! String || revision.isEmpty ||
          _readMap(jsonDecode(config))['outbounds'] is! List) return null;
      return ManagedProfilePayload(
        cacheEntryId: _readText(value['cache_entry_id']),
        profileName: _profileName(
          hostPlatform: inputs.hostPlatform, profileRevision: revision),
        configPayload: config,
        materializedForRuntime: true,
        source: RuntimeProfileSource(
          revision: revision, origin: RuntimeProfileSourceOrigin.managedManifest),
        tcpFallbackFromRevision: _readText(value['tcp_fallback_from_revision']),
        routeMode: inputs.routeMode,
        resolvedNodeCode: _readText(value['resolved_node_code']),
        smartConnect: SmartConnectProfile.tryParse(value['smart_connect']),
        warpPolicy: WarpRuntimePolicy.tryParse(value['warp_policy']),
        freeProfileAccess: FreeProfileAccess.tryParse(
          access: value['access'], freeCaps: value['free_caps']),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> markManagedProfileProven(
    ManagedProfileCacheInputs inputs,
    String entryId,
  ) async {
    try {
      final state = await _loadState(inputs.hostPlatform);
      if (state == null || !state.hasSession || entryId.isEmpty) return;
      await _managedProfileCache.markProven(
        platform: inputs.hostPlatform.name,
        binding: inputs.binding(state.accountId, state.installId),
        entryId: entryId,
      );
    } on Object {
      // A cache write cannot change the state of an already proven tunnel.
    }
  }

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const <String>{},
    String tcpFallbackFromRevision = '',
    Duration? timeout,
  }) async {
    final normalizedSelectedApps = _normalizeSelectedAppIdentifiers(
      selectedApps,
    );
    final normalizedExcludedNodeCodes = excludedNodeCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .take(8)
        .toSet();
    if ((routeMode == RouteMode.selectedApps ||
            routeMode == RouteMode.excludedApps) &&
        (normalizedSelectedApps.isEmpty ||
            (hostPlatform == HostPlatform.windows &&
                _selectedWindowsProcessNames(
                        hostPlatform, normalizedSelectedApps)
                    .isEmpty))) {
      throw const BootstrapFailure(
        'Выберите хотя бы одно приложение в разделе «Правила».',
      );
    }
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    var timedOut = false;
    final timer = timeout == null ? null : Timer(timeout, () {
      timedOut = true;
      client.close(force: true);
    });

    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          await _syncRoutePolicy(
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            selectedApps: normalizedSelectedApps,
            client: client,
          );
          var manifest = await _fetchManagedManifest(
            tcpFallbackFromRevision: tcpFallbackFromRevision,
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            selectedApps: normalizedSelectedApps,
            preferredNodeCode: preferredNodeCode,
            preferredVariantId: preferredVariantId,
            client: client,
          );
          if (preferredNodeCode.trim().isEmpty &&
              manifest.payload.smartConnect != null) {
            final deadline = DateTime.now().add(smartConnectTelemetryDeadline);
            final smartConnect = manifest.payload.smartConnect;
            final resolution = await _resolveSmartConnectNode(
              smartConnect: manifest.payload.smartConnect,
              state: state,
              hostPlatform: hostPlatform,
              deadline: deadline,
              excludedNodeCodes: normalizedExcludedNodeCodes,
            );
            final selectedNodeCode = resolution.selectedNodeCode;
            if (normalizedExcludedNodeCodes.isNotEmpty &&
                selectedNodeCode.isEmpty) {
              throw const BootstrapFailure(
                'Не удалось найти доступную автоматическую локацию.',
              );
            }
            if (selectedNodeCode.isNotEmpty) {
              try {
                manifest = _promoteSelectedSmartConnectNode(
                  manifest: manifest,
                  selectedNodeCode: selectedNodeCode,
                );
              } on Object {
                try {
                  manifest = await _fetchManagedManifest(
                    tcpFallbackFromRevision: tcpFallbackFromRevision,
                    state: state,
                    hostPlatform: hostPlatform,
                    routeMode: routeMode,
                    selectedApps: normalizedSelectedApps,
                    preferredNodeCode: selectedNodeCode,
                    preferredVariantId: 'direct',
                    client: client,
                  ).timeout(_smartConnectProfileRefreshTimeout);
                } on Object {
                  if (normalizedExcludedNodeCodes.isNotEmpty) {
                    rethrow;
                  }
                  // The preliminary managed profile is already authorized and
                  // usable. A bounded Smart Connect refresh must not turn a
                  // transient selection/refetch failure into a dead-end.
                }
              }
            }
            if (smartConnect != null && resolution.samplePayload.isNotEmpty) {
              unawaited(
                _uploadSmartConnectLatencySamples(
                  state: state,
                  hostPlatform: hostPlatform,
                  smartConnect: smartConnect,
                  selectedNodeCode: selectedNodeCode,
                  selection: resolution.selection,
                  samplePayload: resolution.samplePayload,
                ),
              );
            }
          }
          if (timedOut) throw TimeoutException('Managed profile refresh');
          state = state.copyWith(
            profileRevision: manifest.profileRevision,
            managedManifestPath: manifest.managedManifestPath,
          );
          await _saveState(hostPlatform, state);
          try {
            final currentState = await _loadState(hostPlatform);
            if (currentState?.accountId == state.accountId &&
                currentState?.installId == state.installId &&
                currentState?.hasSession == true) {
              final payload = manifest.payload;
              final response = manifest.response;
              await _managedProfileCache.saveDownloaded(
                platform: hostPlatform.name,
                binding: ManagedProfileCacheInputs(
                  hostPlatform: hostPlatform, routeMode: routeMode,
                  selectedApps: normalizedSelectedApps,
                  preferredNodeCode: preferredNodeCode,
                  preferredVariantId: preferredVariantId,
                ).binding(state.accountId, state.installId),
                revision: manifest.profileRevision,
                verifiedAt: manifest.verifiedAt,
                payload: <String, Object?>{
                  'cache_entry_id': payload.cacheEntryId,
                  'revision': manifest.profileRevision,
                  'config_payload': payload.configPayload,
                  'resolved_node_code': payload.resolvedNodeCode,
                  'tcp_fallback_from_revision': payload.tcpFallbackFromRevision,
                  'smart_connect': payload.smartConnect == null
                      ? null : response['smart_connect'],
                  'warp_policy': response['warp_policy'] ??
                      _readMap(response['client_policy'])['warp_policy'],
                  'access': response['access'], 'free_caps': response['free_caps'],
                },
              );
            }
          } on Object {
            // Keep online connect available if protected cache storage fails.
          }
          return manifest.payload;
        } on BootstrapFailure catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            try {
              await _managedProfileCache.clear(hostPlatform.name);
            } on Object {
              // The explicit denial still propagates; no offline fall-through.
            }
          }
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV не смог завершить подготовку устройства.',
      );
    } finally {
      timer?.cancel();
      client.close(force: true);
    }
  }

  Future<AppFirstRedeemResult> redeemCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      throw const BootstrapFailure('Activation code is required.');
    }

    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/redeem',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: <String, Object?>{
              'code': trimmedCode,
            },
          );
          return AppFirstRedeemResult(
            ok: response['ok'] == true,
            kind: _readText(response['kind']),
            codePreview: _readText(response['code_preview']),
            result: _readMap(response['result']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure('POKROV could not redeem this code.');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<DevicePairingClaimResult> claimDevicePairingCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    final normalized =
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length != 8) {
      throw const BootstrapFailure(
        'Код входа должен содержать восемь символов.',
      );
    }

    final state = await _loadOrCreateState(hostPlatform);
    // A first launch may already have created a trial identity. Pairing uses a
    // fresh install id so that an abandoned trial device cannot conflict with
    // the account selected by the user. The old token is removed only after a
    // successful claim; a failed code leaves the current session untouched.
    final pairedInstallId = _generateInstallId(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      final response = await _requestJson(
        method: 'POST',
        path: '/api/client/device-pairing/claim',
        client: client,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'code': normalized,
          'install_id': pairedInstallId,
          'device_name': await _deviceName(hostPlatform),
          'platform': hostPlatform.name,
          'os_version': _trim(Platform.operatingSystemVersion, 64),
          'app_version': pokrovClientVersion,
          'locale': _trim(Platform.localeName, 32),
          'time_zone': _trim(DateTime.now().timeZoneName, 64),
        },
      );
      final session = _readMap(response['session']);
      final pair = _sessionPairFromResponse(response);
      final accountId = _readText(
        response['canonical_account_id'] ?? session['account_id'],
      );
      if (pair == null || accountId.isEmpty) {
        throw const BootstrapFailure(
          'POKROV не получил подтверждённую сессию устройства.',
        );
      }

      if (state.installId != pairedInstallId) {
        await _sessionSecretStore.deleteSessionToken(
          hostPlatform: hostPlatform,
          installId: state.installId,
        );
      }
      final nextState = state.copyWith(
        installId: pairedInstallId,
        sessionToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        accountId: accountId,
        managedManifestPath: _defaultManagedManifestPath,
        profileRevision: '',
        expectsSecureSessionToken: true,
      );
      await _saveState(hostPlatform, nextState);
      return DevicePairingClaimResult(
        ok: response['ok'] != false,
        accountId: accountId,
        installId: pairedInstallId,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<CabinetHandoff> createCabinetHandoff({
    required HostPlatform hostPlatform,
    String targetPath = '/',
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/client/cabinet-token',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: <String, Object?>{
              'target_path': targetPath.trim().isEmpty ? '/' : targetPath,
            },
          );
          final token = _readText(response['token']);
          final handoffUrlText = _readText(response['handoff_url']);
          if (token.isEmpty || handoffUrlText.isEmpty) {
            throw const BootstrapFailure(
              'POKROV could not create a cabinet handoff.',
            );
          }
          return CabinetHandoff(
            token: token,
            handoffUrl: Uri.parse(handoffUrlText),
            expiresIn: Duration(
              seconds: max(0, _readInt(response['expires_in'])),
            ),
            targetPath: _readText(response['target_path']).isEmpty
                ? '/'
                : _readText(response['target_path']),
            scope: _readText(response['scope']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not create a cabinet handoff.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<WarpControlStatus> fetchWarpStatus({
    required HostPlatform hostPlatform,
  }) async {
    final response = await _requestWarpJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'GET',
      path: '/api/client/warp/status',
    );
    final status = WarpControlStatus.tryParse(response);
    await _saveWarpConsentCache(hostPlatform, status);
    return status;
  }

  @override
  Future<WarpControlStatus> setWarpConsent({
    required HostPlatform hostPlatform,
    required bool enabled,
    String reasonCode = '',
  }) async {
    final response = await _requestWarpJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: enabled ? '/api/client/warp/consent' : '/api/client/warp/revoke',
      body: enabled
          ? <String, Object?>{
              'consent': true,
              if (reasonCode.trim().isNotEmpty)
                'reason_code': reasonCode.trim(),
            }
          : <String, Object?>{
              if (reasonCode.trim().isNotEmpty)
                'reason_code': reasonCode.trim(),
            },
    );
    final status = WarpControlStatus.tryParse(response);
    await _saveWarpConsentCache(hostPlatform, status);
    return status;
  }

  @override
  Future<WarpControlStatus> requestWarpRotation({
    required HostPlatform hostPlatform,
    String reasonCode = 'user_requested',
  }) async {
    final response = await _requestWarpJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/warp/rotate',
      body: <String, Object?>{
        'reason_code':
            reasonCode.trim().isEmpty ? 'user_requested' : reasonCode.trim(),
      },
    );
    final status = WarpControlStatus.tryParse(response);
    await _saveWarpConsentCache(hostPlatform, status);
    return status;
  }

  @override
  Future<WarpControlStatus> reportWarpRuntimeEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    String state = '',
    String reasonCode = '',
    String message = '',
    Map<String, Object?> meta = const <String, Object?>{},
  }) async {
    final safeMessage = _sanitizeWarpRuntimeMessage(message);
    final response = await _requestWarpJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/warp/events',
      body: <String, Object?>{
        'event_name': _safeWarpToken(eventName, fallback: 'runtime_event'),
        if (state.trim().isNotEmpty)
          'state': _safeWarpToken(state, fallback: 'fallback'),
        if (reasonCode.trim().isNotEmpty)
          'reason_code': _safeWarpToken(
            reasonCode,
            fallback: 'runtime_event',
          ),
        if (safeMessage.isNotEmpty) 'message': safeMessage,
        'meta': _sanitizeWarpRuntimeMeta(meta),
      },
    );
    final status = WarpControlStatus.tryParse(response);
    await _saveWarpConsentCache(hostPlatform, status);
    return status;
  }

  @override
  Future<void> reportRuntimeStats({
    required HostPlatform hostPlatform,
    required String runtimePhase,
    required bool connected,
    String errorCode = '',
    String selectedNodeCode = '',
    String routeMode = '',
    int? durationMs,
    int? attemptNumber,
    bool? retryable,
    String networkClass = '',
  }) async {
    final phase = runtimePhase.trim().toLowerCase();
    final safeErrorCode = errorCode.trim().toLowerCase();
    final safeNodeCode = selectedNodeCode.trim().toLowerCase();
    final safeRouteMode = routeMode.trim().toLowerCase();
    final safeNetworkClass = networkClass.trim().toLowerCase();
    if (hostPlatform == HostPlatform.android &&
        const {'app_opened', 'connect_requested', 'running', 'failed'}.contains(phase)) {
      unawaited(_reportAutomaticNetworkContext(phase));
    }
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/runtime/stats',
      body: <String, Object?>{
        'runtime_phase': phase.length <= 32 ? phase : phase.substring(0, 32),
        'connected': connected,
        if (RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(safeErrorCode))
          'error_code': safeErrorCode,
        if (RegExp(r'^[a-z0-9_.-]{1,32}$').hasMatch(safeNodeCode))
          'selected_node_code': safeNodeCode,
        if (RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(safeRouteMode))
          'route_mode': safeRouteMode,
        if (durationMs != null) 'duration_ms': durationMs.clamp(0, 3600000),
        if (attemptNumber != null)
          'attempt_number': attemptNumber.clamp(1, 100),
        if (retryable != null) 'retryable': retryable,
        if (RegExp(r'^[a-z][a-z0-9_.-]{0,23}$').hasMatch(safeNetworkClass))
          'network_class': safeNetworkClass,
      },
    );
  }

  Future<void> _reportAutomaticNetworkContext(String phase) async {
    if (_networkContextInFlight) return;
    _networkContextInFlight = true;
    try {
      final state = await _loadState(HostPlatform.android);
      if (state == null || !state.hasSession || state.accountId.isEmpty) return;
      final now = DateTime.now();
      if (_lastNetworkContextAccount == state.accountId && _lastNetworkContextAt != null &&
          now.difference(_lastNetworkContextAt!) < const Duration(minutes: 1)) return;
      _lastNetworkContextAccount = state.accountId;
      _lastNetworkContextAt = now;
      final result = await _appFirstRuntimeEngineChannel.invokeMapMethod<String, dynamic>(
        'runtimeEngine.observeNetworkContext', <String, Object?>{
          'apiBaseUrl': apiBaseUrl, 'sessionToken': state.sessionToken,
          'appVersion': pokrovClientVersion, 'profileRevision': state.profileRevision,
          'runtimePhase': phase,
        },
      ).timeout(const Duration(seconds: 6));
      if (result == null || result['status'] != 'unavailable') return;
      final current = await _loadState(HostPlatform.android);
      if (current?.accountId != state.accountId || current?.sessionToken != state.sessionToken) return;
      final network = _readText(result['network_class']);
      final carrier = _readText(result['carrier']);
      if (!const {'cellular', 'wifi', 'ethernet', 'other', 'unknown'}.contains(network)) return;
      // A request through the ordinary API can report carrier/unknown, never
      // infer the underlying IP from the tunnel's exit address.
      final client = _createHttpClient(HostPlatform.android);
      try {
        await _requestJson(
          client: client, method: 'POST', path: '/api/client/network/context',
          bearerToken: state.sessionToken, hostPlatform: HostPlatform.android,
          body: <String, Object?>{
            'network_class': network, 'direct_observation': false,
            if (network == 'cellular' && carrier.isNotEmpty && carrier.length <= 80) 'carrier': carrier,
            'profile_revision': state.profileRevision, 'runtime_phase': phase,
          },
        );
      } finally {
        client.close(force: true);
      }
    } on Object {
      // Automatic diagnostics cannot block connect or trigger session renewal.
    } finally {
      _networkContextInFlight = false;
    }
  }

  @override
  Future<void> reportFirstSessionEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required String stage,
    required String result,
    String errorCode = '',
    bool? retryable,
  }) async {
    const allowedEvents = <String>{
      'app_first_open',
      'acquisition_handoff_received',
      'acquisition_handoff_failed',
      'trial_start_selected',
      'existing_access_selected',
      'vpn_permission_explainer_shown',
      'vpn_permission_result',
      'first_home_seen',
      'connect_requested',
      'first_verified_connect',
    };
    const allowedResults = <String>{
      'shown',
      'received',
      'selected',
      'started',
      'seen',
      'success',
      'failure',
      'dismissed',
    };
    final safeEvent = eventName.trim().toLowerCase();
    final safeStage = stage.trim().toLowerCase();
    final safeResult = result.trim().toLowerCase();
    final safeErrorCode = errorCode.trim().toLowerCase();
    if (!allowedEvents.contains(safeEvent) ||
        !RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(safeStage) ||
        !allowedResults.contains(safeResult) ||
        (safeErrorCode.isNotEmpty &&
            !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(safeErrorCode))) {
      return;
    }
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/events',
      body: <String, Object?>{
        'event_name': safeEvent,
        'source': 'app',
        'platform': hostPlatform.name,
        'app_version': pokrovClientVersion,
        'surface': 'first_session',
        'subsystem': 'onboarding',
        'stage': safeStage,
        'result': safeResult,
        if (safeErrorCode.isNotEmpty) 'error_category': 'first_session',
        if (safeErrorCode.isNotEmpty) 'error_code': safeErrorCode,
        if (retryable != null) 'retryable': retryable,
      },
    );
  }

  @override
  Future<void> reportPromoEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required AppFirstPromoSlot slot,
  }) async {
    const allowed = <String>{'impression', 'click', 'dismiss', 'expired'};
    final normalized = eventName.trim().toLowerCase();
    if (!allowed.contains(normalized) || slot.slotId.trim().isEmpty) {
      return;
    }
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/events',
      body: <String, Object?>{
        'event_name': 'promo_$normalized',
        'source': 'app',
        'meta': <String, Object?>{
          'slot_id': slot.slotId.trim().substring(
                0,
                min(120, slot.slotId.trim().length),
              ),
          'content_id': slot.contentId.trim().substring(
                0,
                min(120, slot.contentId.trim().length),
              ),
          'placement': slot.placement.trim().substring(
                0,
                min(64, slot.placement.trim().length),
              ),
          if (slot.hasCommercialLineage) ...<String, Object?>{
            'pilot_id': slot.pilotId.trim(),
            'pilot_revision': slot.pilotRevision.trim(),
            'pilot_contract_sha256': slot.pilotContractSha256.trim(),
            'commercial_revision': slot.commercialRevision.trim(),
            'campaign_id': slot.campaignId.trim(),
            'offer_id': slot.offerId.trim(),
            'creative_id': slot.creativeId.trim(),
            'variant': slot.variant.trim(),
            'assignment_id': slot.assignmentId.trim(),
            'impression_id': slot.impressionId.trim(),
            'click_id': slot.clickId.trim(),
          },
        },
      },
    );
  }

  @override
  Future<void> consumeAcquisitionHandoff({
    required HostPlatform hostPlatform,
    required String handle,
    required String purpose,
  }) async {
    final safeHandle = handle.trim();
    final safePurpose = purpose.trim().toLowerCase();
    if (!RegExp(r'^[A-Za-z0-9_-]{32,160}$').hasMatch(safeHandle) ||
        safePurpose != pokrovAcquisitionPurposeForHost(hostPlatform)) {
      throw const BootstrapFailure('POKROV continuation link is invalid.');
    }
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/acquisition/handoffs/consume',
      body: <String, Object?>{
        'handle': safeHandle,
        'purpose': safePurpose,
      },
    );
  }

  @override
  Future<void> completeAccountOnboarding({
    required HostPlatform hostPlatform,
  }) async {
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/account/experience/onboarding',
      body: <String, Object?>{'status': 'completed'},
    );
  }

  @override
  Future<void> completeRoutingLesson({
    required HostPlatform hostPlatform,
  }) async {
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/events',
      body: const <String, Object?>{
        'event_name': 'routing_lesson_completed',
        'source': 'app',
        'meta': <String, Object?>{'surface': 'route_explainer'},
      },
    );
  }

  Future<Map<String, dynamic>> _requestWarpJsonWithSession({
    required HostPlatform hostPlatform,
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          return await _requestJson(
            method: method,
            path: path,
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: body,
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not update extended protection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<ClientLocationsCatalog> fetchLocationsCatalog({
    required HostPlatform hostPlatform,
    String query = '',
  }) async {
    final params = <String, String>{'platform': hostPlatform.name};
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      params['q'] = trimmedQuery;
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'GET',
      path: Uri(
        path: '/api/client/locations',
        queryParameters: params,
      ).toString(),
    );
    return ClientLocationsCatalog.fromJson(response);
  }

  @override
  Future<AppFirstEmergencyCatalogResult> fetchEmergencyCatalog({
    required HostPlatform hostPlatform,
    required bool manualLimitedNetwork,
    bool forceRefresh = false,
  }) async {
    final initialState = await _loadOrCreateState(hostPlatform);
    final binding = await _emergencyEnvelopeVerifier.deviceBinding(
      initialState.installId,
    );
    if (!forceRefresh) {
      final cached = await _readCachedEmergencyCatalog(
        hostPlatform: hostPlatform,
        installId: initialState.installId,
        deviceBinding: binding,
        manualLimitedNetwork: manualLimitedNetwork,
      );
      if (cached != null) {
        return AppFirstEmergencyCatalogResult(
          catalog: cached,
          reason: 'cached',
          eligibilitySource: cached.eligibilitySource,
          usingCache: true,
        );
      }
    }
    return _refreshEmergencyOfflineBundle(
      hostPlatform: hostPlatform,
      manualLimitedNetwork: manualLimitedNetwork,
      precacheOnly: false,
    );
  }

  @override
  Future<void> prepareEmergencyOfflineCache({
    required HostPlatform hostPlatform,
    bool manualLimitedNetwork = false,
  }) {
    final key = '${hostPlatform.name}:${manualLimitedNetwork ? 1 : 0}';
    final existing = _emergencyOfflineCacheFlights[key];
    if (existing != null) {
      return existing;
    }
    late final Future<void> flight;
    flight = _prepareEmergencyOfflineCache(
      hostPlatform: hostPlatform,
      manualLimitedNetwork: manualLimitedNetwork,
    ).whenComplete(() {
      if (identical(_emergencyOfflineCacheFlights[key], flight)) {
        _emergencyOfflineCacheFlights.remove(key);
      }
    });
    _emergencyOfflineCacheFlights[key] = flight;
    return flight;
  }

  Future<void> _prepareEmergencyOfflineCache({
    required HostPlatform hostPlatform,
    required bool manualLimitedNetwork,
  }) async {
    final state = await _loadOrCreateState(hostPlatform);
    final binding =
        await _emergencyEnvelopeVerifier.deviceBinding(state.installId);
    final cached = await _readCachedEmergencyCatalog(
      hostPlatform: hostPlatform,
      installId: state.installId,
      deviceBinding: binding,
      manualLimitedNetwork: manualLimitedNetwork,
    );
    if (cached != null && cached.refreshAfter.isAfter(DateTime.now().toUtc())) {
      final complete = await _hasCompleteCachedEmergencyBundle(
        hostPlatform: hostPlatform,
        installId: state.installId,
        deviceBinding: binding,
        catalog: cached,
      );
      if (complete) {
        return;
      }
    }
    await _refreshEmergencyOfflineBundle(
      hostPlatform: hostPlatform,
      manualLimitedNetwork: manualLimitedNetwork,
      precacheOnly: true,
    );
  }

  Future<AppFirstEmergencyCatalogResult> _refreshEmergencyOfflineBundle({
    required HostPlatform hostPlatform,
    required bool manualLimitedNetwork,
    required bool precacheOnly,
  }) async {
    final initialState = await _loadOrCreateState(hostPlatform);
    final binding = await _emergencyEnvelopeVerifier.deviceBinding(
      initialState.installId,
    );
    try {
      final response = await _requestClientJsonWithSession(
        hostPlatform: hostPlatform,
        method: 'POST',
        path: '/api/client/emergency-network/offline-bundle',
        body: <String, Object?>{
          'manual_limited_network': manualLimitedNetwork,
          if (precacheOnly) 'precache_only': true,
        },
      );
      if (_readText(response['schemaVersion']) !=
          'pokrov-emergency-offline-bundle-v1') {
        throw const EmergencyContractFailure('bundle_version_invalid');
      }
      final envelope = _readMap(response['catalogEnvelope']);
      final state = await _loadOrCreateState(hostPlatform);
      final catalog = await _emergencyEnvelopeVerifier.parseCatalog(
        envelope,
        installId: state.installId,
      );
      final expected = <String>{
        for (final item in catalog.items.where((item) => item.available))
          for (final mode in item.modes) '${item.id}\u0000${mode.wireValue}',
      };
      final rawProfiles = response['profileEnvelopes'];
      if (expected.length < 4 ||
          expected.length > 36 ||
          rawProfiles is! List ||
          rawProfiles.length != expected.length) {
        throw const EmergencyContractFailure('bundle_profiles_invalid');
      }
      final seen = <String>{};
      final cachedProfiles = <Map<String, Object?>>[];
      for (final rawEntry in rawProfiles) {
        final entry = _readMap(rawEntry);
        if (entry.length != 3 ||
            !entry.containsKey('reserveId') ||
            !entry.containsKey('chainMode') ||
            !entry.containsKey('envelope')) {
          throw const EmergencyContractFailure('bundle_profiles_invalid');
        }
        final reserveId = _readText(entry['reserveId']);
        final chainMode = EmergencyChainMode.tryParse(entry['chainMode']);
        final key = '$reserveId\u0000${chainMode?.wireValue ?? ''}';
        if (chainMode == null || !expected.contains(key) || !seen.add(key)) {
          throw const EmergencyContractFailure('bundle_profiles_invalid');
        }
        final profileEnvelope = _readMap(entry['envelope']);
        await _emergencyEnvelopeVerifier.parseProfile(
          profileEnvelope,
          installId: state.installId,
          catalogRevision: catalog.revision,
          reserveId: reserveId,
          chainMode: chainMode,
        );
        cachedProfiles.add(<String, Object?>{
          'reserve_id': reserveId,
          'chain_mode': chainMode.wireValue,
          'envelope': profileEnvelope,
        });
      }
      if (seen.length != expected.length) {
        throw const EmergencyContractFailure('bundle_profiles_invalid');
      }
      await _emergencyNetworkStore.writeEnvelope(
        hostPlatform: hostPlatform,
        deviceBinding: catalog.deviceBinding,
        kind: EmergencyCacheKind.profileBundle,
        envelope: <String, dynamic>{
          'schema_version': 1,
          'catalog_revision': catalog.revision,
          'profiles': cachedProfiles,
        },
      );
      await _emergencyNetworkStore.writeEnvelope(
        hostPlatform: hostPlatform,
        deviceBinding: catalog.deviceBinding,
        kind: EmergencyCacheKind.catalog,
        envelope: envelope,
      );
      return AppFirstEmergencyCatalogResult(
        catalog: catalog,
        reason: 'ready',
        eligibilitySource: catalog.eligibilitySource,
        usingCache: false,
      );
    } on EmergencyContractFailure catch (error) {
      throw BootstrapFailure(
        'Экстренная сеть получила неподтверждённые данные. Обновите приложение или попробуйте позже.',
        operation: 'POST /api/client/emergency-network/offline-bundle',
        code: error.code,
      );
    } on BootstrapFailure catch (error) {
      if (error.statusCode == HttpStatus.unauthorized) {
        final cached = await _readCachedEmergencyCatalog(
          hostPlatform: hostPlatform,
          installId: initialState.installId,
          deviceBinding: binding,
          manualLimitedNetwork: manualLimitedNetwork,
        );
        if (cached != null) {
          return AppFirstEmergencyCatalogResult(
            catalog: cached,
            reason: 'cached',
            eligibilitySource: cached.eligibilitySource,
            usingCache: true,
          );
        }
        rethrow;
      }
      if (error.statusCode == HttpStatus.forbidden) {
        rethrow;
      }
      if (_isTransientEmergencyFailure(error)) {
        final cached = await _readCachedEmergencyCatalog(
          hostPlatform: hostPlatform,
          installId: initialState.installId,
          deviceBinding: binding,
          manualLimitedNetwork: manualLimitedNetwork,
        );
        if (cached != null) {
          return AppFirstEmergencyCatalogResult(
            catalog: cached,
            reason: 'cached',
            eligibilitySource: cached.eligibilitySource,
            usingCache: true,
          );
        }
      }
      rethrow;
    }
  }

  Future<EmergencyCatalog?> _readCachedEmergencyCatalog({
    required HostPlatform hostPlatform,
    required String installId,
    required String deviceBinding,
    required bool manualLimitedNetwork,
  }) async {
    final envelope = await _emergencyNetworkStore.readEnvelope(
      hostPlatform: hostPlatform,
      deviceBinding: deviceBinding,
      kind: EmergencyCacheKind.catalog,
    );
    if (envelope == null) {
      return null;
    }
    try {
      final catalog = await _emergencyEnvelopeVerifier.parseCatalog(
        envelope,
        installId: installId,
      );
      if (!manualLimitedNetwork &&
          const {'manual_limited_network', 'entitlement_precache'}
              .contains(catalog.eligibilitySource)) {
        return null;
      }
      return catalog;
    } on Object {
      await _emergencyNetworkStore.clear(
        hostPlatform: hostPlatform,
        deviceBinding: deviceBinding,
      );
      return null;
    }
  }

  Future<bool> _hasCompleteCachedEmergencyBundle({
    required HostPlatform hostPlatform,
    required String installId,
    required String deviceBinding,
    required EmergencyCatalog catalog,
  }) async {
    final bundle = await _emergencyNetworkStore.readEnvelope(
      hostPlatform: hostPlatform,
      deviceBinding: deviceBinding,
      kind: EmergencyCacheKind.profileBundle,
    );
    if (bundle == null ||
        bundle['schema_version'] != 1 ||
        _readText(bundle['catalog_revision']) != catalog.revision) {
      return false;
    }
    final rawProfiles = bundle['profiles'];
    if (rawProfiles is! List || rawProfiles.length > 36) {
      return false;
    }
    final expected = <String>{
      for (final item in catalog.items.where((item) => item.available))
        for (final mode in item.modes) '${item.id}\u0000${mode.wireValue}',
    };
    final seen = <String>{};
    for (final rawEntry in rawProfiles) {
      try {
        final entry = _readMap(rawEntry);
        final reserveId = _readText(entry['reserve_id']);
        final chainMode = EmergencyChainMode.tryParse(entry['chain_mode']);
        if (chainMode == null) {
          return false;
        }
        final key = '$reserveId\u0000${chainMode.wireValue}';
        if (!expected.contains(key) || !seen.add(key)) {
          return false;
        }
        await _emergencyEnvelopeVerifier.parseProfile(
          _readMap(entry['envelope']),
          installId: installId,
          catalogRevision: catalog.revision,
          reserveId: reserveId,
          chainMode: chainMode,
        );
      } on Object {
        return false;
      }
    }
    return seen.length == expected.length;
  }

  @override
  Future<AppFirstEmergencyProfileResult> resolveEmergencyProfile({
    required HostPlatform hostPlatform,
    required String catalogRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
    required bool manualLimitedNetwork,
  }) async {
    final state = await _loadOrCreateState(hostPlatform);
    final binding =
        await _emergencyEnvelopeVerifier.deviceBinding(state.installId);
    EmergencyProfile? profile = await _readCachedEmergencyProfile(
      hostPlatform: hostPlatform,
      installId: state.installId,
      deviceBinding: binding,
      catalogRevision: catalogRevision,
      reserveId: reserveId,
      chainMode: chainMode,
    );
    var usingCache = profile != null;
    if (profile == null) {
      try {
        final response = await _requestClientJsonWithSession(
          hostPlatform: hostPlatform,
          method: 'POST',
          path: '/api/client/emergency-network/profile',
          body: <String, Object?>{
            'catalog_revision': catalogRevision,
            'reserve_id': reserveId,
            'chain_mode': chainMode.wireValue,
            'manual_limited_network': manualLimitedNetwork,
          },
        );
        final envelope = _readMap(response['envelope']);
        final refreshedState = await _loadOrCreateState(hostPlatform);
        profile = await _emergencyEnvelopeVerifier.parseProfile(
          envelope,
          installId: refreshedState.installId,
          catalogRevision: catalogRevision,
          reserveId: reserveId,
          chainMode: chainMode,
        );
        await _emergencyNetworkStore.writeEnvelope(
          hostPlatform: hostPlatform,
          deviceBinding: profile.deviceBinding,
          kind: EmergencyCacheKind.profile,
          envelope: envelope,
        );
        usingCache = false;
      } on EmergencyContractFailure catch (error) {
        await _emergencyNetworkStore.clear(
          hostPlatform: hostPlatform,
          deviceBinding: binding,
        );
        throw BootstrapFailure(
          'Экстренный профиль не прошёл проверку подписи и не будет запущен.',
          operation: 'POST /api/client/emergency-network/profile',
          code: error.code,
        );
      } on BootstrapFailure catch (error) {
        if (error.statusCode == HttpStatus.unauthorized ||
            error.statusCode == HttpStatus.forbidden ||
            !_isTransientEmergencyFailure(error)) {
          await _emergencyNetworkStore.clear(
            hostPlatform: hostPlatform,
            deviceBinding: binding,
          );
        }
        rethrow;
      }
    }
    final resolved = profile;
    final managed = await _materializeEmergencyManagedProfile(
      hostPlatform: hostPlatform,
      profile: resolved,
    );
    return AppFirstEmergencyProfileResult(
      profile: resolved,
      managedProfile: managed,
      usingCache: usingCache,
    );
  }

  Future<EmergencyProfile?> _readCachedEmergencyProfile({
    required HostPlatform hostPlatform,
    required String installId,
    required String deviceBinding,
    required String catalogRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
  }) async {
    final bundle = await _emergencyNetworkStore.readEnvelope(
      hostPlatform: hostPlatform,
      deviceBinding: deviceBinding,
      kind: EmergencyCacheKind.profileBundle,
    );
    if (bundle != null) {
      try {
        if (bundle['schema_version'] != 1 ||
            _readText(bundle['catalog_revision']) != catalogRevision) {
          throw const FormatException('Emergency bundle revision is invalid.');
        }
        final rawProfiles = bundle['profiles'];
        if (rawProfiles is! List || rawProfiles.length > 36) {
          throw const FormatException('Emergency bundle is invalid.');
        }
        for (final rawEntry in rawProfiles) {
          final entry = _readMap(rawEntry);
          if (_readText(entry['reserve_id']) != reserveId ||
              EmergencyChainMode.tryParse(entry['chain_mode']) != chainMode) {
            continue;
          }
          return await _emergencyEnvelopeVerifier.parseProfile(
            _readMap(entry['envelope']),
            installId: installId,
            catalogRevision: catalogRevision,
            reserveId: reserveId,
            chainMode: chainMode,
          );
        }
      } on Object {
        await _emergencyNetworkStore.clear(
          hostPlatform: hostPlatform,
          deviceBinding: deviceBinding,
        );
        return null;
      }
    }
    final envelope = await _emergencyNetworkStore.readEnvelope(
      hostPlatform: hostPlatform,
      deviceBinding: deviceBinding,
      kind: EmergencyCacheKind.profile,
    );
    if (envelope == null) {
      return null;
    }
    try {
      return await _emergencyEnvelopeVerifier.parseProfile(
        envelope,
        installId: installId,
        catalogRevision: catalogRevision,
        reserveId: reserveId,
        chainMode: chainMode,
      );
    } on Object {
      await _emergencyNetworkStore.clear(
        hostPlatform: hostPlatform,
        deviceBinding: deviceBinding,
      );
      return null;
    }
  }

  Future<ManagedProfilePayload> _materializeEmergencyManagedProfile({
    required HostPlatform hostPlatform,
    required EmergencyProfile profile,
  }) async {
    final runtimePayload = jsonDecode(jsonEncode(profile.configPayload));
    if (runtimePayload is! Map) {
      throw const BootstrapFailure(
        'POKROV получил неполный резервный профиль.',
      );
    }
    final emergencyConfig = runtimePayload.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    _normalizeEmergencyRuntimeDns(emergencyConfig);
    _addEmergencyRuntimeEgressProbe(emergencyConfig);
    final materialized = await _materializeRuntimeConfig(
      rawConfigPayload: jsonEncode(emergencyConfig),
      hostPlatform: hostPlatform,
      routeMode: RouteMode.allExceptRu,
      selectedApps: const <String>[],
      preferredNodeCode: '',
      preferredVariantId: 'direct',
      smartConnect: null,
      supportContext: const <String, dynamic>{},
      clientRuleSetCatalog: _ClientRuleSetCatalog.empty,
    );
    return ManagedProfilePayload(
      profileName: 'pokrov-emergency-${profile.profileRevision}',
      source: RuntimeProfileSource(
        revision: profile.profileRevision,
        origin: RuntimeProfileSourceOrigin.signedEmergencyEnvelope,
      ),
      configPayload: materialized,
      materializedForRuntime: true,
      quickSettingsEligible: false,
      coreEgressProbeRequired: true,
      routeMode: RouteMode.allExceptRu,
      warpPolicy: WarpRuntimePolicy.disabled,
    );
  }

  void _normalizeEmergencyRuntimeDns(Map<String, dynamic> config) {
    final dns = Map<String, dynamic>.from(_readMap(config['dns']));
    final servers = _readListOfMaps(dns['servers'])
        .map((server) => Map<String, dynamic>.from(server))
        .toList(growable: false);
    final emergencyServers = servers
        .where((server) => _readText(server['tag']) == 'emergency-dns')
        .toList(growable: false);
    if (emergencyServers.length != 1) {
      throw const BootstrapFailure(
        'POKROV получил неполный резервный профиль.',
      );
    }
    emergencyServers.single
      ..remove('type')
      ..remove('server')
      ..remove('server_port')
      ..remove('address_resolver')
      ..['address'] = 'https://1.1.1.1/dns-query';
    dns['strategy'] = 'ipv4_only';
    dns['servers'] = servers;
    config['dns'] = dns;
  }

  void _addEmergencyRuntimeEgressProbe(Map<String, dynamic> config) {
    final outbounds = _readListOfMaps(config['outbounds'])
        .map((outbound) => Map<String, dynamic>.from(outbound))
        .toList(growable: true);
    final route = Map<String, dynamic>.from(_readMap(config['route']));
    final finalTag = _readText(route['final']);
    final existingTags = outbounds
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (finalTag.isEmpty || !existingTags.contains(finalTag)) {
      throw const BootstrapFailure(
        'POKROV получил неполный резервный профиль.',
      );
    }
    final finalOutbound = outbounds.singleWhere(
      (outbound) => _readText(outbound['tag']) == finalTag,
    );
    var probeCopyTag = 'pokrov-emergency-probe-copy';
    var copySuffix = 2;
    while (existingTags.contains(probeCopyTag)) {
      probeCopyTag = 'pokrov-emergency-probe-copy-$copySuffix';
      copySuffix += 1;
    }
    final probeCopyPayload = jsonDecode(jsonEncode(finalOutbound));
    if (probeCopyPayload is! Map) {
      throw const BootstrapFailure(
        'POKROV получил неполный резервный профиль.',
      );
    }
    final probeCopy = probeCopyPayload.map(
      (key, value) => MapEntry(key.toString(), value),
    )..['tag'] = probeCopyTag;
    outbounds.add(probeCopy);
    existingTags.add(probeCopyTag);
    var probeTag = 'pokrov-emergency-health';
    var suffix = 2;
    while (existingTags.contains(probeTag)) {
      probeTag = 'pokrov-emergency-health-$suffix';
      suffix += 1;
    }
    outbounds.add(<String, dynamic>{
      'type': 'selector',
      'tag': probeTag,
      'outbounds': <String>[finalTag, probeCopyTag],
      'default': finalTag,
      'interrupt_exist_connections': false,
    });
    route['final'] = probeTag;
    config['outbounds'] = outbounds;
    config['route'] = route;
  }

  bool _isTransientEmergencyFailure(BootstrapFailure error) {
    final statusCode = error.statusCode;
    return statusCode == null ||
        statusCode == HttpStatus.requestTimeout ||
        statusCode == HttpStatus.tooManyRequests ||
        statusCode == HttpStatus.badGateway ||
        statusCode == HttpStatus.serviceUnavailable ||
        statusCode == HttpStatus.gatewayTimeout;
  }

  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform,
  }) async {
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'GET',
      path: '/api/client/subscription',
    );
    return ClientSubscriptionInfo.fromJson(response);
  }

  @override
  Future<ClientDeviceList> fetchClientDevices({
    required HostPlatform hostPlatform,
  }) async {
    try {
      await _requestClientJsonWithSession(
        hostPlatform: hostPlatform,
        method: 'PATCH',
        path: '/api/client/devices/current',
        body: <String, Object?>{
          'device_name': await _deviceName(hostPlatform),
          'platform': hostPlatform.name,
          'os_version': _trim(Platform.operatingSystemVersion, 64),
          'app_version': pokrovClientVersion,
        },
      );
    } on BootstrapFailure catch (error) {
      if (error.statusCode != HttpStatus.notFound &&
          error.statusCode != HttpStatus.methodNotAllowed) {
        rethrow;
      }
      // Keeps an updated client compatible with the brief deployment window
      // before the metadata endpoint reaches every production instance.
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'GET',
      path: '/api/client/devices',
    );
    return ClientDeviceList.fromJson(response);
  }

  @override
  Future<bool> revokeClientDevice({
    required HostPlatform hostPlatform,
    required String deviceId,
  }) async {
    final safeDeviceId = deviceId.trim();
    if (safeDeviceId.isEmpty) {
      throw const BootstrapFailure('Device id is required.');
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'DELETE',
      path: '/api/client/devices/${Uri.encodeComponent(safeDeviceId)}',
    );
    return response['ok'] != false;
  }

  @override
  Future<ClientDevicePairingCode> issueDevicePairingCode({
    required HostPlatform hostPlatform,
  }) async {
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/device-pairing/codes',
    );
    final pairing = ClientDevicePairingCode.fromJson(
      _readMap(response['pairing']),
    );
    if (pairing.id.isEmpty || pairing.code.isEmpty) {
      throw const BootstrapFailure(
        'POKROV не получил одноразовый код устройства.',
      );
    }
    return pairing;
  }

  @override
  Future<bool> cancelDevicePairingCode({
    required HostPlatform hostPlatform,
    required String pairingId,
  }) async {
    final id = pairingId.trim();
    if (id.isEmpty) {
      return true;
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'DELETE',
      path: '/api/client/device-pairing/codes/${Uri.encodeComponent(id)}',
    );
    return response['ok'] != false;
  }

  @override
  Future<ClientNotificationInbox> fetchClientNotifications({
    required HostPlatform hostPlatform,
    String after = '',
  }) async {
    final params = <String, String>{};
    final cursor = after.trim();
    if (cursor.isNotEmpty) {
      params['after'] = cursor;
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'GET',
      path: Uri(
        path: '/api/client/notifications',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
    return ClientNotificationInbox.fromJson(response);
  }

  @override
  Future<bool> markClientNotificationsRead({
    required HostPlatform hostPlatform,
    required List<String> ids,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .take(100)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return true;
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/notifications/read',
      body: <String, Object?>{'ids': normalizedIds},
    );
    return response['ok'] != false;
  }

  @override
  Future<bool> dismissClientNotifications({
    required HostPlatform hostPlatform,
    required List<String> ids,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .take(100)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return true;
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/notifications/dismiss',
      body: <String, Object?>{'ids': normalizedIds},
    );
    return response['ok'] != false;
  }

  @override
  Future<ClientPushRegistration> registerClientPushToken({
    required HostPlatform hostPlatform,
    required String token,
    required String provider,
  }) async {
    final safeToken = token.trim();
    if (safeToken.isEmpty) {
      throw const BootstrapFailure('Push token is required.');
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/push/register',
      body: <String, Object?>{
        'platform': hostPlatform.name,
        'token': safeToken,
        'provider': provider.trim().isEmpty ? 'poll' : provider.trim(),
      },
    );
    return ClientPushRegistration.fromJson(response);
  }

  @override
  Future<ClientSupportAssistantReply> askSupportAssistant({
    required HostPlatform hostPlatform,
    required String message,
    int? ticketId,
    String? assistantSessionId,
    Map<String, Object?> safeDiagnostics = const <String, Object?>{},
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw const BootstrapFailure('Support message is required.');
    }
    final validSessionId = _clientAssistantSessionId(assistantSessionId);
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/support/assistant',
      requestTimeoutOverride: supportAssistantRequestTimeout,
      body: <String, Object?>{
        'message': text,
        'scope': 'support',
        if (ticketId != null) 'ticketId': ticketId,
        if (validSessionId != null) 'assistantSessionId': validSessionId,
        'safeDiagnostics': _sanitizeWarpRuntimeMeta(safeDiagnostics),
      },
    );
    return ClientSupportAssistantReply.fromJson(response);
  }

  Future<Map<String, dynamic>> _requestClientJsonWithSession({
    required HostPlatform hostPlatform,
    required String method,
    required String path,
    Map<String, Object?>? body,
    Duration? requestTimeoutOverride,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          return await _requestJson(
            method: method,
            path: path,
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: body,
            requestTimeoutOverride: requestTimeoutOverride,
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure('POKROV could not update app data.');
    } finally {
      client.close(force: true);
    }
  }

  Future<TelegramLinkResult> createTelegramLink({
    required HostPlatform hostPlatform,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/client/telegram/link',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
          );
          final botUrlText = _readText(response['bot_url']);
          if (botUrlText.isEmpty) {
            throw const BootstrapFailure(
              'POKROV could not create a Telegram link.',
            );
          }
          return TelegramLinkResult(
            ok: response['ok'] == true,
            linked: response['linked'] == true,
            linkedTelegramId: _readNullableInt(response['linked_telegram_id']),
            linkedTelegramUsername:
                _readText(response['linked_telegram_username']),
            startCode: _readText(response['start_code']),
            botUrl: Uri.parse(botUrlText),
            channelUrl: _readOptionalUri(response['channel_url']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not create a Telegram link.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> reportTelegramLinkEvent({
    required HostPlatform hostPlatform,
    required String eventName,
  }) async {
    const allowed = <String>{
      'handoff_opened',
      'handoff_open_failed',
      'verify_requested',
    };
    final normalized = eventName.trim().toLowerCase();
    if (!allowed.contains(normalized)) {
      return;
    }
    await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/telegram/link/events',
      body: <String, Object?>{'event_name': normalized},
    );
  }

  Future<ChannelBonusStatus> checkChannelBonus({
    required HostPlatform hostPlatform,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/channel/subscriber/check',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
          );
          return ChannelBonusStatus(
            ok: response['ok'] == true,
            subscriber: response['subscriber'] == true,
            reason: _readText(response['reason']),
            pointsGranted: _readInt(response['points_granted']),
            campaignMarked: response['campaign_marked'] == true,
            linkRequired: response['link_required'] == true,
            claimRequired: response['claim_required'] == true,
            alreadyClaimed: response['already_claimed'] == true,
            bonusDays: _readInt(response['bonus_days']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not check the Telegram bonus.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ChannelBonusClaimResult> claimChannelBonus({
    required HostPlatform hostPlatform,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/bonuses/channel/claim',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
          );
          return ChannelBonusClaimResult(
            ok: response['ok'] == true,
            alreadyClaimed: response['already_claimed'] == true,
            premiumDays: _readInt(response['premium_days']),
            claimedAt: _readText(response['claimed_at']),
            expiryAt: _readText(response['expiry_at']),
            subType: _readText(response['sub_type']),
            channel: _readText(response['channel']),
            linkedTelegramId: _readNullableInt(response['linked_telegram_id']),
            linkedTelegramUsername:
                _readText(response['linked_telegram_username']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not activate the Telegram bonus.',
      );
    } finally {
      client.close(force: true);
    }
  }

  ClientAppPlatformMetadata _readClientAppPlatformMetadata({
    required String platform,
    required Map<String, Object?> response,
  }) {
    final update = _readMap(response['update']);
    final primaryUrl = platform == 'android'
        ? _readText(response['apk_url'])
        : _readText(response['exe_url']);
    return ClientAppPlatformMetadata(
      platform: platform,
      primaryUrl: primaryUrl,
      mirrorUrl: _readText(response['mirror_url']),
      version: _readText(response['version']),
      sha256: _readText(response['sha256']),
      size: _readInt(response['size']),
      releaseNotes: _readText(response['release_notes']),
      releaseNotesUrl: _readText(response['release_notes_url']),
      publishedAt: _readText(response['published_at']),
      update: ClientAppUpdateInfo(
        platform: _readText(update['platform'], fallback: platform),
        channel: _readText(update['channel'], fallback: 'stable'),
        latestVersion: _readText(update['latest_version']),
        minSupportedVersion: _readText(update['min_supported_version']),
        updatePolicy: _readText(update['update_policy'], fallback: 'none'),
        url: _readText(update['url']),
        sha256: _readText(update['sha256']),
        size: _readInt(update['size']),
        releaseNotes: _readText(update['release_notes']),
        releaseNotesUrl: _readText(update['release_notes_url']),
        publishedAt: _readText(update['published_at']),
      ),
    );
  }

  @override
  Future<ClientAppsMetadata> fetchClientApps({
    required HostPlatform hostPlatform,
    required String currentVersion,
    String channel = 'stable',
  }) async {
    final client = _createHttpClient(hostPlatform);
    try {
      final platformLabel = switch (hostPlatform) {
        HostPlatform.android => 'android',
        HostPlatform.windows => 'windows',
        HostPlatform.ios => 'ios',
        HostPlatform.linux => 'linux',
        HostPlatform.macos => 'macos',
      };
      final androidAbi = hostPlatform == HostPlatform.android
          ? (await _androidAbiResolver(hostPlatform))?.trim().toLowerCase() ??
              ''
          : '';
      final query = Uri(
        queryParameters: <String, String>{
          'platform': platformLabel,
          'current_version': currentVersion.trim(),
          'channel': channel.trim().isEmpty ? 'stable' : channel.trim(),
          if (_supportedAndroidUpdateAbis.contains(androidAbi))
            'android_abi': androidAbi,
        },
      ).query;
      // Update discovery must work before sign-in, during an expired session,
      // and while the account API is degraded. It is public release metadata;
      // never create or repair a trial merely to check for a new APK/EXE.
      final response = await _requestJson(
        method: 'GET',
        path: '/api/public/client-apps?$query',
        client: client,
        hostPlatform: hostPlatform,
      );
      final updateCheck = _readMap(response['update_check']);
      return ClientAppsMetadata(
        android: _readClientAppPlatformMetadata(
          platform: 'android',
          response: _readMap(response['android']),
        ),
        windows: _readClientAppPlatformMetadata(
          platform: 'windows',
          response: _readMap(response['windows']),
        ),
        docsUrl: _readText(response['docs_url']),
        updatedAt: _readText(response['updated_at']),
        updateCheckMode: _readText(
          updateCheck['mode'],
          fallback: 'prompt',
        ),
        silentUpdate: updateCheck['silent_update'] == true,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<SmartConnectPreferenceResult> setPreferredSmartConnectNode({
    required HostPlatform hostPlatform,
    required SmartConnectProfile smartConnect,
    required String nodeCode,
  }) async {
    final normalizedNode = nodeCode.trim().toLowerCase();
    if (normalizedNode.isEmpty) {
      throw const BootstrapFailure('Выберите локацию из списка.');
    }
    final allowedCodes = {
      for (final node in smartConnect.shortlist) node.code.trim().toLowerCase(),
    }..remove('');
    if (allowedCodes.isNotEmpty && !allowedCodes.contains(normalizedNode)) {
      throw const BootstrapFailure(
        'Эта локация недоступна для текущего доступа.',
      );
    }

    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: '/api/client/nodes/select',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: <String, Object?>{
              'mode': 'manual',
              'profile_revision': smartConnect.profileRevision,
              'transport_profile': smartConnect.transportProfile,
              'selected_node_code': normalizedNode,
              'previous_node_code':
                  smartConnect.stickiness.preferredNodeCode.trim().isEmpty
                      ? null
                      : smartConnect.stickiness.preferredNodeCode.trim(),
              'samples': const <Map<String, Object?>>[],
            },
          );
          return SmartConnectPreferenceResult.tryParse(response);
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV не смог сохранить выбранную локацию.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AppFirstBonusSummary> fetchBonusSummary({
    required HostPlatform hostPlatform,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'GET',
            path: '/api/bonuses/summary',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
          );
          final tier = _readMap(response['points_tier']);
          final wheel = _readMap(response['wheel']);
          final calendar = _readMap(response['calendar']);
          final achievements = _readMap(response['achievements']);
          final rewardAccess = _readMap(response['reward_access']);
          final channelBonus = _readMap(response['channel_bonus']);
          final referralCount = _readInt(response['referral_count']);
          final referralCode = _readText(response['referral_code']);
          final referralBonusDays = _readInt(response['referral_bonus_days']);
          final referralSummaryFallback = _readReferralSummary(
            _readMap(response['referral']),
            fallbackCount: referralCount,
            fallbackCode: referralCode,
            fallbackBonusDays: referralBonusDays,
            fallbackTier: tier,
          );
          final historyItems = await _fetchBonusHistoryItems(
            summaryResponse: response,
            hostPlatform: hostPlatform,
            client: client,
            bearerToken: state.sessionToken,
          );
          final referralSummary = await _fetchReferralSummary(
            hostPlatform: hostPlatform,
            client: client,
            bearerToken: state.sessionToken,
            fallback: referralSummaryFallback,
          );
          final promoSlots = await _fetchPromoSlots(
            hostPlatform: hostPlatform,
            client: client,
            bearerToken: state.sessionToken,
          );
          return AppFirstBonusSummary(
            referralCount: referralCount,
            referralCode: referralCode,
            referralBonusDays: referralBonusDays,
            streakMonths: _readInt(response['streak_months']),
            lastWheelSpin: _readText(response['last_wheel_spin']),
            channelBonusPremiumDays:
                _readInt(response['channel_bonus_premium_days']),
            channelBonusClaimedAt:
                _readText(response['channel_bonus_claimed_at']),
            openingBonusPremiumDays:
                _readInt(response['opening_bonus_premium_days']),
            openingBonusClaimed: response['opening_bonus_claimed'] == true,
            channelUsername: _readText(response['channel_username']),
            tierKey: _readText(tier['tier_key']),
            tierPercent: _readDouble(tier['percent']),
            paidReferrals: _readInt(tier['paid_referrals']),
            nextTierKey: _readText(tier['next_tier_key']),
            nextTierAt: _readNullableInt(tier['next_tier_at']),
            rewardAccess: AppFirstRewardAccess(
              eligible: rewardAccess['eligible'] == true,
              state: _readText(rewardAccess['state']),
              reason: _readText(rewardAccess['reason']),
              message: _readText(rewardAccess['message']),
            ),
            channelBonusEligible: channelBonus['eligible'] == true,
            channelBonusCanClaim: channelBonus['can_claim'] == true,
            channelBonusReason: _readText(channelBonus['reason']),
            wheelState: _readBonusFeatureState(
              wheel,
              fallback: AppFirstBonusFeatureState.wheelDisabled,
              actionEndpointKey: 'spin_endpoint',
              actionAllowedKey: 'can_spin',
              nextActionAtKey: 'next_spin_at',
              lastActionAtKeys: const <String>['last_spin_at'],
            ),
            calendarState: _readBonusFeatureState(
              calendar,
              fallback: AppFirstBonusFeatureState.calendarDisabled,
              actionEndpointKey: 'checkin_endpoint',
              actionAllowedKey: 'can_checkin',
              lastActionAtKeys: const <String>[
                'last_checkin_at',
                'last_wheel_spin',
              ],
            ),
            referralSummary: referralSummary,
            promoSlots: promoSlots,
            historyItems: historyItems,
            achievementItems: _readListOfMaps(achievements['items'])
                .map(
                  (item) => AppFirstAchievementItem(
                    id: _readText(item['id']),
                    title: _readText(item['title']),
                    description: _readText(item['description']),
                    unlocked: item['unlocked'] == true,
                  ),
                )
                .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
                .take(20)
                .toList(growable: false),
            questItems: _readListOfMaps(achievements['quests'])
                .map(
                  (item) => AppFirstQuestItem(
                    id: _readText(item['id']),
                    title: _readText(item['title']),
                    description: _readText(item['description']),
                    progress: _readInt(item['progress']),
                    target: _readInt(item['target']),
                    completed: item['completed'] == true,
                    actionHref: _readText(item['action_href']),
                    verification: _readText(item['verification']),
                  ),
                )
                .where(
                  (item) =>
                      item.id.isNotEmpty &&
                      item.title.isNotEmpty &&
                      item.target > 0,
                )
                .take(10)
                .toList(growable: false),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw const BootstrapFailure(
        'POKROV could not load the bonus summary.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AppFirstBonusRewardResult> spinBonusWheel({
    required HostPlatform hostPlatform,
  }) {
    return _runBonusRewardAction(
      hostPlatform: hostPlatform,
      path: '/api/bonuses/wheel/spin',
      failureMessage: 'POKROV could not claim the wheel reward.',
    );
  }

  @override
  Future<AppFirstBonusRewardResult> checkInBonusCalendar({
    required HostPlatform hostPlatform,
  }) {
    return _runBonusRewardAction(
      hostPlatform: hostPlatform,
      path: '/api/bonuses/calendar/checkin',
      failureMessage: 'POKROV could not claim the calendar reward.',
    );
  }

  Future<AppFirstBonusRewardResult> _runBonusRewardAction({
    required HostPlatform hostPlatform,
    required String path,
    required String failureMessage,
  }) async {
    var state = await _loadOrCreateState(hostPlatform);
    final client = _createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _requestJson(
            method: 'POST',
            path: path,
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
          );
          final summary = await fetchBonusSummary(
            hostPlatform: hostPlatform,
          );
          return AppFirstBonusRewardResult(
            ok: response['ok'] == true,
            rewardDays: _readInt(response['reward_days']),
            rewardKey: _readText(response['reward_key']),
            expiryAt: _readText(response['expiry_at']),
            summary: summary,
            rewardKind: _readText(response['reward_kind']).isEmpty
                ? 'days'
                : _readText(response['reward_kind']),
            rewardValue: _readInt(response['reward_value']),
            discountPct: _readInt(response['discount_pct']),
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 && _isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          rethrow;
        }
      }

      throw BootstrapFailure(failureMessage);
    } finally {
      client.close(force: true);
    }
  }

  Future<AppFirstPromoSlots> _fetchPromoSlots({
    required HostPlatform hostPlatform,
    required HttpClient client,
    required String bearerToken,
  }) async {
    try {
      final response = await _requestJson(
        method: 'GET',
        path: '/api/client/promo-slots?surface=app',
        client: client,
        bearerToken: bearerToken,
        hostPlatform: hostPlatform,
      );
      final serverTime = _readText(response['server_time']);
      final parsedServerTime = DateTime.tryParse(serverTime)?.toUtc();
      final serverTimeOffsetMs = parsedServerTime == null
          ? 0
          : parsedServerTime.difference(DateTime.now().toUtc()).inMilliseconds;
      return AppFirstPromoSlots(
        surface: _readText(response['surface']).isEmpty
            ? 'app'
            : _readText(response['surface']),
        accessState: _readText(response['access_state']),
        remoteAvailable: response['remote_available'] == true,
        fallbackBehavior: _readText(response['fallback_behavior']),
        mode: _readText(response['mode']),
        serverTime: serverTime,
        slots: _readListOfMaps(response['slots'])
            .map((slot) {
              final lineage = _readPromoCommercialLineage(slot);
              return AppFirstPromoSlot(
                slotId: _readText(slot['slot_id']),
                contentId: _readText(slot['content_id']),
                enabled: slot['enabled'] != false,
                title: _readText(slot['title']),
                body: _readText(slot['body']),
                badgeLabel: _readText(slot['badge_label']),
                imageUrl: _readText(slot['image_url']),
                imageLayout: _readText(slot['image_layout']).isEmpty
                    ? 'logo'
                    : _readText(slot['image_layout']),
                mediaType: _readText(slot['media_type']),
                mediaUrl: _readText(slot['media_url']),
                posterUrl: _readText(slot['poster_url']),
                fallbackImageUrl: _readText(slot['fallback_image_url']),
                mediaMime: _readText(slot['media_mime']),
                mediaWidth: _readNullableInt(slot['media_width']),
                mediaHeight: _readNullableInt(slot['media_height']),
                mediaBytes: _readNullableInt(slot['media_bytes']),
                mediaDurationSeconds:
                    _readNullableInt(slot['media_duration_seconds']),
                autoplay: slot['autoplay'] == true,
                loop: slot['loop'] != false,
                ctaLabel: _readText(slot['cta_label']),
                ctaHref: _readText(slot['cta_href']),
                accentColor: _readText(slot['accent_color']),
                backgroundColor: _readText(slot['background_color']),
                textColor: _readText(slot['text_color']),
                buttonColor: _readText(slot['button_color']),
                buttonTextColor: _readText(slot['button_text_color']),
                placement: _readText(slot['placement']),
                dismissible: slot['dismissible'] != false,
                wholeCardClickable: slot['whole_card_clickable'] != false,
                startsAt: _readText(slot['starts_at']),
                endsAt: _readText(slot['ends_at']),
                countdownMode: _readText(slot['countdown_mode']).isEmpty
                    ? 'none'
                    : _readText(slot['countdown_mode']),
                countdownLabel: _readText(slot['countdown_label']),
                serverTimeOffsetMs: serverTimeOffsetMs,
                pilotId: lineage['pilot_id'] ?? '',
                pilotRevision: lineage['pilot_revision'] ?? '',
                pilotContractSha256: lineage['pilot_contract_sha256'] ?? '',
                commercialRevision: lineage['commercial_revision'] ?? '',
                campaignId: lineage['campaign_id'] ?? '',
                offerId: lineage['offer_id'] ?? '',
                creativeId: lineage['creative_id'] ?? '',
                variant: lineage['variant'] ?? '',
                assignmentId: lineage['assignment_id'] ?? '',
                impressionId: lineage['impression_id'] ?? '',
                clickId: lineage['click_id'] ?? '',
                offerState:
                    lineage.isEmpty ? '' : _readText(slot['offer_state']),
                reasonCode:
                    lineage.isEmpty ? '' : _readText(slot['reason_code']),
                planCode: lineage.isEmpty ? '' : _readText(slot['plan_code']),
                currency: lineage.isEmpty ? '' : _readText(slot['currency']),
                basePriceRub: lineage.isEmpty
                    ? null
                    : _readNullableInt(slot['base_price_rub']),
                finalPriceRub: lineage.isEmpty
                    ? null
                    : _readNullableInt(slot['final_price_rub']),
                benefitPercent: lineage.isEmpty
                    ? null
                    : _readNullableInt(slot['benefit_percent']),
                remainingQuotaLowerBound: lineage.isEmpty
                    ? null
                    : _readNullableInt(slot['remaining_quota_lower_bound']),
                termsUrl: lineage.isEmpty ? '' : _readText(slot['terms_url']),
                kind: _readText(slot['kind']),
                goal: _readText(slot['goal']),
              );
            })
            .where((slot) => slot.slotId.isNotEmpty)
            .toList(growable: false),
      );
    } on BootstrapFailure {
      return AppFirstPromoSlots.empty;
    }
  }

  Future<AppFirstReferralSummary> _fetchReferralSummary({
    required HostPlatform hostPlatform,
    required HttpClient client,
    required String bearerToken,
    required AppFirstReferralSummary fallback,
  }) async {
    try {
      final response = await _requestJson(
        method: 'GET',
        path: '/api/bonuses/referral/summary',
        client: client,
        bearerToken: bearerToken,
        hostPlatform: hostPlatform,
      );
      return _readReferralSummary(
        response,
        fallbackCount: fallback.count,
        fallbackCode: fallback.code,
        fallbackBonusDays: fallback.bonusDays,
        fallbackTier: <String, Object?>{
          'tier_key': fallback.tierKey,
          'percent': fallback.tierPercent,
          'paid_referrals': fallback.paidReferrals,
          'next_tier_key': fallback.nextTierKey,
          'next_tier_at': fallback.nextTierAt,
        },
      );
    } on BootstrapFailure {
      return fallback;
    }
  }

  AppFirstReferralSummary _readReferralSummary(
    Map<String, dynamic> data, {
    required int fallbackCount,
    required String fallbackCode,
    required int fallbackBonusDays,
    required Map<String, Object?> fallbackTier,
  }) {
    final tier = _readMap(data['tier']).isEmpty
        ? _readMap(data['points_tier'])
        : _readMap(data['tier']);
    final resolvedTier = tier.isEmpty ? fallbackTier : tier;
    final conversion = _readMap(data['conversion']);
    return AppFirstReferralSummary(
      count: data.containsKey('count')
          ? _readInt(data['count'])
          : _readInt(data['referral_count']) == 0
              ? fallbackCount
              : _readInt(data['referral_count']),
      code: _readText(data['code']).isNotEmpty
          ? _readText(data['code'])
          : _readText(data['referral_code']).isNotEmpty
              ? _readText(data['referral_code'])
              : fallbackCode,
      link: _readText(data['link']),
      bonusDays: data.containsKey('bonus_days')
          ? _readInt(data['bonus_days'])
          : _readInt(data['referral_bonus_days']) == 0
              ? fallbackBonusDays
              : _readInt(data['referral_bonus_days']),
      tierKey: _readText(resolvedTier['tier_key']),
      tierPercent: _readDouble(resolvedTier['percent']),
      paidReferrals: _readInt(resolvedTier['paid_referrals']),
      nextTierKey: _readText(resolvedTier['next_tier_key']),
      nextTierAt: _readNullableInt(resolvedTier['next_tier_at']),
      conversion: AppFirstReferralConversion(
        invited: _readInt(conversion['invited']),
        activated: _readInt(conversion['activated']),
        paid: _readInt(conversion['paid']),
        rewarded: _readInt(conversion['rewarded']),
        activationPct: _readDouble(conversion['activation_pct']),
        paidPct: _readDouble(conversion['paid_pct']),
      ),
      history: _readListOfMaps(data['history'])
          .map(
            (item) => AppFirstReferralHistoryItem(
              id: _readText(item['id']),
              status: _readText(item['status']),
              createdAt: _readText(item['created_at']),
              activatedAt: _readText(item['activated_at']),
              paidAt: _readText(item['paid_at']),
              holdUntil: _readText(item['hold_until']),
              rewardedAt: _readText(item['rewarded_at']),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.status.isNotEmpty)
          .take(20)
          .toList(growable: false),
      privacy: _readText(data['privacy']),
    );
  }

  AppFirstBonusFeatureState _readBonusFeatureState(
    Map<String, dynamic> data, {
    required AppFirstBonusFeatureState fallback,
    required String actionEndpointKey,
    required String actionAllowedKey,
    String nextActionAtKey = '',
    required List<String> lastActionAtKeys,
  }) {
    if (data.isEmpty) {
      return fallback;
    }
    var lastActionAt = '';
    for (final key in lastActionAtKeys) {
      lastActionAt = _readText(data[key]);
      if (lastActionAt.isNotEmpty) {
        break;
      }
    }
    return AppFirstBonusFeatureState(
      ok: data['ok'] != false,
      enabled: data['enabled'] == true,
      state: _readText(data['state']).isEmpty
          ? fallback.state
          : _readText(data['state']),
      featureFlag: _readText(data['feature_flag']).isEmpty
          ? fallback.featureFlag
          : _readText(data['feature_flag']),
      featureFlagEnabled: data['feature_flag_enabled'] == true,
      actionEndpoint: _readText(data[actionEndpointKey]).isEmpty
          ? fallback.actionEndpoint
          : _readText(data[actionEndpointKey]),
      lastActionAt: lastActionAt,
      streakMonths: _readInt(data['streak_months']),
      eligible: data.containsKey('eligible')
          ? data['eligible'] == true
          : fallback.eligible,
      actionAllowed: data.containsKey(actionAllowedKey)
          ? data[actionAllowedKey] == true
          : fallback.actionAllowed,
      reason: _readText(data['reason']),
      nextActionAt:
          nextActionAtKey.isEmpty ? '' : _readText(data[nextActionAtKey]),
      cooldownHours: _readInt(data['cooldown_hours']),
    );
  }

  Future<List<AppFirstBonusHistoryItem>> _fetchBonusHistoryItems({
    required Map<String, dynamic> summaryResponse,
    required HostPlatform hostPlatform,
    required HttpClient client,
    required String bearerToken,
  }) async {
    final history = _readMap(summaryResponse['history']);
    var endpoint = _readText(history['endpoint']);
    if (endpoint.isEmpty) {
      endpoint = '/api/bonuses/history';
    }
    if (!endpoint.startsWith('/api/bonuses/')) {
      return const <AppFirstBonusHistoryItem>[];
    }

    try {
      final response = await _requestJson(
        method: 'GET',
        path: endpoint,
        client: client,
        bearerToken: bearerToken,
        hostPlatform: hostPlatform,
      );
      return _readListOfMaps(response['items'])
          .map(
            (item) => AppFirstBonusHistoryItem(
              kind: _readText(item['kind']),
              source: _readText(item['source']),
              title: _readText(item['title']),
              occurredAt: _readText(item['occurred_at']),
              days: _readInt(item['days']),
              discountPct: _readInt(item['discount_pct']),
              codePreview: _readText(item['code_preview']),
            ),
          )
          .where((item) => item.title.isNotEmpty)
          .take(3)
          .toList(growable: false);
    } on BootstrapFailure {
      return const <AppFirstBonusHistoryItem>[];
    }
  }

  HttpClient _createHttpClient(HostPlatform _) =>
      _httpClientFactory()..connectionTimeout = connectionTimeout;

  Future<_StoredBootstrapState> _loadOrCreateState(
    HostPlatform hostPlatform,
  ) {
    final key = hostPlatform.name;
    final inFlight = _initialStateFlights[key];
    if (inFlight != null) {
      return inFlight;
    }
    final creation = _loadOrCreateStateWithFileLock(hostPlatform);
    _initialStateFlights[key] = creation;
    creation.then<void>(
      (_) => _removeInitialStateFlight(key, creation),
      onError: (_, __) => _removeInitialStateFlight(key, creation),
    );
    return creation;
  }

  Future<_StoredBootstrapState> _loadOrCreateStateWithFileLock(
    HostPlatform hostPlatform,
  ) async {
    final file = await _stateFile(hostPlatform);
    return _withAppFirstStateFileLock(file, () async {
      final existing = await _loadStateFromFile(hostPlatform, file);
      if (existing != null) {
        return existing;
      }
      final created = _StoredBootstrapState(
        installId: _generateInstallId(hostPlatform),
        managedManifestPath: _defaultManagedManifestPath,
        sessionToken: '',
        accountId: '',
        profileRevision: '',
      );
      await _persistStateToFile(
        hostPlatform: hostPlatform,
        file: file,
        state: created,
      );
      return created;
    });
  }

  void _removeInitialStateFlight(
    String key,
    Future<_StoredBootstrapState> creation,
  ) {
    if (identical(_initialStateFlights[key], creation)) {
      _initialStateFlights.remove(key);
    }
  }

  Future<_StoredBootstrapState?> _loadState(HostPlatform hostPlatform) async {
    final file = await _stateFile(hostPlatform);
    return _withAppFirstStateFileLock(
      file,
      () => _loadStateFromFile(hostPlatform, file),
    );
  }

  Future<_StoredBootstrapState?> _loadStateFromFile(
    HostPlatform hostPlatform,
    File file,
  ) async {
    final backupFile = File('${file.path}.bak');
    if (!await file.exists() && await backupFile.exists()) {
      await backupFile.rename(file.path);
    }
    if (!await file.exists()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const BootstrapFailure(
        'This device needs to be set up again before it can connect.',
      );
    }
    final parsed = _StoredBootstrapState.fromJson(
      decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    // A persisted path is untrusted input. Validate it before reading secrets
    // or allowing any authenticated route-policy/profile request.
    _validatedManagedManifestPath(parsed.managedManifestPath);
    final securePair = await _sessionSecretStore.readSessionPair(
      hostPlatform: hostPlatform,
      installId: parsed.installId,
    );
    if (securePair != null && securePair.hasAccessToken) {
      if (parsed.sessionToken.isNotEmpty || parsed.requiresSchemaMigration) {
        await _persistStateToFile(
          hostPlatform: hostPlatform,
          file: file,
          state: parsed.copyWith(
            sessionToken: securePair.accessToken,
            refreshToken: securePair.refreshToken,
            expectsSecureSessionToken: true,
          ),
        );
      }
      await _cleanupStateWriteArtifacts(file);
      return parsed.copyWith(
        sessionToken: securePair.accessToken,
        refreshToken: securePair.refreshToken,
        expectsSecureSessionToken: true,
      );
    }
    if (parsed.sessionToken.isNotEmpty) {
      await _sessionSecretStore.writeSessionToken(
        hostPlatform: hostPlatform,
        installId: parsed.installId,
        sessionToken: parsed.sessionToken,
      );
      final migrated = parsed.copyWith(
        refreshToken: '',
        expectsSecureSessionToken: true,
      );
      await _persistStateToFile(
        hostPlatform: hostPlatform,
        file: file,
        state: migrated,
      );
      await _cleanupStateWriteArtifacts(file);
      return migrated;
    }
    if (parsed.expectsSecureSessionToken) {
      throw const BootstrapFailure(
        'Сохраненная сессия устройства недоступна. Используйте почту или код, '
        'чтобы восстановить доступ.',
      );
    }
    if (parsed.requiresSchemaMigration) {
      await _persistStateToFile(
        hostPlatform: hostPlatform,
        file: file,
        state: parsed,
      );
    }
    await _cleanupStateWriteArtifacts(file);
    return parsed;
  }

  Future<void> _cleanupStateWriteArtifacts(File file) async {
    for (final suffix in const <String>['.bak', '.next']) {
      final artifact = File('${file.path}$suffix');
      if (await artifact.exists()) {
        await artifact.delete();
      }
    }
  }

  Future<void> _saveState(
    HostPlatform hostPlatform,
    _StoredBootstrapState state,
  ) async {
    final file = await _stateFile(hostPlatform);
    await _withAppFirstStateFileLock(
      file,
      () => _persistStateToFile(
        hostPlatform: hostPlatform,
        file: file,
        state: state,
      ),
    );
  }

  Future<void> _persistStateToFile({
    required HostPlatform hostPlatform,
    required File file,
    required _StoredBootstrapState state,
  }) async {
    await file.parent.create(recursive: true);
    if (state.sessionToken.trim().isNotEmpty) {
      await _sessionSecretStore.writeSessionPair(
        hostPlatform: hostPlatform,
        installId: state.installId,
        pair: AppFirstSessionCredentials(
          accessToken: state.sessionToken,
          refreshToken: state.refreshToken,
        ),
      );
    } else {
      await _sessionSecretStore.deleteSessionToken(
        hostPlatform: hostPlatform,
        installId: state.installId,
      );
    }
    await _stateFileWriter(file, jsonEncode(state.toJson()));
  }

  Future<File> _stateFile(HostPlatform hostPlatform) async {
    final supportDirectory = await _supportDirectoryResolver();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'app-first-session-${hostPlatform.name}.json',
    );
  }

  Future<void> _saveWarpConsentCache(
    HostPlatform hostPlatform,
    WarpControlStatus status,
  ) async {
    final file = await _warpConsentCacheFile(hostPlatform);
    await file.parent.create(recursive: true);
    final updatedAt =
        status.consented ? status.consentedAt.trim() : status.revokedAt.trim();
    await file.writeAsString(
      jsonEncode(
        <String, Object?>{
          'schema_version': 1,
          'feature': 'extended_protection',
          'public_label': _safeWarpPublicLabel(status.publicLabel),
          'consented': status.consented,
          'state': _safeWarpToken(status.state, fallback: 'not_ready'),
          if (updatedAt.isNotEmpty) 'consent_updated_at': updatedAt,
        },
      ),
    );
  }

  Future<File> _warpConsentCacheFile(HostPlatform hostPlatform) async {
    final supportDirectory = await _supportDirectoryResolver();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'warp-consent-${hostPlatform.name}.json',
    );
  }

  String _safeWarpPublicLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return 'WARP';
    }
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  Future<_StoredBootstrapState> _startTrial({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) {
    // An existing install must refresh its device session, never bootstrap a
    // second trial identity. Callers clear only the expired access token, so
    // the securely retained rotating credential is still available here.
    if (state.refreshToken.trim().isNotEmpty) {
      return _refreshSession(
        state: state,
        hostPlatform: hostPlatform,
        client: client,
      );
    }
    if (state.expectsSecureSessionToken) {
      return Future<_StoredBootstrapState>.error(const BootstrapFailure(
        'Сессия устройства истекла. Используйте почту или код, чтобы восстановить доступ.',
        statusCode: HttpStatus.unauthorized,
      ));
    }
    final key = '${hostPlatform.name}:${state.installId.trim()}';
    final inFlight = _initialTrialFlights[key];
    if (inFlight != null) {
      return inFlight;
    }
    final provisioning = _provisionInitialTrial(
      state: state,
      hostPlatform: hostPlatform,
      client: client,
    );
    _initialTrialFlights[key] = provisioning;
    provisioning.then<void>(
      (_) => _removeInitialTrialFlight(key, provisioning),
      onError: (_, __) => _removeInitialTrialFlight(key, provisioning),
    );
    return provisioning;
  }

  Future<_StoredBootstrapState> _provisionInitialTrial({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    final latest = await _loadState(hostPlatform);
    if (latest != null && latest.hasSession) {
      return latest;
    }
    final effectiveState =
        latest != null && latest.installId == state.installId ? latest : state;
    final response = await _requestJson(
      method: 'POST',
      path: '/api/client/session/start-trial',
      client: client,
      body: <String, Object?>{
        'install_id': effectiveState.installId,
        'device_name': await _deviceName(hostPlatform),
        'platform': hostPlatform.name,
        'os_version': _trim(Platform.operatingSystemVersion, 64),
        'app_version': pokrovClientVersion,
        'locale': _trim(Platform.localeName, 32),
        'time_zone': _trim(DateTime.now().timeZoneName, 64),
      },
      hostPlatform: hostPlatform,
    );

    final session = _readMap(response['session']);
    final provisioning = _readMap(response['provisioning']);
    final managedManifest = _readMap(provisioning['managed_manifest']);
    final pair = _sessionPairFromResponse(response);
    if (pair == null) {
      throw const BootstrapFailure(
        'POKROV не смог завершить подготовку устройства.',
      );
    }

    final accountId = _readText(
      session['account_id'] ??
          response['account_id'] ??
          response['canonical_account_id'],
    );
    final managedManifestPath = _readText(managedManifest['url']);

    final nextState = effectiveState.copyWith(
      sessionToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      accountId: accountId,
      managedManifestPath: _validatedManagedManifestPath(managedManifestPath),
      expectsSecureSessionToken: true,
    );
    await _saveState(hostPlatform, nextState);
    return await _loadState(hostPlatform) ?? nextState;
  }

  void _removeInitialTrialFlight(
    String key,
    Future<_StoredBootstrapState> provisioning,
  ) {
    if (identical(_initialTrialFlights[key], provisioning)) {
      _initialTrialFlights.remove(key);
    }
  }

  AppFirstSessionCredentials? _sessionPairFromResponse(
    Map<String, dynamic> response,
  ) {
    final session = _readMap(response['session']);
    final accessToken = _readText(
      session['access_token'] ??
          session['session_token'] ??
          response['access_token'] ??
          response['session_token'],
    );
    if (accessToken.isEmpty) {
      return null;
    }
    return AppFirstSessionCredentials(
      accessToken: accessToken,
      refreshToken: _readText(
        session['refresh_token'] ?? response['refresh_token'],
      ),
    );
  }

  Future<_StoredBootstrapState> _refreshSession({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) {
    final key = '${hostPlatform.name}:${state.installId.trim()}';
    final inFlight = _refreshFlights[key];
    if (inFlight != null) {
      return inFlight;
    }
    final refresh = _refreshSessionWithLatestCredentials(
      state: state,
      hostPlatform: hostPlatform,
      client: client,
    );
    _refreshFlights[key] = refresh;
    refresh.then<void>(
      (_) => _removeRefreshFlight(key, refresh),
      onError: (_, __) => _removeRefreshFlight(key, refresh),
    );
    return refresh;
  }

  void _removeRefreshFlight(
    String key,
    Future<_StoredBootstrapState> refresh,
  ) {
    if (identical(_refreshFlights[key], refresh)) {
      _refreshFlights.remove(key);
    }
  }

  Future<_StoredBootstrapState> _refreshSessionWithLatestCredentials({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    final refreshToken = state.refreshToken.trim();
    if (refreshToken.isEmpty) {
      throw const BootstrapFailure(
        'Сессия устройства истекла. Используйте почту или код, чтобы восстановить доступ.',
        statusCode: HttpStatus.unauthorized,
      );
    }
    final latest = await _sessionSecretStore.readSessionPair(
      hostPlatform: hostPlatform,
      installId: state.installId,
    );
    if (_credentialsHaveAdvanced(latest, state)) {
      return _stateWithCredentials(state, latest!);
    }
    try {
      final response = await _requestJson(
        method: 'POST',
        path: '/api/client/session/refresh',
        client: client,
        hostPlatform: hostPlatform,
        body: <String, Object?>{'refresh_token': refreshToken},
      );
      final pair = _sessionPairFromResponse(response);
      if (pair == null || pair.refreshToken.trim().isEmpty) {
        throw const BootstrapFailure(
          'Сессия устройства истекла. Используйте почту или код, чтобы восстановить доступ.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      final session = _readMap(response['session']);
      final nextState = state.copyWith(
        sessionToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        accountId: _readText(
          session['account_id'] ??
              response['account_id'] ??
              response['canonical_account_id'],
          fallback: state.accountId,
        ),
        expectsSecureSessionToken: true,
      );
      await _saveState(hostPlatform, nextState);
      return nextState;
    } on BootstrapFailure catch (error) {
      if (_isSessionFailure(error.statusCode)) {
        final latest = await _sessionSecretStore.readSessionPair(
          hostPlatform: hostPlatform,
          installId: state.installId,
        );
        if (_credentialsHaveAdvanced(latest, state)) {
          return _stateWithCredentials(state, latest!);
        }
        throw BootstrapFailure(
          'Сессия устройства истекла. Используйте почту или код, чтобы восстановить доступ.',
          statusCode: HttpStatus.unauthorized,
          operation: error.operation,
          code: error.code,
        );
      }
      rethrow;
    }
  }

  bool _credentialsHaveAdvanced(
    AppFirstSessionCredentials? credentials,
    _StoredBootstrapState state,
  ) {
    if (credentials == null || !credentials.hasAccessToken) {
      return false;
    }
    if (credentials.refreshToken.trim() != state.refreshToken.trim()) {
      return true;
    }
    return state.sessionToken.trim().isNotEmpty &&
        credentials.accessToken.trim() != state.sessionToken.trim();
  }

  _StoredBootstrapState _stateWithCredentials(
    _StoredBootstrapState state,
    AppFirstSessionCredentials credentials,
  ) {
    return state.copyWith(
      sessionToken: credentials.accessToken,
      refreshToken: credentials.refreshToken,
      expectsSecureSessionToken: true,
    );
  }

  Future<void> _syncRoutePolicy({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required HttpClient client,
  }) async {
    final policySelectedApps =
        routeMode == RouteMode.selectedApps ? selectedApps : const <String>[];
    await _requestJson(
      method: 'POST',
      path: '/api/client/route-policy',
      client: client,
      bearerToken: state.sessionToken,
      hostPlatform: hostPlatform,
      body: <String, Object?>{
        'route_mode': _routeModeWireValue(routeMode),
        'selected_apps': policySelectedApps,
        'requires_elevated_privileges': hostPlatform.supportsSelectedAppsMode &&
            routeMode == RouteMode.selectedApps,
      },
    );
  }

  Future<_ManagedManifestEnvelope> _fetchManagedManifest({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required String preferredNodeCode,
    required String preferredVariantId,
    required HttpClient client,
    String tcpFallbackFromRevision = '',
  }) async {
    final path = _validatedManagedManifestPath(state.managedManifestPath);
    final normalizedPreferredNode = preferredNodeCode.trim().toLowerCase();
    var requestPath = normalizedPreferredNode.isEmpty
        ? path
        : '$path${path.contains('?') ? '&' : '?'}selected_node_code=${Uri.encodeQueryComponent(normalizedPreferredNode)}';
    if (tcpFallbackFromRevision.isNotEmpty) {
      requestPath +=
          '${requestPath.contains('?') ? '&' : '?'}fallback_from_revision=${Uri.encodeQueryComponent(tcpFallbackFromRevision)}';
    }
    final response = await _requestJson(
      method: 'GET',
      path: requestPath,
      client: client,
      bearerToken: state.sessionToken,
      hostPlatform: hostPlatform,
    );
    final verifiedAt = DateTime.now().toUtc();

    if (tcpFallbackFromRevision.isNotEmpty &&
        (_readText(response['transport_profile']) !=
                'legacy_reality_fallback' ||
            _readText(response['profile_revision']) !=
                '$tcpFallbackFromRevision:fallback:legacy_reality_fallback')) {
      throw const BootstrapFailure(
        'Сервер не подтвердил резервное подключение. Повторите попытку позже.',
      );
    }
    final configFormat = _readText(response['config_format']);
    if (configFormat != 'singbox-json') {
      throw BootstrapFailure(
        'This device received connection details it cannot use yet.',
      );
    }

    final configPayload = response['config_payload'];
    if (configPayload == null) {
      throw const BootstrapFailure(
        'POKROV не смог завершить настройку: данных подключения недостаточно.',
      );
    }
    final provisioning = _readMap(response['provisioning']);
    final provisioningReady = _readBool(provisioning['sync_ok']) ||
        _readText(provisioning['status']) == 'ready';
    if (!provisioningReady) {
      throw const BootstrapFailure(
        'POKROV еще завершает первый запуск. Попробуйте через минуту.',
        operationalCode: 'API-011',
      );
    }
    final supportContext = _readMap(response['support_context']);
    final warpPolicy = WarpRuntimePolicy.tryParse(
      response['warp_policy'] ??
          _readMap(response['client_policy'])['warp_policy'],
    );
    final smartConnect = SmartConnectProfile.tryParse(
      response['smart_connect'],
    );
    final isOwnedTransportLab = _ownedTransportLabProfiles.contains(
      _readText(response['transport_profile']).trim().toLowerCase(),
    );
    final effectiveSmartConnect = isOwnedTransportLab ? null : smartConnect;
    final effectivePreferredNode =
        isOwnedTransportLab ? '' : normalizedPreferredNode;
    final clientRuleSetCatalog = await _ensureAllExceptRuRuleSetCatalog(
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      client: client,
    );

    final fallbackOrder = response['fallback_order'];
    final tcpFallbackRevision =
        isOwnedTransportLab &&
            fallbackOrder is List &&
            fallbackOrder.contains('legacy_reality_fallback')
        ? _readText(response['profile_revision'])
        : '';
    final payload = ManagedProfilePayload(
      cacheEntryId: ManagedProfileCache.newEntryId(),
      tcpFallbackFromRevision: tcpFallbackRevision,
      source: RuntimeProfileSource(
        revision: _readText(response['profile_revision']),
        origin: RuntimeProfileSourceOrigin.managedManifest,
      ),
      profileName: _profileName(
        hostPlatform: hostPlatform,
        profileRevision: _readText(response['profile_revision']),
      ),
      configPayload: await _materializeRuntimeConfig(
        rawConfigPayload:
            configPayload is String ? configPayload : jsonEncode(configPayload),
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        preferredNodeCode: effectivePreferredNode,
        preferredVariantId:
            effectivePreferredNode.isEmpty ? 'direct' : preferredVariantId,
        smartConnect: effectiveSmartConnect,
        supportContext: supportContext,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
      materializedForRuntime: true,
      routeMode: routeMode,
      smartConnect: effectiveSmartConnect,
      resolvedNodeCode: effectivePreferredNode,
      warpPolicy: warpPolicy,
      freeProfileAccess: FreeProfileAccess.tryParse(
        access: response['access'],
        freeCaps: response['free_caps'],
      ),
    );

    return _ManagedManifestEnvelope(
      payload: payload,
      response: response,
      verifiedAt: verifiedAt,
      profileRevision: _readText(response['profile_revision']),
      managedManifestPath: path,
    );
  }

  String _validatedManagedManifestPath(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) {
      return _defaultManagedManifestPath;
    }
    final uri = Uri.tryParse(candidate);
    final safeQueryValue = RegExp(r'^[a-zA-Z0-9._~-]{0,96}$');
    final hasSafeQuery = uri != null &&
        uri.queryParametersAll.length <= 8 &&
        uri.queryParametersAll.entries.every(
          (entry) =>
              RegExp(r'^[a-zA-Z0-9_]{1,32}$').hasMatch(entry.key) &&
              entry.value.length <= 4 &&
              entry.value.every(safeQueryValue.hasMatch),
        );
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.host.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != _defaultManagedManifestPath ||
        !hasSafeQuery) {
      throw const BootstrapFailure(
        'POKROV получил недопустимый путь профиля. Обновите настройки и попробуйте ещё раз.',
      );
    }
    return uri.toString();
  }

  Future<String> _materializeRuntimeConfig({
    required String rawConfigPayload,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required String preferredNodeCode,
    required String preferredVariantId,
    required SmartConnectProfile? smartConnect,
    required Map<String, dynamic> supportContext,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) async {
    if ((routeMode == RouteMode.selectedApps ||
            routeMode == RouteMode.excludedApps) &&
        selectedApps.isEmpty) {
      throw const BootstrapFailure(
        'Выберите хотя бы одно приложение в разделе «Правила».',
      );
    }
    final decoded = jsonDecode(rawConfigPayload);
    if (decoded is! Map) {
      throw const BootstrapFailure(
        'The connection details for this device were incomplete.',
      );
    }

    final baseConfig = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    _applyRealityTlsFragmentPolicy(
      baseConfig: baseConfig,
      supportContext: supportContext,
    );
    final preferredNode = _verifiedPreferredSmartConnectNode(
      preferredNodeCode: preferredNodeCode,
      smartConnect: smartConnect,
    );
    final normalizedPreferredVariant = preferredNode == null
        ? 'direct'
        : normalizeClientLocationVariantId(preferredVariantId);
    if (normalizedPreferredVariant == null) {
      throw const BootstrapFailure('Выбранный вариант подключения недоступен.');
    }
    final ruBridgeEndpoints = _readSafeRuBridgeEndpoints(baseConfig);
    if (hostPlatform != HostPlatform.android &&
        _looksRuntimeReady(baseConfig)) {
      final sanitized = _sanitizeRuntimeReadyConfig(
        baseConfig: baseConfig,
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      _promotePreferredSmartConnectOutbound(
        config: sanitized,
        preferredNode: preferredNode,
        preferredVariantId: normalizedPreferredVariant,
        ruBridgeEndpoints: ruBridgeEndpoints,
        allowDirectInsertion: true,
      );
      return const JsonEncoder.withIndent('  ').convert(sanitized);
    }
    final runtimeConfig = _buildRuntimeConfig(
      baseConfig: baseConfig,
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      selectedApps: selectedApps,
      supportContext: supportContext,
      clientRuleSetCatalog: clientRuleSetCatalog,
    );
    _promotePreferredSmartConnectOutbound(
      config: runtimeConfig,
      preferredNode: preferredNode,
      preferredVariantId: normalizedPreferredVariant,
      ruBridgeEndpoints: ruBridgeEndpoints,
      allowDirectInsertion: true,
    );
    return const JsonEncoder.withIndent('  ').convert(runtimeConfig);
  }

  SmartConnectNode? _verifiedPreferredSmartConnectNode({
    required String preferredNodeCode,
    required SmartConnectProfile? smartConnect,
  }) {
    final code = preferredNodeCode.trim().toLowerCase();
    if (code.isEmpty) {
      return null;
    }
    if (smartConnect == null || !smartConnect.eligible) {
      throw const BootstrapFailure('Выбранная локация недоступна.');
    }
    final matches = smartConnect.shortlist
        .where((node) => node.code.trim().toLowerCase() == code)
        .toList(growable: false);
    if (matches.length != 1) {
      throw const BootstrapFailure('Выбранная локация недоступна.');
    }
    return matches.single;
  }

  void _promotePreferredSmartConnectOutbound({
    required Map<String, dynamic> config,
    required SmartConnectNode? preferredNode,
    String preferredVariantId = 'direct',
    List<_SafeRuBridgeEndpoint> ruBridgeEndpoints =
        const <_SafeRuBridgeEndpoint>[],
    bool allowDirectInsertion = false,
  }) {
    if (preferredNode == null) {
      return;
    }
    final outbounds = _readListOfMaps(config['outbounds'])
        .map((outbound) => Map<String, dynamic>.from(outbound))
        .toList(growable: true);
    final expectedTags = <String>{
      preferredNode.outboundTag.trim(),
      preferredNode.code.trim(),
      _legacySmartConnectOutboundTag(preferredNode),
    }..removeWhere((tag) => tag.isEmpty);
    final host = preferredNode.probeHost.trim().toLowerCase();
    final port = preferredNode.probePort;
    var matchingProxyOutbounds = outbounds.where((outbound) {
      return _isProxyTransportOutbound(outbound) &&
          _readText(outbound['detour']).isEmpty &&
          expectedTags.contains(_readText(outbound['tag']).trim());
    }).toList(growable: false);
    if (matchingProxyOutbounds.isEmpty && host.isNotEmpty && port > 0) {
      matchingProxyOutbounds = outbounds.where((outbound) {
        return _isProxyTransportOutbound(outbound) &&
            _readText(outbound['detour']).isEmpty &&
            _readText(outbound['server']).trim().toLowerCase() == host &&
            _readInt(outbound['server_port']) == port &&
            _readText(outbound['tag']).isNotEmpty;
      }).toList(growable: false);
    }
    if (matchingProxyOutbounds.length != 1) {
      throw const BootstrapFailure('Выбранная локация недоступна.');
    }
    final route = _readMap(config['route']);
    final finalTag = _readText(route['final']);
    final finalOutbounds = outbounds
        .where((outbound) => _readText(outbound['tag']) == finalTag)
        .toList(growable: false);
    if (finalTag.isEmpty ||
        finalOutbounds.length != 1 ||
        _readText(finalOutbounds.single['type']).toLowerCase() != 'selector') {
      throw const BootstrapFailure('Выбранная локация недоступна.');
    }
    final selector = finalOutbounds.single;
    final baseSelectedTag = _readText(matchingProxyOutbounds.single['tag']);
    final finalSelectorTargets = _readTagList(selector['outbounds']);
    final normalizedVariant =
        normalizeClientLocationVariantId(preferredVariantId);
    if (normalizedVariant == null) {
      throw const BootstrapFailure('Выбранный вариант подключения недоступен.');
    }
    final nestedSelectors = outbounds.where((outbound) {
      return _readText(outbound['tag']) != finalTag &&
          _readText(outbound['type']).toLowerCase() == 'selector' &&
          _readTagList(outbound['outbounds']).contains(baseSelectedTag);
    }).toList(growable: false);
    if (nestedSelectors.length > 1) {
      throw const BootstrapFailure('Выбранная локация недоступна.');
    }
    final usesNestedSelector = nestedSelectors.length == 1 &&
        finalSelectorTargets.contains(_readText(nestedSelectors.single['tag']));
    final targetSelector =
        usesNestedSelector ? nestedSelectors.single : selector;
    final targetSelectorTag = _readText(targetSelector['tag']);
    final targetSelectorTargets = _readTagList(targetSelector['outbounds']);
    final baseLocationTag = baseSelectedTag.endsWith(' · Обычный')
        ? baseSelectedTag.substring(
            0,
            baseSelectedTag.length - ' · Обычный'.length,
          )
        : baseSelectedTag;
    var selectedTag = baseSelectedTag;
    if (normalizedVariant != 'direct') {
      final endpointMatches = ruBridgeEndpoints
          .where((endpoint) => endpoint.id == normalizedVariant)
          .toList(growable: false);
      if (endpointMatches.length != 1) {
        throw const BootstrapFailure(
          'Выбранный вариант подключения недоступен.',
        );
      }
      final expectedBridgeTags = <String>{
        '$baseLocationTag · ${endpointMatches.single.label}',
        '$baseSelectedTag · ${endpointMatches.single.label}',
      };
      final bridgeMatches = outbounds.where((outbound) {
        return _isProxyTransportOutbound(outbound) &&
            expectedBridgeTags.contains(_readText(outbound['tag'])) &&
            targetSelectorTargets.contains(_readText(outbound['tag'])) &&
            _readText(outbound['detour']).isNotEmpty;
      }).toList(growable: false);
      if (bridgeMatches.length != 1) {
        throw const BootstrapFailure(
          'Выбранный вариант подключения недоступен.',
        );
      }
      final bridgeDetour = _readText(bridgeMatches.single['detour']);
      final detourMatches = outbounds.where((outbound) {
        return _isProxyTransportOutbound(outbound) &&
            _readText(outbound['tag']) == bridgeDetour;
      }).toList(growable: false);
      if (detourMatches.length != 1) {
        throw const BootstrapFailure(
          'Выбранный вариант подключения недоступен.',
        );
      }
      selectedTag = _readText(bridgeMatches.single['tag']);
    }
    if (!targetSelectorTargets.contains(selectedTag) &&
        !(allowDirectInsertion && normalizedVariant == 'direct')) {
      throw const BootstrapFailure('Выбранный вариант подключения недоступен.');
    }
    targetSelector['outbounds'] = <String>[
      selectedTag,
      ...targetSelectorTargets.where((tag) => tag != selectedTag),
    ];
    targetSelector['default'] = selectedTag;
    final finalSelectedTag =
        usesNestedSelector ? targetSelectorTag : selectedTag;
    if (!finalSelectorTargets.contains(finalSelectedTag) &&
        !(!usesNestedSelector &&
            allowDirectInsertion &&
            normalizedVariant == 'direct')) {
      throw const BootstrapFailure('Выбранный вариант подключения недоступен.');
    }
    selector['outbounds'] = <String>[
      finalSelectedTag,
      ...finalSelectorTargets.where((tag) => tag != finalSelectedTag),
    ];
    selector['default'] = finalSelectedTag;
    _installRuntimeVariantProbe(
      config: config,
      outbounds: outbounds,
      baseSelectedTag: baseSelectedTag,
      baseLocationTag: baseLocationTag,
      ruBridgeEndpoints: ruBridgeEndpoints,
      targetSelectorTargets: targetSelectorTargets,
    );
    config['outbounds'] = outbounds;
  }

  void _installRuntimeVariantProbe({
    required Map<String, dynamic> config,
    required List<Map<String, dynamic>> outbounds,
    required String baseSelectedTag,
    required String baseLocationTag,
    required List<_SafeRuBridgeEndpoint> ruBridgeEndpoints,
    required List<String> targetSelectorTargets,
  }) {
    final mappings = <Map<String, String>>[
      <String, String>{'id': 'direct', 'outbound_tag': baseSelectedTag},
    ];
    for (final endpoint in ruBridgeEndpoints) {
      final expectedTags = <String>{
        '$baseLocationTag · ${endpoint.label}',
        '$baseSelectedTag · ${endpoint.label}',
      };
      final matches = outbounds.where((outbound) {
        final tag = _readText(outbound['tag']);
        return _isProxyTransportOutbound(outbound) &&
            expectedTags.contains(tag) &&
            targetSelectorTargets.contains(tag) &&
            _readText(outbound['detour']).isNotEmpty;
      }).toList(growable: false);
      if (matches.length == 1) {
        mappings.add(<String, String>{
          'id': endpoint.id,
          'outbound_tag': _readText(matches.single['tag']),
        });
      }
    }
    final uniqueTags = mappings
        .map((mapping) => mapping['outbound_tag'] ?? '')
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (uniqueTags.length != mappings.length || uniqueTags.isEmpty) {
      return;
    }
    final existingTags = outbounds
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    var groupTag = 'pokrov-variant-probe';
    var suffix = 2;
    while (existingTags.contains(groupTag)) {
      groupTag = 'pokrov-variant-probe-$suffix';
      suffix += 1;
    }
    outbounds.add(<String, dynamic>{
      'type': 'urltest',
      'tag': groupTag,
      'outbounds': uniqueTags.toList(growable: false),
      'url': _androidCoreEgressProbeUrl,
      'interval': '10m0s',
      'tolerance': 1,
      'interrupt_exist_connections': false,
    });
    final meta = Map<String, dynamic>.from(_readMap(config['_meta']));
    meta['runtime_variant_probe'] = <String, dynamic>{
      'group_tag': groupTag,
      'mappings': mappings,
    };
    config['_meta'] = meta;
  }

  List<_SafeRuBridgeEndpoint> _readSafeRuBridgeEndpoints(
    Map<String, dynamic> config,
  ) {
    final ruBridge = _readMap(_readMap(config['_meta'])['ru_bridge']);
    if (!_readBool(ruBridge['enabled'])) {
      return const <_SafeRuBridgeEndpoint>[];
    }
    final endpoints = <_SafeRuBridgeEndpoint>[];
    for (final item in _readListOfMaps(ruBridge['endpoints'])) {
      final id = normalizeClientLocationVariantId(_readText(item['id']));
      final label = _clientLocationVariantText(
        item['label'],
        maxLength: 48,
      );
      if (id == null || id == 'direct' || label.isEmpty) {
        continue;
      }
      endpoints.add(_SafeRuBridgeEndpoint(id: id, label: label));
    }
    return List<_SafeRuBridgeEndpoint>.unmodifiable(endpoints);
  }

  String _legacySmartConnectOutboundTag(SmartConnectNode node) {
    final rawCode = node.code.trim().toLowerCase();
    if (rawCode.contains('free')) {
      return '🇳🇱 NL Free';
    }
    final base = rawCode.split(RegExp(r'[_.-]')).first;
    const flags = <String, String>{
      'pl': '🇵🇱',
      'it': '🇮🇹',
      'us': '🇺🇸',
      'nl': '🇳🇱',
      'brain': '🇩🇪',
      'de': '🇩🇪',
      'ru': '🇷🇺',
    };
    const names = <String, String>{
      'pl': 'Польша',
      'it': 'Италия',
      'us': 'США',
      'nl': 'Нидерланды',
      'brain': 'Германия',
      'de': 'Германия',
      'ru': 'Россия',
    };
    final fallbackName = node.country.trim();
    final name = names[base] ??
        (fallbackName.isNotEmpty
            ? fallbackName
            : base.isNotEmpty
                ? base.toUpperCase()
                : rawCode);
    var suffix = rawCode.startsWith(base)
        ? rawCode.substring(base.length).replaceFirst(RegExp(r'^[._ -]+'), '')
        : '';
    suffix = suffix
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => int.tryParse(part) != null
              ? part
              : '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
    return <String>[
      flags[base] ?? '🏳️',
      name,
      if (suffix.isNotEmpty) suffix,
    ].join(' ');
  }

  _ManagedManifestEnvelope _promoteSelectedSmartConnectNode({
    required _ManagedManifestEnvelope manifest,
    required String selectedNodeCode,
  }) {
    final preferredNode = _verifiedPreferredSmartConnectNode(
      preferredNodeCode: selectedNodeCode,
      smartConnect: manifest.payload.smartConnect,
    );
    final decoded = jsonDecode(manifest.payload.configPayload);
    if (decoded is! Map) {
      throw const BootstrapFailure(
        'The connection details for this device were incomplete.',
      );
    }
    final config = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    _promotePreferredSmartConnectOutbound(
      config: config,
      preferredNode: preferredNode,
      allowDirectInsertion: true,
    );
    return _ManagedManifestEnvelope(
      payload: manifest.payload.copyWith(
        configPayload: const JsonEncoder.withIndent('  ').convert(config),
        resolvedNodeCode: selectedNodeCode.trim().toLowerCase(),
      ),
      profileRevision: manifest.profileRevision,
      managedManifestPath: manifest.managedManifestPath,
      response: manifest.response,
      verifiedAt: manifest.verifiedAt,
    );
  }

  Future<_SmartConnectResolution> _resolveSmartConnectNode({
    required SmartConnectProfile? smartConnect,
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required DateTime deadline,
    required Set<String> excludedNodeCodes,
  }) async {
    final probe = smartConnectLatencyProbe ?? _probeSmartConnectNode;
    if (smartConnect == null ||
        !smartConnect.eligible ||
        smartConnect.shortlist.isEmpty ||
        !state.hasSession) {
      return const _SmartConnectResolution.empty();
    }

    final allowedNodes = smartConnect.shortlist
        .where(
          (node) => !excludedNodeCodes.contains(
            node.code.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);
    if (allowedNodes.isEmpty) {
      return const _SmartConnectResolution.empty();
    }

    final samples = await _collectSmartConnectLatencySamples(
      smartConnect: smartConnect,
      probe: probe,
      deadline: deadline,
      excludedNodeCodes: excludedNodeCodes,
    );
    final selection = samples.isEmpty
        ? null
        : _selectSmartConnectNode(
            smartConnect: smartConnect,
            samples: samples,
          );
    final samplePayload = samples
        .map(
          (sample) => <String, Object?>{
            'node_code': sample.nodeCode,
            'rtt_ms': sample.rttMs,
          },
        )
        .toList(growable: false);
    var selectedNodeCode = '';
    final selectionRequestBudget = _smartConnectRemaining(deadline);
    if (selectionRequestBudget > Duration.zero) {
      final selectionClient = _createHttpClient(hostPlatform);
      try {
        final response = await _requestJson(
          method: 'POST',
          path: '/api/client/nodes/select',
          client: selectionClient,
          bearerToken: state.sessionToken,
          hostPlatform: hostPlatform,
          body: <String, Object?>{
            'mode': 'auto',
            'profile_revision': smartConnect.profileRevision,
            'transport_profile': smartConnect.transportProfile,
            'selected_node_code': selection?.selectedNodeCode,
            'previous_node_code': (selection?.previousNodeCode ?? '').isEmpty
                ? null
                : selection?.previousNodeCode,
            'samples': samplePayload,
            if (excludedNodeCodes.isNotEmpty)
              'excluded_node_codes': excludedNodeCodes.toList(growable: false),
          },
        ).timeout(selectionRequestBudget);
        final candidate =
            _readText(response['selected_node_code']).toLowerCase();
        final allowedCodes = <String>{
          for (final node in allowedNodes) node.code.trim().toLowerCase(),
        };
        if (allowedCodes.contains(candidate)) {
          selectedNodeCode = candidate;
        }
      } on Object {
        // The exact profile refresh below can still apply the bounded local
        // choice; a slow advisory selector must not discard that identity.
      } finally {
        selectionClient.close(force: true);
      }
    }
    final locallySelectedCode =
        selection?.selectedNodeCode.trim().toLowerCase() ?? '';
    if (selectedNodeCode.isEmpty &&
        locallySelectedCode.isNotEmpty &&
        !excludedNodeCodes.contains(locallySelectedCode)) {
      selectedNodeCode = locallySelectedCode;
    }
    if (selectedNodeCode.isEmpty) {
      selectedNodeCode = allowedNodes.first.code.trim().toLowerCase();
    }
    if (_smartConnectDeadlineExpired(deadline) || samples.isEmpty) {
      return _SmartConnectResolution(
        selectedNodeCode: selectedNodeCode,
        selection: selection,
        samplePayload: samplePayload,
      );
    }
    return _SmartConnectResolution(
      selectedNodeCode: selectedNodeCode,
      selection: selection,
      samplePayload: samplePayload,
    );
  }

  Future<void> _uploadSmartConnectLatencySamples({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required SmartConnectProfile smartConnect,
    required String selectedNodeCode,
    required _SmartConnectSelection? selection,
    required List<Map<String, Object?>> samplePayload,
  }) async {
    final client = _createHttpClient(hostPlatform);
    try {
      await _requestJson(
        method: 'POST',
        path: '/api/client/nodes/latency-samples',
        client: client,
        bearerToken: state.sessionToken,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'profile_revision': smartConnect.profileRevision,
          'transport_profile': smartConnect.transportProfile,
          'selected_node_code': selectedNodeCode.isEmpty
              ? selection?.selectedNodeCode
              : selectedNodeCode,
          'previous_node_code': (selection?.previousNodeCode ?? '').isEmpty
              ? null
              : selection?.previousNodeCode,
          'stickiness_applied': selection?.stickinessApplied ?? false,
          'samples': samplePayload,
        },
      );
    } on Object {
      // RTT upload is telemetry only. The selected manifest is authoritative.
    } finally {
      client.close(force: true);
    }
  }

  Future<List<_SmartConnectLatencySample>> _collectSmartConnectLatencySamples({
    required SmartConnectProfile smartConnect,
    required SmartConnectLatencyProbe probe,
    required DateTime deadline,
    Set<String> excludedNodeCodes = const <String>{},
  }) async {
    final nodes = smartConnect.shortlist
        .take(_smartConnectTelemetryMaxNodes)
        .where((node) => node.code.trim().isNotEmpty)
        .where(
          (node) => !excludedNodeCodes.contains(
            node.code.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);
    final samples = List<_SmartConnectLatencySample?>.filled(
      nodes.length,
      null,
    );
    var nextIndex = 0;
    final workerCount = min(
      max(1, smartConnectProbeConcurrency),
      nodes.length,
    );

    Future<void> collectOne() async {
      while (
          nextIndex < nodes.length && !_smartConnectDeadlineExpired(deadline)) {
        final index = nextIndex++;
        final node = nodes[index];
        final remaining = _smartConnectRemaining(deadline);
        if (remaining <= Duration.zero) {
          return;
        }
        final probeBudget = _shorterDuration(
          smartConnectProbeTimeout,
          remaining,
        );
        if (_activeSmartConnectProbes >= max(1, smartConnectProbeConcurrency)) {
          return;
        }
        _activeSmartConnectProbes += 1;
        // Future.timeout only ends this wait. Keep its slot occupied until the
        // underlying probe settles, including across later profile resolutions.
        final pendingProbe = Future<int?>.sync(() => probe(node)).whenComplete(
          () => _activeSmartConnectProbes -= 1,
        );
        try {
          final rttMs = await pendingProbe.timeout(
            probeBudget,
          );
          if (rttMs == null || rttMs < 1 || rttMs > 60000) {
            continue;
          }
          samples[index] = _SmartConnectLatencySample(
            nodeCode: node.code.trim().toLowerCase(),
            rttMs: rttMs,
            cpuPenalty: node.rankHint.cpuPenalty,
            backendPenalty: node.rankHint.backendPenalty,
            rank: node.rank,
          );
        } on TimeoutException {
          if (probeBudget == remaining) {
            return;
          }
        } on Object {
          // One unavailable candidate must not hold up the profile.
        }
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => collectOne()),
    );
    return samples.whereType<_SmartConnectLatencySample>().toList(
          growable: false,
        );
  }

  bool _smartConnectDeadlineExpired(DateTime deadline) =>
      !DateTime.now().isBefore(deadline);

  Duration _smartConnectRemaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration _shorterDuration(Duration left, Duration right) =>
      left <= right ? left : right;

  Future<int?> _probeSmartConnectNode(SmartConnectNode node) async {
    final host = node.probeHost.trim();
    final port = node.probePort;
    if (host.isEmpty || port <= 0 || port > 65535) {
      return null;
    }

    Socket? socket;
    final stopwatch = Stopwatch()..start();
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: smartConnectProbeTimeout,
      );
      stopwatch.stop();
      return max(1, min(60000, stopwatch.elapsedMilliseconds));
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } finally {
      stopwatch.stop();
      socket?.destroy();
    }
  }

  _SmartConnectSelection _selectSmartConnectNode({
    required SmartConnectProfile smartConnect,
    required List<_SmartConnectLatencySample> samples,
  }) {
    final ordered = List<_SmartConnectLatencySample>.from(samples)
      ..sort((left, right) {
        final scoreDelta = left.effectiveScore.compareTo(right.effectiveScore);
        if (scoreDelta != 0) {
          return scoreDelta;
        }
        return left.rank.compareTo(right.rank);
      });
    final best = ordered.first;
    final previousNodeCode =
        smartConnect.stickiness.preferredNodeCode.trim().toLowerCase();
    final thresholdPercent = smartConnect.stickiness.thresholdPercent > 0
        ? smartConnect.stickiness.thresholdPercent
        : 15;
    _SmartConnectLatencySample? stickySample;
    for (final sample in ordered) {
      if (sample.nodeCode == previousNodeCode) {
        stickySample = sample;
        break;
      }
    }
    if (stickySample != null && stickySample.nodeCode != best.nodeCode) {
      final stickyScore = max(stickySample.effectiveScore, 1);
      final improvementPercent =
          ((stickyScore - best.effectiveScore) / stickyScore) * 100;
      if (improvementPercent < thresholdPercent) {
        return _SmartConnectSelection(
          selectedNodeCode: stickySample.nodeCode,
          previousNodeCode: previousNodeCode,
          stickinessApplied: true,
        );
      }
    }
    return _SmartConnectSelection(
      selectedNodeCode: best.nodeCode,
      previousNodeCode: previousNodeCode,
      stickinessApplied: false,
    );
  }

  bool _looksRuntimeReady(Map<String, dynamic> config) {
    final inbounds = config['inbounds'];
    if (inbounds is! List || inbounds.isEmpty) {
      return false;
    }
    final route = config['route'];
    return route is Map && route.isNotEmpty;
  }

  Map<String, dynamic> _sanitizeRuntimeReadyConfig({
    required Map<String, dynamic> baseConfig,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final sanitized = Map<String, dynamic>.from(baseConfig)..remove('_meta');
    if (hostPlatform == HostPlatform.windows) {
      final outbounds = _readListOfMaps(sanitized['outbounds']);
      final directTag = _ensureAuxiliaryOutbound(
        outbounds,
        outbounds.map((outbound) => _readText(outbound['tag'])).toSet(),
        preferredTag: 'direct',
        type: 'direct',
      );
      final transportTags = <String>[
        ...outbounds
            .where(_isProxyTransportOutbound)
            .map((outbound) => _readText(outbound['tag'])),
        ..._readListOfMaps(sanitized['endpoints'])
            .where((endpoint) =>
                _readText(endpoint['type']).toLowerCase() == 'awg')
            .map((endpoint) => _readText(endpoint['tag'])),
      ].where((tag) => tag.isNotEmpty).toList(growable: false);
      _normalizeVpnOutboundChains(
        outbounds: outbounds,
        proxyOutboundTags: transportTags,
        directTag: directTag,
      );
      sanitized['outbounds'] = outbounds;
      final route = Map<String, dynamic>.from(_readMap(sanitized['route']));
      final safeTags = _computeVpnSafeOutboundTags(
          outbounds: outbounds, proxyOutboundTags: transportTags);
      var vpnTag = _readText(route['final']);
      if (!safeTags.contains(vpnTag)) {
        vpnTag = outbounds
                .map((outbound) => _readText(outbound['tag']))
                .where(safeTags.contains)
                .firstOrNull ??
            '';
      }
      if (vpnTag.isEmpty) {
        throw const BootstrapFailure('Не удалось подготовить параметры VPN.');
      }
      // Replace prior per-process routing; the current mode and selection own
      // it. Non-routing actions and the rest of the materialized profile stay.
      route['rules'] = _readListOfMaps(route['rules'])
          .where((rule) => !((rule.containsKey('process_name') ||
                  rule.containsKey('process_path') ||
                  rule.containsKey('process_path_regex')) &&
              _readText(rule['outbound']).isNotEmpty))
          .toList();
      sanitized['route'] = _buildRouteBlock(
        baseRoute: route,
        directTag: directTag,
        dnsOutboundTag: null,
        finalOutboundTag: vpnTag,
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      sanitized['dns'] = _buildWindowsDnsBlock(
        baseDns: sanitized['dns'],
        outbounds: outbounds,
        finalOutboundTag: vpnTag,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      return sanitized;
    }
    if (hostPlatform != HostPlatform.android) {
      if (routeMode == RouteMode.allExceptRu && !clientRuleSetCatalog.isEmpty) {
        _injectAllExceptRuRuleSetCatalog(
          config: sanitized,
          hostPlatform: hostPlatform,
          clientRuleSetCatalog: clientRuleSetCatalog,
        );
      }
      return sanitized;
    }

    final route = _readMap(sanitized['route']);
    if (route.isNotEmpty) {
      final routeCopy = Map<String, dynamic>.from(route)
        ..['auto_detect_interface'] = false
        ..remove('override_android_vpn');
      sanitized['route'] = routeCopy;
    }
    final inbounds = _readListOfMaps(sanitized['inbounds'])
        .map((inbound) => Map<String, dynamic>.from(inbound))
        .toList(growable: true);
    for (final inbound in inbounds) {
      if (_readText(inbound['type']) == 'tun') {
        if (routeMode == RouteMode.selectedApps) {
          inbound['include_package'] = selectedApps;
          inbound.remove('exclude_package');
        } else {
          inbound.remove('include_package');
          inbound['exclude_package'] = <String>[
            _androidShellPackageName,
            if (routeMode == RouteMode.excludedApps) ...selectedApps,
            ..._readTagList(inbound['exclude_package'])
                .where((value) => value != _androidShellPackageName),
          ];
        }
      }
    }
    if (inbounds.isNotEmpty) {
      sanitized['inbounds'] = inbounds;
    }
    return sanitized;
  }

  Map<String, dynamic> _buildRuntimeConfig({
    required Map<String, dynamic> baseConfig,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required Map<String, dynamic> supportContext,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final outbounds = _readListOfMaps(baseConfig['outbounds']);
    final endpoints = _readListOfMaps(baseConfig['endpoints']);
    final awgEndpointTags = endpoints
        .where(
          (endpoint) => _readText(endpoint['type']).toLowerCase() == 'awg',
        )
        .map((endpoint) => _readText(endpoint['tag']))
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    if (outbounds.isEmpty && awgEndpointTags.isEmpty) {
      throw const BootstrapFailure(
        'The connection details for this device were incomplete.',
      );
    }
    if (hostPlatform == HostPlatform.android) {
      _useOwnedAndroidEgressProbe(outbounds);
    }

    final existingTags = outbounds
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final proxyOutboundTags = outbounds
        .where(_isProxyTransportOutbound)
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final transportPathTags = <String>{
      ...proxyOutboundTags,
      ...awgEndpointTags,
    }.toList(growable: false);
    final selectorTag = _findOutboundTag(outbounds, 'selector');
    final urlTestTag = _findOutboundTag(outbounds, 'urltest');
    if (proxyOutboundTags.isEmpty &&
        awgEndpointTags.isEmpty &&
        selectorTag == null &&
        urlTestTag == null) {
      throw const BootstrapFailure(
        'The connection details for this device did not include a working connection path.',
      );
    }

    final directTag = _ensureAuxiliaryOutbound(
      outbounds,
      existingTags,
      preferredTag: 'direct',
      type: 'direct',
    );
    _ensureAuxiliaryOutbound(
      outbounds,
      existingTags,
      preferredTag: 'block',
      type: 'block',
    );
    final legacyDnsOutboundTags = hostPlatform == HostPlatform.android ||
            hostPlatform == HostPlatform.windows
        ? _removeLegacyDnsOutbounds(outbounds)
        : const <String>{};
    existingTags.removeAll(legacyDnsOutboundTags);
    final dnsOutboundTag = hostPlatform == HostPlatform.android ||
            hostPlatform == HostPlatform.windows
        ? null
        : _ensureAuxiliaryOutbound(
            outbounds,
            existingTags,
            preferredTag: 'dns-out',
            type: 'dns',
          );

    final baseRoute = _readMap(baseConfig['route']);
    var finalOutboundTag = _readText(baseRoute['final']);
    if ((!existingTags.contains(finalOutboundTag) &&
            !awgEndpointTags.contains(finalOutboundTag)) ||
        _isAuxiliaryTag(finalOutboundTag)) {
      finalOutboundTag = '';
    }

    if (hostPlatform == HostPlatform.android ||
        hostPlatform == HostPlatform.windows) {
      _normalizeVpnOutboundChains(
        outbounds: outbounds,
        proxyOutboundTags: transportPathTags,
        directTag: directTag,
      );
    }

    if (finalOutboundTag.isEmpty && selectorTag != null) {
      finalOutboundTag = selectorTag;
    }
    if (finalOutboundTag.isEmpty && urlTestTag != null) {
      finalOutboundTag = urlTestTag;
    }
    if (finalOutboundTag.isEmpty && proxyOutboundTags.isNotEmpty) {
      finalOutboundTag = _synthesizeSelectorOutbounds(
        outbounds: outbounds,
        existingTags: existingTags,
        proxyOutboundTags: proxyOutboundTags,
      );
    }
    if (finalOutboundTag.isEmpty && awgEndpointTags.length == 1) {
      finalOutboundTag = awgEndpointTags.single;
    }
    if (finalOutboundTag.isEmpty) {
      throw const BootstrapFailure(
        'The connection details for this device did not include a working connection path.',
      );
    }

    if (hostPlatform == HostPlatform.android) {
      finalOutboundTag = _normalizeAndroidFinalOutboundTag(
        outbounds: outbounds,
        proxyOutboundTags: transportPathTags,
        routeMode: routeMode,
        directTag: directTag,
        currentFinalOutboundTag: finalOutboundTag,
      );
      final runtimeConfig = <String, dynamic>{
        'log': _buildLogBlock(baseConfig['log']),
        'dns': _buildAndroidDnsBlock(
          baseDns: baseConfig['dns'],
          outbounds: outbounds,
          directTag: directTag,
          finalOutboundTag: finalOutboundTag,
          routeMode: routeMode,
          clientRuleSetCatalog: clientRuleSetCatalog,
        ),
        'inbounds': _buildInbounds(
          hostPlatform: hostPlatform,
          routeMode: routeMode,
          selectedApps: selectedApps,
          supportContext: supportContext,
        ),
        'outbounds': outbounds,
        'route': _buildAndroidRouteBlock(
          baseRoute: baseConfig['route'],
          directTag: directTag,
          legacyDnsOutboundTags: legacyDnsOutboundTags,
          finalOutboundTag: finalOutboundTag,
          routeMode: routeMode,
          clientRuleSetCatalog: clientRuleSetCatalog,
        ),
      };
      final experimental = _readMap(baseConfig['experimental']);
      if (experimental.isNotEmpty) {
        runtimeConfig['experimental'] = experimental;
      }
      _preserveManagedAwgRuntimeContract(
        runtimeConfig: runtimeConfig,
        baseConfig: baseConfig,
        endpoints: endpoints,
        awgEndpointTags: awgEndpointTags,
      );
      return runtimeConfig;
    }

    final runtimeConfig = <String, dynamic>{
      'log': _buildLogBlock(baseConfig['log']),
      'dns': _buildDnsBlock(
        baseDns: baseConfig['dns'],
        outbounds: outbounds,
        directTag: directTag,
        finalOutboundTag: finalOutboundTag,
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
      'inbounds': _buildInbounds(
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        supportContext: supportContext,
      ),
      'outbounds': outbounds,
      'route': _buildRouteBlock(
        baseRoute: baseConfig['route'],
        directTag: directTag,
        dnsOutboundTag: dnsOutboundTag,
        finalOutboundTag: finalOutboundTag,
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
    };
    _preserveManagedAwgRuntimeContract(
      runtimeConfig: runtimeConfig,
      baseConfig: baseConfig,
      endpoints: endpoints,
      awgEndpointTags: awgEndpointTags,
    );
    return runtimeConfig;
  }

  void _preserveManagedAwgRuntimeContract({
    required Map<String, dynamic> runtimeConfig,
    required Map<String, dynamic> baseConfig,
    required List<Map<String, dynamic>> endpoints,
    required List<String> awgEndpointTags,
  }) {
    if (awgEndpointTags.isEmpty) {
      return;
    }
    runtimeConfig['endpoints'] = endpoints;
    final transportContract = _readMap(
      _readMap(baseConfig['_meta'])['transport_contract'],
    );
    if (transportContract.isEmpty) {
      return;
    }
    runtimeConfig['_meta'] = <String, dynamic>{
      'transport_contract': Map<String, dynamic>.from(transportContract),
    };
  }

  Map<String, dynamic> _buildAndroidDnsBlock({
    required Object? baseDns,
    required List<Map<String, dynamic>> outbounds,
    required String directTag,
    required String finalOutboundTag,
    required RouteMode routeMode,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final dns = _readMap(baseDns).isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_readMap(baseDns));
    final baseServers = _readListOfMaps(dns['servers'])
        .where((server) => !_isLoopbackDnsServer(server))
        .map((server) => Map<String, dynamic>.from(server))
        .toList(growable: true);
    final serverDomains = outbounds
        .map((outbound) => _readText(outbound['server']))
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList(growable: false);
    var directServerTag = 'dns-direct';
    var localServerTag = 'dns-local';
    final existingTags = baseServers
        .map((server) => _readText(server['tag']))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final existingRules = _readListOfMaps(dns['rules'])
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList(growable: true);
    if (existingTags.contains(localServerTag)) {
      var suffix = 2;
      while (existingTags.contains('dns-local-$suffix')) {
        suffix += 1;
      }
      localServerTag = 'dns-local-$suffix';
    }
    if (existingTags.contains(directServerTag)) {
      var suffix = 2;
      while (existingTags.contains('dns-direct-$suffix')) {
        suffix += 1;
      }
      directServerTag = 'dns-direct-$suffix';
    }
    var remoteServerTag = 'dns-remote';
    if (existingTags.contains(remoteServerTag)) {
      var suffix = 2;
      while (existingTags.contains('dns-remote-$suffix')) {
        suffix += 1;
      }
      remoteServerTag = 'dns-remote-$suffix';
    }

    var localBootstrapServerTag = _selectAndroidBootstrapDnsServerTag(
      baseServers,
      directTag: directTag,
    );
    if (baseServers.isNotEmpty && localBootstrapServerTag == null) {
      baseServers.add(<String, dynamic>{
        'tag': localServerTag,
        'type': 'local',
        'detour': directTag,
      });
      localBootstrapServerTag = localServerTag;
    } else if (localBootstrapServerTag != null) {
      for (final server in baseServers) {
        if (_readText(server['tag']) == localBootstrapServerTag) {
          // Legacy `address: local` does not use Android's platform DNS
          // transport in the current core. Normalize it to the typed local
          // server so endpoint hostnames resolve on the underlying network.
          server['type'] = 'local';
          server.remove('address');
          server.remove('address_resolver');
          server['detour'] = directTag;
          break;
        }
      }
    }
    if (baseServers.isNotEmpty && localBootstrapServerTag != null) {
      _ensureAndroidOutboundDomainResolvers(
        outbounds: outbounds,
        serverTag: localBootstrapServerTag,
      );
      _ensureDnsServerDomainRule(
        rules: existingRules,
        serverDomains: serverDomains,
        serverTag: localBootstrapServerTag,
      );
      _ensureDnsIpPrivateRule(
        rules: existingRules,
        serverTag: localBootstrapServerTag,
      );
      if (routeMode == RouteMode.allExceptRu) {
        _ensureDnsDomainSuffixRule(
            existingRules, '.ru', localBootstrapServerTag);
        _ensureDnsDomainSuffixRule(
            existingRules, '.xn--p1ai', localBootstrapServerTag);
        _ensureDnsDomainSuffixRule(
            existingRules, '.su', localBootstrapServerTag);
        _ensureDnsRuleSetServerRule(
          rules: existingRules,
          ruleSetTags: clientRuleSetCatalog.domainRuleSetTags,
          serverTag: localBootstrapServerTag,
        );
      }
      dns['servers'] = baseServers;
      dns['rules'] = existingRules;
      final existingFinal = _readText(dns['final']);
      if (routeMode == RouteMode.fullTunnel ||
          routeMode == RouteMode.excludedApps) {
        var resolvedFinal = existingFinal;
        Map<String, dynamic>? existingFinalServer;
        for (final server in baseServers) {
          if (_readText(server['tag']) == existingFinal) {
            existingFinalServer = server;
            break;
          }
        }
        if (existingFinalServer == null ||
            _isAndroidBootstrapDnsServer(
              existingFinalServer,
              directTag: directTag,
            )) {
          resolvedFinal = _selectAndroidSafeDnsFinalServerTag(
                baseServers,
                directTag: directTag,
              ) ??
              '';
        }
        if (resolvedFinal.isEmpty) {
          baseServers.add(<String, dynamic>{
            'tag': remoteServerTag,
            'address': _preferredAndroidRemoteDnsAddress(baseServers),
            'address_resolver': localBootstrapServerTag,
            'detour': finalOutboundTag,
          });
          resolvedFinal = remoteServerTag;
        }
        dns['final'] = resolvedFinal;
      } else if (existingFinal.isEmpty ||
          !baseServers
              .any((server) => _readText(server['tag']) == existingFinal)) {
        dns['final'] = _readText(baseServers.first['tag']);
      }
      dns['independent_cache'] = true;
      return dns;
    }

    final remoteDnsAddress = _preferredAndroidRemoteDnsAddress(baseServers);
    dns['servers'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'tag': remoteServerTag,
        'address': remoteDnsAddress,
        'address_resolver': directServerTag,
        'detour': finalOutboundTag,
      },
      <String, dynamic>{
        'tag': directServerTag,
        'address': remoteDnsAddress,
        'address_resolver': localServerTag,
        'detour': directTag,
      },
      <String, dynamic>{
        'tag': localServerTag,
        'type': 'local',
        'detour': directTag,
      },
    ];
    _ensureAndroidOutboundDomainResolvers(
      outbounds: outbounds,
      serverTag: localServerTag,
    );
    dns['rules'] = <Map<String, dynamic>>[
      if (serverDomains.isNotEmpty)
        <String, dynamic>{
          'domain': serverDomains,
          'server': localServerTag,
        },
      <String, dynamic>{
        'ip_is_private': true,
        'server': localServerTag,
      },
      if (routeMode == RouteMode.allExceptRu)
        <String, dynamic>{
          'domain_suffix': '.ru',
          'server': localServerTag,
        },
      if (routeMode == RouteMode.allExceptRu)
        <String, dynamic>{
          'domain_suffix': '.xn--p1ai',
          'server': localServerTag,
        },
      if (routeMode == RouteMode.allExceptRu)
        <String, dynamic>{
          'domain_suffix': '.su',
          'server': localServerTag,
        },
      if (routeMode == RouteMode.allExceptRu &&
          clientRuleSetCatalog.domainRuleSetTags.isNotEmpty)
        <String, dynamic>{
          'rule_set': clientRuleSetCatalog.domainRuleSetTags,
          'server': localServerTag,
        },
    ];
    dns['final'] = remoteServerTag;
    dns['independent_cache'] = true;
    return dns;
  }

  Map<String, dynamic> _buildAndroidRouteBlock({
    required Object? baseRoute,
    required String directTag,
    required Set<String> legacyDnsOutboundTags,
    required String finalOutboundTag,
    required RouteMode routeMode,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final route = _readMap(baseRoute).isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_readMap(baseRoute));
    final existingRules = _readListOfMaps(route['rules'])
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList(growable: true);

    _normalizeAndroidRouteModeRules(
      rules: existingRules,
      routeMode: routeMode,
      directTag: directTag,
    );
    _ensureAndroidSelfBypassRule(
      rules: existingRules,
      directTag: directTag,
    );

    if (routeMode == RouteMode.allExceptRu) {
      _mergeRouteRuleSetDefinitions(
        route: route,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      _ensureRouteRuleSetDirectRule(
        rules: existingRules,
        ruleSetTags: clientRuleSetCatalog.allRuleSetTags,
        directTag: directTag,
      );
      _ensureDomainSuffixDirectRule(existingRules, '.ru', directTag);
      _ensureDomainSuffixDirectRule(existingRules, '.xn--p1ai', directTag);
      _ensureDomainSuffixDirectRule(existingRules, '.su', directTag);
    }

    // DNS must win before private-address and package bypass rules. Android's
    // TUN resolver is the private address derived from the TUN subnet, so a
    // preceding `ip_is_private -> direct` rule would black-hole every lookup.
    _ensureAndroidDnsHijackRules(
      rules: existingRules,
      legacyDnsOutboundTags: legacyDnsOutboundTags,
    );

    // The Android VpnService excludes its own package from the TUN. Letting
    // sing-box auto-detect the Android VPN interface loops or rejects outbound
    // sessions on some runtimes, including the supported LDPlayer lane.
    route
      ..['auto_detect_interface'] = false
      ..remove('override_android_vpn')
      ..remove('find_process')
      ..['rules'] = existingRules
      ..['final'] = finalOutboundTag;
    return route;
  }

  void _normalizeAndroidRouteModeRules({
    required List<Map<String, dynamic>> rules,
    required RouteMode routeMode,
    required String directTag,
  }) {
    if (routeMode == RouteMode.allExceptRu) {
      rules.removeWhere(
        (rule) =>
            _readText(rule['outbound']) == directTag &&
            !_isRuBypassRule(
              rule: rule,
              directTag: directTag,
            ),
      );
      return;
    }

    rules.removeWhere(
      (rule) => _readText(rule['outbound']) == directTag,
    );
  }

  void _normalizeVpnOutboundChains({
    required List<Map<String, dynamic>> outbounds,
    required List<String> proxyOutboundTags,
    required String directTag,
  }) {
    final safeProxyTags = proxyOutboundTags
        .where((tag) => tag.isNotEmpty && tag != directTag)
        .toList(growable: false);
    for (var pass = 0; pass < outbounds.length + 1; pass += 1) {
      final safeTags = _computeVpnSafeOutboundTags(
        outbounds: outbounds,
        proxyOutboundTags: safeProxyTags,
      );
      var changed = false;

      for (final outbound in outbounds) {
        if (!_isSelectorLikeOutbound(outbound)) {
          continue;
        }

        final originalTargets = _readTagList(outbound['outbounds']);
        final filteredTargets = originalTargets
            .where((tag) => tag != directTag && safeTags.contains(tag))
            .toList(growable: false);
        final nextTargets = filteredTargets.isEmpty
            ? List<String>.from(safeProxyTags)
            : filteredTargets;
        if (!_sameStringList(originalTargets, nextTargets)) {
          outbound['outbounds'] = nextTargets;
          changed = true;
        }
        if (_readText(outbound['type']).toLowerCase() == 'selector') {
          changed = _normalizeSelectorDefault(
                outbound,
                allowedTargets: nextTargets,
              ) ||
              changed;
        }
      }

      if (!changed) {
        break;
      }
    }
  }

  String _normalizeAndroidFinalOutboundTag({
    required List<Map<String, dynamic>> outbounds,
    required List<String> proxyOutboundTags,
    required RouteMode routeMode,
    required String directTag,
    required String currentFinalOutboundTag,
  }) {
    if (routeMode != RouteMode.fullTunnel &&
        routeMode != RouteMode.excludedApps) {
      return currentFinalOutboundTag;
    }

    final safeTags = _computeVpnSafeOutboundTags(
      outbounds: outbounds,
      proxyOutboundTags: proxyOutboundTags
          .where((tag) => tag.isNotEmpty && tag != directTag)
          .toList(growable: false),
    );
    if (currentFinalOutboundTag.isNotEmpty &&
        safeTags.contains(currentFinalOutboundTag)) {
      return currentFinalOutboundTag;
    }

    for (final outbound in outbounds) {
      final tag = _readText(outbound['tag']);
      if (tag.isNotEmpty && safeTags.contains(tag)) {
        return tag;
      }
    }

    throw const BootstrapFailure(
      'Не удалось подготовить подключение на Android.',
    );
  }

  Set<String> _computeVpnSafeOutboundTags({
    required List<Map<String, dynamic>> outbounds,
    required List<String> proxyOutboundTags,
  }) {
    final safeTags = proxyOutboundTags.toSet();
    var changed = true;
    while (changed) {
      changed = false;
      for (final outbound in outbounds) {
        if (!_isSelectorLikeOutbound(outbound)) {
          continue;
        }
        final tag = _readText(outbound['tag']);
        final targets = _readTagList(outbound['outbounds']);
        if (tag.isEmpty ||
            targets.isEmpty ||
            !targets.every(safeTags.contains)) {
          continue;
        }
        if (safeTags.add(tag)) {
          changed = true;
        }
      }
    }
    return safeTags;
  }

  bool _isSelectorLikeOutbound(Map<String, dynamic> outbound) {
    final type = _readText(outbound['type']).toLowerCase();
    return type == 'selector' || type == 'urltest';
  }

  void _useOwnedAndroidEgressProbe(
    List<Map<String, dynamic>> outbounds,
  ) {
    for (final outbound in outbounds) {
      if (_readText(outbound['type']).toLowerCase() == 'urltest') {
        outbound['url'] = _androidCoreEgressProbeUrl;
      }
    }
  }

  bool _normalizeSelectorDefault(
    Map<String, dynamic> outbound, {
    required List<String> allowedTargets,
  }) {
    final currentDefault = _readText(outbound['default']);
    if (allowedTargets.contains(currentDefault)) {
      return false;
    }
    if (allowedTargets.isEmpty) {
      return outbound.remove('default') != null;
    }
    outbound['default'] = allowedTargets.first;
    return true;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isAndroidBootstrapDnsServer(
    Map<String, dynamic> server, {
    required String directTag,
  }) {
    return _readText(server['type']).toLowerCase() == 'local' ||
        _readText(server['address']).toLowerCase() == 'local' ||
        _readText(server['detour']) == directTag;
  }

  String? _selectAndroidSafeDnsFinalServerTag(
    List<Map<String, dynamic>> servers, {
    required String directTag,
  }) {
    for (final server in servers) {
      final tag = _readText(server['tag']);
      if (tag.isEmpty ||
          _isAndroidBootstrapDnsServer(server, directTag: directTag)) {
        continue;
      }
      return tag;
    }
    return null;
  }

  bool _isRuBypassRule({
    required Map<String, dynamic> rule,
    required String directTag,
  }) {
    if (_readText(rule['outbound']) != directTag) {
      return false;
    }
    final ruleSet = _readTagSet(rule['rule_set']);
    if (ruleSet.contains('geoip-ru') ||
        ruleSet.any(_isAllExceptRuClientRuleSetTag)) {
      return true;
    }
    final suffixes = _readTagSet(rule['domain_suffix']);
    return suffixes.contains('.ru') ||
        suffixes.contains('.xn--p1ai') ||
        suffixes.contains('.su');
  }

  Map<String, dynamic> _buildLogBlock(Object? value) {
    final existing = _readMap(value);
    final logBlock = <String, dynamic>{
      'disabled': false,
      'level': 'info',
    };
    if (existing.isNotEmpty) {
      logBlock.addAll(existing);
      logBlock['disabled'] = existing['disabled'] ?? false;
      logBlock['level'] = _readText(existing['level']).isEmpty
          ? 'info'
          : _readText(existing['level']);
    }
    return logBlock;
  }

  Map<String, dynamic> _buildDnsBlock({
    required Object? baseDns,
    required List<Map<String, dynamic>> outbounds,
    required String directTag,
    required String finalOutboundTag,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    if (hostPlatform == HostPlatform.windows) {
      return _buildWindowsDnsBlock(
        baseDns: baseDns,
        outbounds: outbounds,
        finalOutboundTag: finalOutboundTag,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
    }
    final dns = _readMap(baseDns).isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_readMap(baseDns));
    final serverDomains = outbounds
        .map((outbound) => _readText(outbound['server']))
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final servers = _readListOfMaps(dns['servers'])
        .map((server) => Map<String, dynamic>.from(server))
        .toList(growable: true);
    _ensureDnsServerDefinition(
      servers: servers,
      tag: 'dns-local',
      definition: <String, dynamic>{
        'tag': 'dns-local',
        'address': 'local',
        'detour': directTag,
      },
    );
    _ensureDnsServerDefinition(
      servers: servers,
      tag: 'dns-direct',
      definition: <String, dynamic>{
        'tag': 'dns-direct',
        'address': '1.1.1.1',
        'address_resolver': 'dns-local',
        'detour': directTag,
      },
    );
    _ensureDnsServerDefinition(
      servers: servers,
      tag: 'dns-remote',
      definition: <String, dynamic>{
        'tag': 'dns-remote',
        'address': '1.1.1.1',
        'address_resolver': 'dns-direct',
        'detour': finalOutboundTag,
      },
    );
    _ensureDnsServerDefinition(
      servers: servers,
      tag: 'dns-block',
      definition: <String, dynamic>{
        'tag': 'dns-block',
        'address': 'rcode://success',
      },
    );
    final rules = _readListOfMaps(dns['rules'])
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList(growable: true);
    _ensureDnsServerDomainRule(
      rules: rules,
      serverDomains: serverDomains,
      serverTag: 'dns-direct',
    );
    _ensureDnsIpPrivateRule(
      rules: rules,
      serverTag: 'dns-direct',
    );
    final selectedProcessNames =
        _selectedWindowsProcessNames(hostPlatform, selectedApps);
    if (selectedProcessNames.isNotEmpty) {
      _ensureWindowsSelectedProcessDnsRule(
        rules: rules,
        processNames: selectedProcessNames,
        serverTag: 'dns-remote',
      );
    }
    if (routeMode == RouteMode.allExceptRu) {
      _ensureDnsDomainSuffixRule(rules, '.ru', 'dns-direct');
      _ensureDnsDomainSuffixRule(rules, '.xn--p1ai', 'dns-direct');
      _ensureDnsDomainSuffixRule(rules, '.su', 'dns-direct');
      _ensureDnsRuleSetServerRule(
        rules: rules,
        ruleSetTags: clientRuleSetCatalog.domainRuleSetTags,
        serverTag: 'dns-direct',
      );
    }

    dns
      ..['servers'] = servers
      ..['rules'] = rules
      ..['final'] = selectedProcessNames.isNotEmpty
          ? 'dns-direct'
          : (dns['final'] ?? 'dns-remote')
      ..['independent_cache'] = dns['independent_cache'] ?? false;
    return dns;
  }

  Map<String, dynamic> _buildWindowsDnsBlock({
    required Object? baseDns,
    required List<Map<String, dynamic>> outbounds,
    required String finalOutboundTag,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final serverDomains = outbounds
        .map((outbound) => _readText(outbound['server']))
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final processNames =
        _selectedWindowsProcessNames(HostPlatform.windows, selectedApps);
    final base = _readMap(baseDns);
    final baseServers = _readListOfMaps(base['servers']);
    final directTag = _findOutboundTag(outbounds, 'direct') ?? 'direct';
    bool isNetworkDns(Map<String, dynamic> server) =>
        _readText(server['type']).toLowerCase() != 'local' &&
        _readText(server['address']).toLowerCase() != 'local' &&
        !_readText(server['address']).startsWith('rcode://');
    final candidates = baseServers.where(isNetworkDns).toList();
    final template = candidates
            .where((server) => _readText(server['tag']) == 'dns-remote')
            .firstOrNull ??
        candidates
            .where((server) =>
                _readText(server['tag']) == _readText(base['final']))
            .firstOrNull ??
        candidates.firstOrNull;
    final servers = <Map<String, dynamic>>[...baseServers];
    void putLane(String tag, String detour, Map<String, dynamic> fallback) {
      final index =
          servers.indexWhere((server) => _readText(server['tag']) == tag);
      final existing = index < 0 ? null : servers[index];
      final definition = <String, dynamic>{
        ...((tag == 'dns-remote' && existing != null && !isNetworkDns(existing)
                ? template
                : existing ?? template) ??
            fallback),
        'tag': tag,
        'detour': detour,
      };
      if (tag == 'dns-direct') {
        // The VPN resolver can bootstrap through direct DNS. Its direct copy
        // must not point back to either generated lane.
        const laneTags = <String>{'dns-direct', 'dns-remote'};
        final resolver = definition['domain_resolver'];
        if (resolver is Map &&
            laneTags.contains(_readText(resolver['server']))) {
          definition['domain_resolver'] = <String, dynamic>{
            ..._readMap(resolver),
            'server': 'dns-local',
          };
        } else if (resolver is String && laneTags.contains(resolver)) {
          definition['domain_resolver'] = 'dns-local';
        }
        if (laneTags.contains(_readText(definition['address_resolver']))) {
          definition['address_resolver'] = 'dns-local';
        }
      }
      if (index < 0) {
        servers.add(definition);
      } else {
        servers[index] = definition;
      }
    }

    putLane('dns-remote', finalOutboundTag,
        <String, dynamic>{'type': 'tcp', 'server': '1.1.1.1'});
    putLane('dns-direct', directTag, <String, dynamic>{
      'type': 'udp',
      'server': '1.1.1.1',
      'connect_timeout': '5s',
      'disable_tcp_keep_alive': true
    });
    _ensureDnsServerDefinition(
        servers: servers,
        tag: 'dns-local',
        definition: <String, dynamic>{
          'type': 'local',
          'tag': 'dns-local',
          'prefer_go': true
        });
    // Keep non-routing DNS actions, replace stale process/domain server choices.
    final preservedActions = _readListOfMaps(base['rules'])
        .where((rule) => _readText(rule['server']).isEmpty)
        .toList();
    final rules = <Map<String, dynamic>>[];

    _ensureDnsServerDomainRule(
      rules: rules,
      serverDomains: serverDomains,
      serverTag: 'dns-direct',
    );
    _ensureDnsIpPrivateRule(
      rules: rules,
      serverTag: 'dns-direct',
    );
    if (processNames.isNotEmpty) {
      _ensureWindowsSelectedProcessDnsRule(
        rules: rules,
        processNames: processNames,
        serverTag:
            routeMode == RouteMode.excludedApps ? 'dns-direct' : 'dns-remote',
      );
    }
    if (routeMode == RouteMode.allExceptRu) {
      _ensureDnsDomainSuffixRule(rules, '.ru', 'dns-direct');
      _ensureDnsDomainSuffixRule(rules, '.xn--p1ai', 'dns-direct');
      _ensureDnsDomainSuffixRule(rules, '.su', 'dns-direct');
      _ensureDnsRuleSetServerRule(
        rules: rules,
        ruleSetTags: clientRuleSetCatalog.domainRuleSetTags,
        serverTag: 'dns-direct',
      );
    }

    return <String, dynamic>{
      ...base,
      'servers': servers,
      'rules': <Map<String, dynamic>>[...preservedActions, ...rules],
      'final':
          routeMode == RouteMode.selectedApps ? 'dns-direct' : 'dns-remote',
      'disable_expire': true,
      'independent_cache': true,
    };
  }

  List<Map<String, dynamic>> _buildInbounds({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required Map<String, dynamic> supportContext,
  }) {
    final ipVersionPreference =
        _readText(supportContext['ip_version_preference']).toLowerCase();
    final tunMtu = selectSafeTunMtu(supportContext['tun_mtu']);
    final tunInbound = <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'mtu': tunMtu,
      'auto_route': true,
      'strict_route': true,
      'stack': hostPlatform == HostPlatform.android ? 'mixed' : 'system',
    };
    if (hostPlatform == HostPlatform.android) {
      tunInbound
        ..['endpoint_independent_nat'] = true
        ..['sniff'] = true;
    }
    if (hostPlatform == HostPlatform.android) {
      if (ipVersionPreference == 'ipv6_only') {
        tunInbound.remove('inet4_address');
        tunInbound['inet6_address'] = 'fdfe:dcba:9876::1/126';
        tunInbound['domain_strategy'] = 'ipv6_only';
      } else if (ipVersionPreference == 'ipv4_only') {
        tunInbound['inet4_address'] = '172.19.0.1/28';
        tunInbound.remove('inet6_address');
        tunInbound['domain_strategy'] = 'ipv4_only';
      } else {
        tunInbound['inet4_address'] = '172.19.0.1/28';
        tunInbound['inet6_address'] = 'fdfe:dcba:9876::1/126';
        tunInbound['domain_strategy'] = 'prefer_ipv4';
      }
    } else if (ipVersionPreference == 'ipv6_only') {
      tunInbound['address'] = <String>['fdfe:dcba:9876::1/126'];
      tunInbound['domain_strategy'] = 'ipv6_only';
    } else if (ipVersionPreference == 'ipv4_only') {
      tunInbound['address'] = <String>['172.19.0.1/28'];
      tunInbound['domain_strategy'] = 'ipv4_only';
    } else {
      tunInbound['address'] = <String>[
        '172.19.0.1/28',
        'fdfe:dcba:9876::1/126',
      ];
      tunInbound['domain_strategy'] = 'prefer_ipv4';
    }
    if (hostPlatform == HostPlatform.android) {
      if (routeMode == RouteMode.selectedApps) {
        tunInbound['include_package'] = selectedApps;
      } else {
        tunInbound['exclude_package'] = <String>[
          _androidShellPackageName,
          if (routeMode == RouteMode.excludedApps) ...selectedApps,
        ];
      }
    }

    if (hostPlatform == HostPlatform.android) {
      return <Map<String, dynamic>>[tunInbound];
    }

    return <Map<String, dynamic>>[
      tunInbound,
      <String, dynamic>{
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': 12334,
        'domain_strategy': 'ipv4_only',
      },
    ];
  }

  Map<String, dynamic> _buildRouteBlock({
    required Object? baseRoute,
    required String directTag,
    required String? dnsOutboundTag,
    required String finalOutboundTag,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    final route = _readMap(baseRoute).isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_readMap(baseRoute));
    final rules = _readListOfMaps(route['rules'])
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList(growable: true);
    if (hostPlatform == HostPlatform.windows) {
      _normalizeWindowsRouteModeRules(
        rules: rules,
        routeMode: routeMode,
        directTag: directTag,
      );
      rules.removeWhere(
        (rule) =>
            _readText(rule['inbound']) == 'dns-in' ||
            _readText(rule['protocol']).toLowerCase() == 'dns' ||
            rule['port'] == 53 ||
            _readText(rule['outbound']) == 'dns-out' ||
            _readText(rule['action']).toLowerCase() == 'sniff' ||
            _readText(rule['action']).toLowerCase() == 'hijack-dns',
      );
      rules.insert(0, <String, dynamic>{
        // The Windows system resolver sends UDP/TCP to the LAN DNS address.
        // This Core generation does not classify that packet as `protocol:
        // dns` before the private-address rule runs, so match port 53
        // explicitly and keep DNS inside POKROV.
        'port': 53,
        'action': 'hijack-dns',
      });
      rules.insert(1, <String, dynamic>{'action': 'sniff'});
    } else {
      final resolvedDnsOutboundTag = dnsOutboundTag!;
      final hasDnsInboundRule = rules.any(
        (rule) =>
            _readText(rule['inbound']) == 'dns-in' &&
            _readText(rule['outbound']) == resolvedDnsOutboundTag,
      );
      if (!hasDnsInboundRule) {
        rules.insert(0, <String, dynamic>{
          'inbound': 'dns-in',
          'outbound': resolvedDnsOutboundTag,
        });
      }
      final hasDnsPortRule = rules.any(
        (rule) =>
            rule['port'] == 53 &&
            _readText(rule['outbound']) == resolvedDnsOutboundTag,
      );
      if (!hasDnsPortRule) {
        rules.insert(0, <String, dynamic>{
          'port': 53,
          'outbound': resolvedDnsOutboundTag,
        });
      }
    }
    final hasPrivateRule = rules.any(
      (rule) =>
          rule['ip_is_private'] == true &&
          _readText(rule['outbound']) == directTag,
    );
    if (!hasPrivateRule) {
      rules.add(<String, dynamic>{
        'ip_is_private': true,
        'outbound': directTag,
      });
    }
    final selectedProcessNames =
        _selectedWindowsProcessNames(hostPlatform, selectedApps);
    if (selectedProcessNames.isNotEmpty) {
      _ensureWindowsSelectedProcessRouteRule(
        rules: rules,
        processNames: selectedProcessNames,
        outboundTag:
            routeMode == RouteMode.excludedApps ? directTag : finalOutboundTag,
      );
    }
    if (routeMode == RouteMode.allExceptRu) {
      _mergeRouteRuleSetDefinitions(
        route: route,
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      _ensureRouteRuleSetDirectRule(
        rules: rules,
        ruleSetTags: clientRuleSetCatalog.allRuleSetTags,
        directTag: directTag,
      );
      _ensureDomainSuffixDirectRule(rules, '.ru', directTag);
      _ensureDomainSuffixDirectRule(rules, '.xn--p1ai', directTag);
      _ensureDomainSuffixDirectRule(rules, '.su', directTag);
    }

    route
      ..['rules'] = rules
      ..['final'] =
          routeMode == RouteMode.selectedApps ? directTag : finalOutboundTag;
    if (hostPlatform != HostPlatform.android) {
      route['auto_detect_interface'] = true;
    } else {
      route
        ..['auto_detect_interface'] = false
        ..remove('override_android_vpn');
    }
    if (hostPlatform == HostPlatform.windows) {
      route
        ..['find_process'] = true
        ..['default_domain_resolver'] = <String, dynamic>{
          'server': 'dns-direct',
          'strategy': 'ipv4_only',
        };
    }
    return route;
  }

  void _normalizeWindowsRouteModeRules({
    required List<Map<String, dynamic>> rules,
    required RouteMode routeMode,
    required String directTag,
  }) {
    rules.removeWhere((rule) {
      if (_readText(rule['outbound']) != directTag) {
        return false;
      }
      if (rule['ip_is_private'] == true) {
        return false;
      }
      return routeMode != RouteMode.allExceptRu ||
          !_isRuBypassRule(rule: rule, directTag: directTag);
    });
  }

  Future<_ClientRuleSetCatalog> _ensureAllExceptRuRuleSetCatalog({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required HttpClient client,
  }) async {
    if (routeMode != RouteMode.allExceptRu ||
        (hostPlatform != HostPlatform.android &&
            hostPlatform != HostPlatform.windows)) {
      return _ClientRuleSetCatalog.empty;
    }

    final cacheDirectory = await _ruleSetCacheDirectory();
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }

    final definitions = <_ClientRuleSetDefinition>[];
    final domainRuleSetTags = <String>[];
    final ipRuleSetTags = <String>[];
    for (final spec in _allExceptRuRuleSetSpecs()) {
      final definition = await _resolveCachedRuleSetDefinition(
        spec: spec,
        cacheDirectory: cacheDirectory,
        hostPlatform: hostPlatform,
        client: client,
      );
      if (definition == null) {
        continue;
      }
      definitions.add(definition);
      if (spec.appliesToDns) {
        domainRuleSetTags.add(spec.tag);
      } else {
        ipRuleSetTags.add(spec.tag);
      }
    }

    if (definitions.isEmpty) {
      return _ClientRuleSetCatalog.empty;
    }
    return _ClientRuleSetCatalog(
      definitions: definitions,
      domainRuleSetTags: domainRuleSetTags,
      ipRuleSetTags: ipRuleSetTags,
    );
  }

  Future<Directory> _ruleSetCacheDirectory() async {
    final supportDirectory = await _supportDirectoryResolver();
    return Directory(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'pokrov-runtime${Platform.pathSeparator}'
      'data${Platform.pathSeparator}'
      'rule-set${Platform.pathSeparator}'
      '$_allExceptRuRuleSetCacheDirectoryName',
    );
  }

  Iterable<_CachedRuleSetSpec> _allExceptRuRuleSetSpecs() sync* {
    yield _CachedRuleSetSpec(
      tag: _ruDomainWhitelistRuleSetTag,
      fileName: 'ru-domain-whitelist.srs',
      appliesToDns: true,
      urls: _allExceptRuRuleSetUrlsForTag(_ruDomainWhitelistRuleSetTag),
    );
    yield _CachedRuleSetSpec(
      tag: _ruDomainCategoryRuleSetTag,
      fileName: 'ru-domain-category.srs',
      appliesToDns: true,
      urls: _allExceptRuRuleSetUrlsForTag(_ruDomainCategoryRuleSetTag),
    );
    yield _CachedRuleSetSpec(
      tag: _ruIpCountryRuleSetTag,
      fileName: 'ru-ip-country.srs',
      appliesToDns: false,
      urls: _allExceptRuRuleSetUrlsForTag(_ruIpCountryRuleSetTag),
    );
    yield _CachedRuleSetSpec(
      tag: _ruIpWhitelistRuleSetTag,
      fileName: 'ru-ip-whitelist.srs',
      appliesToDns: false,
      urls: _allExceptRuRuleSetUrlsForTag(_ruIpWhitelistRuleSetTag),
    );
  }

  List<String> _allExceptRuRuleSetUrlsForTag(String tag) {
    final override =
        _allExceptRuRuleSetUrlsResolver?.call(tag) ?? const <String>[];
    if (override.isNotEmpty) {
      return override;
    }
    return _defaultAllExceptRuRuleSetUrlsByTag[tag] ?? const <String>[];
  }

  Future<_ClientRuleSetDefinition?> _resolveCachedRuleSetDefinition({
    required _CachedRuleSetSpec spec,
    required Directory cacheDirectory,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    final cachedFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}${spec.fileName}',
    );
    final hasCachedFile = await cachedFile.exists();
    if (hasCachedFile) {
      final lastModified = await cachedFile.lastModified();
      if (DateTime.now().difference(lastModified) <=
          _allExceptRuRuleSetCacheMaxAge) {
        return spec.toDefinition(cachedFile.path);
      }
    }

    final bytes = await _downloadRuleSetBytes(
      spec: spec,
      hostPlatform: hostPlatform,
      client: client,
    );
    if (bytes != null && bytes.isNotEmpty) {
      await _writeRuleSetBytes(
        cachedFile: cachedFile,
        bytes: bytes,
      );
      return spec.toDefinition(cachedFile.path);
    }
    if (hasCachedFile) {
      return spec.toDefinition(cachedFile.path);
    }
    return null;
  }

  Future<List<int>?> _downloadRuleSetBytes({
    required _CachedRuleSetSpec spec,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    for (final url in spec.urls) {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        continue;
      }
      try {
        return await _requestBytes(
          uri: uri,
          hostPlatform: hostPlatform,
          client: client,
        );
      } on BootstrapFailure {
        continue;
      }
    }
    return null;
  }

  Future<void> _writeRuleSetBytes({
    required File cachedFile,
    required List<int> bytes,
  }) async {
    final tempFile = File('${cachedFile.path}.download');
    try {
      await cachedFile.parent.create(recursive: true);
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      await tempFile.rename(cachedFile.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void _injectAllExceptRuRuleSetCatalog({
    required Map<String, dynamic> config,
    required HostPlatform hostPlatform,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    if (clientRuleSetCatalog.isEmpty) {
      return;
    }
    final outbounds = _readListOfMaps(config['outbounds'])
        .map((outbound) => Map<String, dynamic>.from(outbound))
        .toList(growable: true);
    if (outbounds.isEmpty) {
      return;
    }
    final existingTags = outbounds
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final directTag = _ensureAuxiliaryOutbound(
      outbounds,
      existingTags,
      preferredTag: 'direct',
      type: 'direct',
    );
    _ensureAuxiliaryOutbound(
      outbounds,
      existingTags,
      preferredTag: 'block',
      type: 'block',
    );
    final legacyDnsOutboundTags = hostPlatform == HostPlatform.windows
        ? _removeLegacyDnsOutbounds(outbounds)
        : const <String>{};
    existingTags.removeAll(legacyDnsOutboundTags);
    final dnsOutboundTag = hostPlatform == HostPlatform.windows
        ? null
        : _ensureAuxiliaryOutbound(
            outbounds,
            existingTags,
            preferredTag: 'dns-out',
            type: 'dns',
          );
    final proxyOutboundTags = outbounds
        .where(_isProxyTransportOutbound)
        .map((outbound) => _readText(outbound['tag']))
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    var finalOutboundTag = _readText(_readMap(config['route'])['final']);
    if (!existingTags.contains(finalOutboundTag) ||
        _isAuxiliaryTag(finalOutboundTag)) {
      finalOutboundTag = '';
    }
    final selectorTag = _findOutboundTag(outbounds, 'selector');
    final urlTestTag = _findOutboundTag(outbounds, 'urltest');
    if (finalOutboundTag.isEmpty && selectorTag != null) {
      finalOutboundTag = selectorTag;
    }
    if (finalOutboundTag.isEmpty && urlTestTag != null) {
      finalOutboundTag = urlTestTag;
    }
    if (finalOutboundTag.isEmpty && proxyOutboundTags.isNotEmpty) {
      finalOutboundTag = proxyOutboundTags.first;
    }
    if (finalOutboundTag.isEmpty) {
      return;
    }

    config['outbounds'] = outbounds;
    config['dns'] = _buildDnsBlock(
      baseDns: config['dns'],
      outbounds: outbounds,
      directTag: directTag,
      finalOutboundTag: finalOutboundTag,
      hostPlatform: hostPlatform,
      routeMode: RouteMode.allExceptRu,
      selectedApps: const <String>[],
      clientRuleSetCatalog: clientRuleSetCatalog,
    );
    config['route'] = _buildRouteBlock(
      baseRoute: config['route'],
      directTag: directTag,
      dnsOutboundTag: dnsOutboundTag,
      finalOutboundTag: finalOutboundTag,
      hostPlatform: hostPlatform,
      routeMode: RouteMode.allExceptRu,
      selectedApps: const <String>[],
      clientRuleSetCatalog: clientRuleSetCatalog,
    );
  }

  void _ensureDomainSuffixDirectRule(
    List<Map<String, dynamic>> rules,
    String suffix,
    String directTag,
  ) {
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['domain_suffix']) == suffix &&
          _readText(rule['outbound']) == directTag,
    );
    if (!alreadyPresent) {
      rules.add(<String, dynamic>{
        'domain_suffix': suffix,
        'outbound': directTag,
      });
    }
  }

  void _ensureAndroidSelfBypassRule({
    required List<Map<String, dynamic>> rules,
    required String directTag,
  }) {
    final alreadyPresent = rules.any(
      (rule) =>
          (_readTagList(rule['inbound']).contains('tun-in') ||
              _readText(rule['inbound']) == 'tun-in') &&
          (_readTagList(rule['package_name'])
                  .contains(_androidShellPackageName) ||
              _readText(rule['package_name']) == _androidShellPackageName) &&
          _readText(rule['outbound']) == directTag,
    );
    if (!alreadyPresent) {
      final insertAt = rules.takeWhile(_isAndroidDnsHijackRule).length;
      rules.insert(insertAt, <String, dynamic>{
        'inbound': const <String>['tun-in'],
        'package_name': const <String>[_androidShellPackageName],
        'outbound': directTag,
      });
    }
  }

  void _ensureAndroidDnsHijackRules({
    required List<Map<String, dynamic>> rules,
    required Set<String> legacyDnsOutboundTags,
  }) {
    rules.removeWhere(
      (rule) =>
          _isAndroidDnsHijackRule(rule) ||
          (legacyDnsOutboundTags.contains(_readText(rule['outbound'])) &&
              (_readText(rule['protocol']).toLowerCase() == 'dns' ||
                  rule['port'] == 53)),
    );
    rules.insert(0, <String, dynamic>{
      'protocol': 'dns',
      'action': 'hijack-dns',
    });
  }

  bool _isAndroidDnsHijackRule(Map<String, dynamic> rule) =>
      _readText(rule['protocol']).toLowerCase() == 'dns' &&
      _readText(rule['action']).toLowerCase() == 'hijack-dns';

  void _ensureDnsServerDomainRule({
    required List<Map<String, dynamic>> rules,
    required List<String> serverDomains,
    required String serverTag,
  }) {
    if (serverDomains.isEmpty) {
      return;
    }
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['server']) == serverTag &&
          (rule['domain'] as List?)
                  ?.map((value) => value?.toString())
                  .whereType<String>()
                  .toSet()
                  .containsAll(serverDomains) ==
              true,
    );
    if (!alreadyPresent) {
      rules.insert(0, <String, dynamic>{
        'domain': serverDomains,
        'server': serverTag,
      });
    }
  }

  void _ensureDnsIpPrivateRule({
    required List<Map<String, dynamic>> rules,
    required String serverTag,
  }) {
    final alreadyPresent = rules.any(
      (rule) =>
          rule['ip_is_private'] == true &&
          _readText(rule['server']) == serverTag,
    );
    if (!alreadyPresent) {
      rules.add(<String, dynamic>{
        'ip_is_private': true,
        'server': serverTag,
      });
    }
  }

  void _ensureDnsDomainSuffixRule(
    List<Map<String, dynamic>> rules,
    String suffix,
    String serverTag,
  ) {
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['domain_suffix']) == suffix &&
          _readText(rule['server']) == serverTag,
    );
    if (!alreadyPresent) {
      rules.add(<String, dynamic>{
        'domain_suffix': suffix,
        'server': serverTag,
      });
    }
  }

  void _ensureDnsRuleSetServerRule({
    required List<Map<String, dynamic>> rules,
    required List<String> ruleSetTags,
    required String serverTag,
  }) {
    if (ruleSetTags.isEmpty) {
      return;
    }
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['server']) == serverTag &&
          _sameStringList(_readTagList(rule['rule_set']), ruleSetTags),
    );
    if (!alreadyPresent) {
      rules.add(<String, dynamic>{
        'rule_set': ruleSetTags,
        'server': serverTag,
      });
    }
  }

  void _ensureDnsServerDefinition({
    required List<Map<String, dynamic>> servers,
    required String tag,
    required Map<String, dynamic> definition,
  }) {
    final existingIndex = servers.indexWhere(
      (server) => _readText(server['tag']) == tag,
    );
    if (existingIndex >= 0) {
      return;
    }
    servers.add(definition);
  }

  void _ensureRouteRuleSetDirectRule({
    required List<Map<String, dynamic>> rules,
    required List<String> ruleSetTags,
    required String directTag,
  }) {
    if (ruleSetTags.isEmpty) {
      return;
    }
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['outbound']) == directTag &&
          _sameStringList(_readTagList(rule['rule_set']), ruleSetTags),
    );
    if (!alreadyPresent) {
      rules.add(<String, dynamic>{
        'rule_set': ruleSetTags,
        'outbound': directTag,
      });
    }
  }

  void _ensureWindowsSelectedProcessDnsRule({
    required List<Map<String, dynamic>> rules,
    required List<String> processNames,
    required String serverTag,
  }) {
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['server']) == serverTag &&
          _sameStringList(_readTagList(rule['process_name']), processNames),
    );
    if (!alreadyPresent) {
      rules.insert(0, <String, dynamic>{
        'process_name': processNames,
        'server': serverTag,
      });
    }
  }

  void _ensureWindowsSelectedProcessRouteRule({
    required List<Map<String, dynamic>> rules,
    required List<String> processNames,
    required String outboundTag,
  }) {
    final alreadyPresent = rules.any(
      (rule) =>
          _readText(rule['outbound']) == outboundTag &&
          _sameStringList(_readTagList(rule['process_name']), processNames),
    );
    if (!alreadyPresent) {
      rules.insert(min(2, rules.length), <String, dynamic>{
        'process_name': processNames,
        'outbound': outboundTag,
      });
    }
  }

  void _mergeRouteRuleSetDefinitions({
    required Map<String, dynamic> route,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) {
    if (clientRuleSetCatalog.isEmpty) {
      return;
    }
    final existing = _readListOfMaps(route['rule_set'])
        .map((ruleSet) => Map<String, dynamic>.from(ruleSet))
        .toList(growable: true);
    final definitionsByTag = <String, Map<String, dynamic>>{};
    for (final ruleSet in existing) {
      final tag = _readText(ruleSet['tag']);
      if (tag.isNotEmpty) {
        definitionsByTag[tag] = ruleSet;
      }
    }
    for (final definition in clientRuleSetCatalog.definitions) {
      definitionsByTag[definition.tag] = definition.toJson();
    }
    route['rule_set'] = definitionsByTag.values.toList(growable: false);
  }

  bool _isLoopbackDnsServer(Map<String, dynamic> server) {
    final address = _readText(server['address']).toLowerCase();
    return address.contains('127.0.0.1') ||
        address.contains('localhost') ||
        address.contains('::1');
  }

  String? _selectAndroidBootstrapDnsServerTag(
    List<Map<String, dynamic>> servers, {
    required String directTag,
  }) {
    for (final server in servers) {
      if ((_readText(server['type']).toLowerCase() == 'local' ||
              _readText(server['address']).toLowerCase() == 'local') &&
          _readText(server['detour']) == directTag) {
        final tag = _readText(server['tag']);
        if (tag.isNotEmpty) {
          return tag;
        }
      }
    }
    return null;
  }

  String _preferredAndroidRemoteDnsAddress(List<Map<String, dynamic>> servers) {
    for (final server in servers) {
      if (_readText(server['type']).toLowerCase() == 'local') {
        continue;
      }
      final address = _readText(server['address']);
      final normalizedAddress = address.toLowerCase();
      if (normalizedAddress.isEmpty || normalizedAddress == 'local') {
        continue;
      }
      if (normalizedAddress.startsWith('https://')) {
        return address;
      }
    }
    return 'https://1.1.1.1/dns-query';
  }

  void _ensureAndroidOutboundDomainResolvers({
    required List<Map<String, dynamic>> outbounds,
    required String serverTag,
  }) {
    for (final outbound in outbounds) {
      final server = _readText(outbound['server']);
      // A detoured hop must pass its FQDN through the preceding proxy. Local
      // resolution here leaks/breaks reserve -> RU -> foreign emergency
      // chains and is contrary to sing-box detour semantics.
      if (_readText(outbound['detour']).isNotEmpty) {
        outbound.remove('domain_resolver');
        continue;
      }
      if (server.isEmpty || InternetAddress.tryParse(server) != null) {
        continue;
      }
      outbound['domain_resolver'] = serverTag;
    }
  }

  void _applyRealityTlsFragmentPolicy({
    required Map<String, dynamic> baseConfig,
    required Map<String, dynamic> supportContext,
  }) {
    final policy = _readMap(supportContext['reality_tls_fragment']);
    if (!_readBool(policy['enabled'])) {
      return;
    }

    final fragment =
        policy.containsKey('fragment') ? _readBool(policy['fragment']) : false;
    final recordFragment = policy.containsKey('record_fragment')
        ? _readBool(policy['record_fragment'])
        : true;
    if (!fragment && !recordFragment) {
      return;
    }
    final fallbackDelay = _readText(policy['fragment_fallback_delay']);
    final validFallbackDelay =
        RegExp(r'^\d+(?:ns|us|µs|ms|s|m|h)$').hasMatch(fallbackDelay);

    final outbounds = _readListOfMaps(baseConfig['outbounds'])
        .map((outbound) => Map<String, dynamic>.from(outbound))
        .toList(growable: false);
    var changed = false;
    for (final outbound in outbounds) {
      if (_readText(outbound['type']).toLowerCase() != 'vless') {
        continue;
      }
      final transport = _readMap(outbound['transport']);
      if (_readText(transport['type']).isNotEmpty) {
        continue;
      }
      final tls = _readMap(outbound['tls']);
      final reality = _readMap(tls['reality']);
      if (!_readBool(reality['enabled'])) {
        continue;
      }

      final patchedTls = Map<String, dynamic>.from(tls);
      if (!patchedTls.containsKey('fragment')) {
        patchedTls['fragment'] = fragment;
      }
      if (!patchedTls.containsKey('record_fragment')) {
        patchedTls['record_fragment'] = recordFragment;
      }
      if (validFallbackDelay &&
          !patchedTls.containsKey('fragment_fallback_delay')) {
        patchedTls['fragment_fallback_delay'] = fallbackDelay;
      }
      outbound['tls'] = patchedTls;
      outbound['tcp_fast_open'] = false;
      changed = true;
    }
    if (changed) {
      baseConfig['outbounds'] = outbounds;
    }
  }

  bool _isProxyTransportOutbound(Map<String, dynamic> outbound) {
    final type = _readText(outbound['type']).toLowerCase();
    return !const {'direct', 'block', 'dns', 'selector', 'urltest'}
        .contains(type);
  }

  Set<String> _removeLegacyDnsOutbounds(
    List<Map<String, dynamic>> outbounds,
  ) {
    final removedTags = <String>{'dns-out'};
    for (final outbound in outbounds) {
      if (_readText(outbound['type']).toLowerCase() == 'dns') {
        final tag = _readText(outbound['tag']);
        if (tag.isNotEmpty) {
          removedTags.add(tag);
        }
      }
    }
    outbounds.removeWhere(
      (outbound) => _readText(outbound['type']).toLowerCase() == 'dns',
    );
    return removedTags;
  }

  String _ensureAuxiliaryOutbound(
    List<Map<String, dynamic>> outbounds,
    Set<String> existingTags, {
    required String preferredTag,
    required String type,
  }) {
    final existing = outbounds.firstWhere(
      (outbound) => _readText(outbound['tag']) == preferredTag,
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty) {
      return preferredTag;
    }

    var tag = preferredTag;
    var suffix = 2;
    while (existingTags.contains(tag)) {
      tag = '$preferredTag-$suffix';
      suffix += 1;
    }
    outbounds.add(<String, dynamic>{
      'type': type,
      'tag': tag,
    });
    existingTags.add(tag);
    return tag;
  }

  String? _findOutboundTag(
    List<Map<String, dynamic>> outbounds,
    String type,
  ) {
    for (final outbound in outbounds) {
      if (_readText(outbound['type']).toLowerCase() == type) {
        final tag = _readText(outbound['tag']);
        if (tag.isNotEmpty) {
          return tag;
        }
      }
    }
    return null;
  }

  String _synthesizeSelectorOutbounds({
    required List<Map<String, dynamic>> outbounds,
    required Set<String> existingTags,
    required List<String> proxyOutboundTags,
  }) {
    var urlTestTag = 'auto';
    var urlTestSuffix = 2;
    while (existingTags.contains(urlTestTag)) {
      urlTestTag = 'auto-$urlTestSuffix';
      urlTestSuffix += 1;
    }

    outbounds.add(<String, dynamic>{
      'type': 'urltest',
      'tag': urlTestTag,
      'outbounds': proxyOutboundTags,
      'url': 'http://cp.cloudflare.com',
      'interval': '10m0s',
      'tolerance': 1,
      'interrupt_exist_connections': true,
    });
    existingTags.add(urlTestTag);

    var selectorTag = 'select';
    var selectorSuffix = 2;
    while (existingTags.contains(selectorTag)) {
      selectorTag = 'select-$selectorSuffix';
      selectorSuffix += 1;
    }

    outbounds.add(<String, dynamic>{
      'type': 'selector',
      'tag': selectorTag,
      'outbounds': <String>[
        urlTestTag,
        ...proxyOutboundTags,
      ],
      'default': urlTestTag,
      'interrupt_exist_connections': true,
    });
    existingTags.add(selectorTag);
    return selectorTag;
  }

  bool _isAuxiliaryTag(String tag) =>
      tag == 'direct' || tag == 'block' || tag == 'dns-out';

  bool _isAllExceptRuClientRuleSetTag(String tag) =>
      tag == _ruDomainWhitelistRuleSetTag ||
      tag == _ruDomainCategoryRuleSetTag ||
      tag == _ruIpCountryRuleSetTag ||
      tag == _ruIpWhitelistRuleSetTag;

  List<String> _readTagList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    final seen = <String>{};
    final tags = <String>[];
    for (final item in value) {
      final tag = item?.toString().trim() ?? '';
      if (tag.isEmpty || !seen.add(tag)) {
        continue;
      }
      tags.add(tag);
    }
    return tags;
  }

  Set<String> _readTagSet(Object? value) {
    if (value is List) {
      return _readTagList(value).toSet();
    }
    final text = _readText(value);
    if (text.isEmpty) {
      return <String>{};
    }
    return <String>{text};
  }

  List<String> _normalizeSelectedAppIdentifiers(List<String> selectedApps) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final item in selectedApps) {
      final value = _trim(item, 96);
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }
      normalized.add(value);
      if (normalized.length >= 128) {
        break;
      }
    }
    return normalized;
  }

  List<String> _selectedWindowsProcessNames(
    HostPlatform hostPlatform,
    List<String> selectedApps,
  ) {
    if (hostPlatform != HostPlatform.windows || selectedApps.isEmpty) {
      return const <String>[];
    }
    final seen = <String>{};
    final processNames = <String>[];
    final safeProcessName = RegExp(r'^[a-z0-9_.-]+\.exe$');
    for (final item in selectedApps) {
      var value = _trim(item, 96).replaceAll(r'\', '/').toLowerCase();
      if (value.isEmpty) {
        continue;
      }
      final separator = value.lastIndexOf('/');
      if (separator >= 0) {
        value = value.substring(separator + 1);
      }
      if (!value.endsWith('.exe')) {
        value = '$value.exe';
      }
      if (!safeProcessName.hasMatch(value) || !seen.add(value)) {
        continue;
      }
      processNames.add(value);
      if (processNames.length >= 128) {
        break;
      }
    }
    return processNames;
  }

  List<Map<String, dynamic>> _readListOfMaps(Object? value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, nestedValue) => MapEntry(key.toString(), nestedValue),
          ),
        )
        .toList(growable: true);
  }

  Future<List<int>> _requestBytes({
    required Uri uri,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    BootstrapFailure? lastFailure;
    for (var attempt = 0; attempt < maxRequestAttempts; attempt += 1) {
      try {
        final request = await client.openUrl(
          'GET',
          uri,
        );
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          _userAgent(hostPlatform),
        );
        final response = await request.close().timeout(requestTimeout);
        final bytes = await _readBoundedResponseBytes(
          response,
          maxBytes: _maxRuleSetResponseBytes,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final failure = BootstrapFailure(
            _errorMessageForResponse(
              utf8.decode(bytes, allowMalformed: true),
              response.statusCode,
            ),
            statusCode: response.statusCode,
          );
          if (!_shouldRetryStatus(response.statusCode) ||
              attempt >= maxRequestAttempts - 1) {
            throw failure;
          }
          lastFailure = failure;
          await _delayScheduler(_retryDelayForAttempt(attempt));
          continue;
        }
        if (bytes.isEmpty) {
          throw BootstrapFailure(
            'POKROV получил пустое обновление правил от ${uri.host}.',
          );
        }
        return bytes;
      } on SocketException {
        const failure = BootstrapFailure(
          'Не удалось обновить правила. Проверьте интернет и попробуйте ещё раз.',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HttpException {
        const failure = BootstrapFailure(
          'Не удалось обновить правила. Проверьте интернет и попробуйте ещё раз.',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException {
        const failure = BootstrapFailure(
          'Не удалось безопасно обновить правила. Проверьте дату, время и интернет.',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        const failure = BootstrapFailure(
          'Обновление правил заняло слишком много времени. Попробуйте ещё раз.',
          statusCode: HttpStatus.gatewayTimeout,
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      }

      await _delayScheduler(_retryDelayForAttempt(attempt));
    }

    throw lastFailure ??
        const BootstrapFailure(
          'Не удалось обновить правила. Проверьте интернет и попробуйте ещё раз.',
        );
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    required HostPlatform hostPlatform,
    required HttpClient client,
    String bearerToken = '',
    Map<String, Object?>? body,
    Map<String, String> headers = const <String, String>{},
    List<int>? rawBody,
    String rawContentType = 'application/octet-stream',
    Duration? requestTimeoutOverride,
  }) async {
    if (body != null && rawBody != null) {
      throw ArgumentError('JSON body and raw body are mutually exclusive.');
    }
    BootstrapFailure? lastFailure;
    final operation = '$method $path';
    final retryable = method.trim().toUpperCase() == 'GET';
    final attemptLimit = retryable ? maxRequestAttempts : 1;
    for (var attempt = 0; attempt < attemptLimit; attempt += 1) {
      Uri? requestUri;
      try {
        final selectedBaseUrl = await _resolveApiBaseUrl(
          client: client,
          hostPlatform: hostPlatform,
        );
        requestUri = Uri.parse(selectedBaseUrl).resolve(path);
        final request = await client.openUrl(
          method,
          requestUri,
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          _userAgent(hostPlatform),
        );
        request.headers.set(
          _correlationIdHeader,
          PortalCorrelationScope.currentOrCreate(),
        );
        if (bearerToken.isNotEmpty) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $bearerToken',
          );
        }
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
        if (body != null) {
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.write(jsonEncode(body));
        } else if (rawBody != null) {
          request.headers.set(HttpHeaders.contentTypeHeader, rawContentType);
          request.add(rawBody);
        }

        final effectiveRequestTimeout =
            requestTimeoutOverride ?? requestTimeout;
        final response = await request.close().timeout(effectiveRequestTimeout);
        final bytes = await _readBoundedResponseBytes(
          response,
          maxBytes: _maxJsonResponseBytes,
          timeout: effectiveRequestTimeout,
        );
        final text = utf8.decode(bytes, allowMalformed: true);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final failure = BootstrapFailure(
            _errorMessageForResponse(text, response.statusCode),
            statusCode: response.statusCode,
            operation: operation,
            code: _platformErrorCode(response),
          );
          if (!retryable ||
              !_shouldRetryStatus(response.statusCode) ||
              attempt >= attemptLimit - 1) {
            throw failure;
          }
          lastFailure = failure;
          await _delayScheduler(_retryDelayForAttempt(attempt));
          continue;
        }

        if (text.trim().isEmpty) {
          return const <String, dynamic>{};
        }

        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
        throw BootstrapFailure(
          'POKROV получил неожиданный ответ во время подготовки устройства.',
          operation: operation,
          operationalCode: 'API-008',
        );
      } on SocketException {
        _invalidateApiBaseUrl(requestUri);
        final failure = BootstrapFailure(
          'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
          operation: operation,
          operationalCode: 'API-002',
        );
        if (attempt >= attemptLimit - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HttpException {
        _invalidateApiBaseUrl(requestUri);
        final failure = BootstrapFailure(
          'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
          operation: operation,
          operationalCode: 'API-002',
        );
        if (attempt >= attemptLimit - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException {
        _invalidateApiBaseUrl(requestUri);
        final failure = BootstrapFailure(
          'Не удалось безопасно подключиться к сервису. Проверьте дату, время и интернет.',
          operation: operation,
          operationalCode: 'API-003',
        );
        if (attempt >= attemptLimit - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        _invalidateApiBaseUrl(requestUri);
        final failure = BootstrapFailure(
          'Сервис не ответил вовремя. Попробуйте ещё раз.',
          statusCode: HttpStatus.gatewayTimeout,
          operation: operation,
          operationalCode: 'API-002',
        );
        if (attempt >= attemptLimit - 1) {
          throw failure;
        }
        lastFailure = failure;
      }

      await _delayScheduler(_retryDelayForAttempt(attempt));
    }

    throw lastFailure ??
        BootstrapFailure(
          'POKROV не смог связаться с сервисом подготовки.',
          operation: operation,
        );
  }

  Future<String> _resolveApiBaseUrl({
    required HttpClient client,
    required HostPlatform hostPlatform,
  }) async {
    if (_apiBaseUrls.length == 1) {
      return _apiBaseUrls.single;
    }
    final active = _activeApiBaseUrl;
    if (active != null) {
      return active;
    }
    final existingFlight = _apiBaseUrlFlight;
    if (existingFlight != null) {
      return existingFlight;
    }
    final flight = _selectApiBaseUrl(
      client: client,
      hostPlatform: hostPlatform,
    );
    _apiBaseUrlFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_apiBaseUrlFlight, flight)) {
        _apiBaseUrlFlight = null;
      }
    }
  }

  Future<String> _selectApiBaseUrl({
    required HttpClient client,
    required HostPlatform hostPlatform,
  }) async {
    for (final candidate in _apiBaseUrls) {
      try {
        final request = await client.getUrl(
          Uri.parse(candidate).resolve('/api/health'),
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          _userAgent(hostPlatform),
        );
        request.headers.set(
          _correlationIdHeader,
          PortalCorrelationScope.currentOrCreate(),
        );
        final response = await request.close().timeout(requestTimeout);
        final contentType = response.headers.contentType;
        final bytes = await _readBoundedResponseBytes(
          response,
          maxBytes: 64 * 1024,
          timeout: requestTimeout,
        );
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            contentType?.mimeType.toLowerCase() != 'application/json') {
          continue;
        }
        final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
        if (decoded is! Map) {
          continue;
        }
        _activeApiBaseUrl = candidate;
        return candidate;
      } on Object catch (error) {
        if (error is! SocketException &&
            error is! HttpException &&
            error is! HandshakeException &&
            error is! TimeoutException &&
            error is! FormatException &&
            error is! BootstrapFailure) {
          rethrow;
        }
      }
    }
    throw const BootstrapFailure(
      'Не удалось связаться с сервисом. Проверьте сеть и попробуйте ещё раз.',
      operationalCode: 'API-002',
    );
  }

  void _invalidateApiBaseUrl(Uri? requestUri) {
    final active = _activeApiBaseUrl;
    if (active == null || requestUri == null) {
      return;
    }
    final activeUri = Uri.parse(active);
    if (activeUri.scheme == requestUri.scheme &&
        activeUri.host == requestUri.host &&
        activeUri.port == requestUri.port) {
      _activeApiBaseUrl = null;
    }
  }

  static String _normalizeApiBaseUrl(String rawValue) {
    final value = rawValue.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(rawValue, 'apiBaseUrl', 'Invalid API URL.');
    }
    final normalizedPath = uri.path.isEmpty
        ? '/'
        : (uri.path.endsWith('/') ? uri.path : '${uri.path}/');
    return uri.replace(path: normalizedPath).toString();
  }

  static List<String> _buildApiBaseUrls(
    String rawPrimary,
    List<String>? rawFallbacks,
  ) {
    final primary = _normalizeApiBaseUrl(rawPrimary);
    final primaryUri = Uri.parse(primary);
    final fallbacks = rawFallbacks ?? _implicitOwnedApiFallbacks(primaryUri);
    final result = <String>[primary];
    for (final rawFallback in fallbacks) {
      final fallback = _normalizeApiBaseUrl(rawFallback);
      if (result.contains(fallback)) {
        continue;
      }
      final fallbackUri = Uri.parse(fallback);
      if (!_isTrustedApiFallback(primaryUri, fallbackUri)) {
        throw ArgumentError.value(
          rawFallback,
          'apiFallbackBaseUrls',
          'API fallback must stay inside the owned API pair or loopback.',
        );
      }
      result.add(fallback);
    }
    return List<String>.unmodifiable(result);
  }

  static List<String> _implicitOwnedApiFallbacks(Uri primary) {
    if (primary.scheme != 'https' ||
        primary.hasPort ||
        primary.path != '/' ||
        !_ownedApiHosts.contains(primary.host.toLowerCase())) {
      return const <String>[];
    }
    return primary.host.toLowerCase() == 'app.pokrov.space'
        ? const <String>['https://api.pokrov.space/']
        : const <String>['https://app.pokrov.space/'];
  }

  static bool _isTrustedApiFallback(Uri primary, Uri fallback) {
    final primaryHost = primary.host.toLowerCase();
    final fallbackHost = fallback.host.toLowerCase();
    final ownedPair = primary.scheme == 'https' &&
        fallback.scheme == 'https' &&
        !primary.hasPort &&
        !fallback.hasPort &&
        primary.path == '/' &&
        fallback.path == '/' &&
        _ownedApiHosts.contains(primaryHost) &&
        _ownedApiHosts.contains(fallbackHost);
    if (ownedPair) {
      return true;
    }
    const loopbackHosts = <String>{'127.0.0.1', '::1', 'localhost'};
    return primary.scheme == 'http' &&
        fallback.scheme == 'http' &&
        primary.path == '/' &&
        fallback.path == '/' &&
        loopbackHosts.contains(primaryHost) &&
        loopbackHosts.contains(fallbackHost);
  }

  Future<List<int>> _readBoundedResponseBytes(
    HttpClientResponse response, {
    required int maxBytes,
    Duration? timeout,
  }) async {
    final contentLength = response.contentLength;
    if (contentLength > maxBytes) {
      throw const BootstrapFailure(
        'Ответ сервиса оказался слишком большим. Попробуйте ещё раз.',
        operationalCode: 'API-010',
      );
    }

    final iterator = StreamIterator<List<int>>(response);
    final bytes = <int>[];
    final deadline = DateTime.now().add(timeout ?? requestTimeout);
    try {
      while (true) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('response body deadline exceeded');
        }
        final hasNext = await iterator.moveNext().timeout(remaining);
        if (!hasNext) {
          return bytes;
        }
        final chunk = iterator.current;
        if (chunk.length > maxBytes - bytes.length) {
          throw const BootstrapFailure(
            'Ответ сервиса оказался слишком большим. Попробуйте ещё раз.',
            operationalCode: 'API-010',
          );
        }
        bytes.addAll(chunk);
      }
    } finally {
      await iterator.cancel();
    }
  }

  bool _isSessionFailure(int? statusCode) =>
      statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.forbidden;

  bool _shouldRetryStatus(int statusCode) =>
      statusCode == HttpStatus.requestTimeout ||
      statusCode == HttpStatus.tooManyRequests ||
      statusCode == HttpStatus.badGateway ||
      statusCode == HttpStatus.serviceUnavailable ||
      statusCode == HttpStatus.gatewayTimeout;

  String _platformErrorCode(HttpClientResponse response) {
    final normalized = (response.headers.value(_platformErrorCodeHeader) ?? '')
        .trim()
        .toLowerCase();
    return _platformErrorCodePattern.hasMatch(normalized) ? normalized : '';
  }

  Duration _retryDelayForAttempt(int attempt) {
    final baseMs = 350 * (attempt + 1) * (attempt + 1);
    return Duration(milliseconds: baseMs);
  }

  String _routeModeWireValue(RouteMode routeMode) {
    switch (routeMode) {
      case RouteMode.selectedApps:
        return 'selected_apps';
      case RouteMode.excludedApps:
      case RouteMode.fullTunnel:
      case RouteMode.allExceptRu:
        return 'all_traffic';
    }
  }

  String _safeWarpToken(String value, {required String fallback}) {
    final cleaned = value.trim().toLowerCase();
    if (cleaned.isEmpty || !RegExp(r'^[a-z0-9_:-]{2,64}$').hasMatch(cleaned)) {
      return fallback;
    }
    return cleaned;
  }

  Map<String, Object?> _sanitizeWarpRuntimeMeta(
    Map<String, Object?> meta,
  ) {
    final sanitized = <String, Object?>{};
    for (final entry in meta.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _isUnsafeWarpMetaKey(key)) {
        continue;
      }
      final value = _sanitizeWarpRuntimeMetaValue(entry.value);
      if (value != null) {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  Object? _sanitizeWarpRuntimeMetaValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool || value is num) {
      return value;
    }
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) {
        return null;
      }
      final lowered = cleaned.toLowerCase();
      if (lowered.contains('://') ||
          lowered.contains('private-key') ||
          lowered.contains('access-token') ||
          lowered.contains('bearer ')) {
        return '[redacted]';
      }
      return cleaned.length > 500 ? cleaned.substring(0, 500) : cleaned;
    }
    if (value is Map) {
      return _sanitizeWarpRuntimeMeta(
        value.map((key, child) => MapEntry(key.toString(), child)),
      );
    }
    if (value is Iterable) {
      return value
          .take(20)
          .map(_sanitizeWarpRuntimeMetaValue)
          .where((item) => item != null)
          .toList(growable: false);
    }
    return value.toString();
  }

  String _sanitizeWarpRuntimeMessage(String value) {
    final sanitized = _sanitizeWarpRuntimeMetaValue(value);
    if (sanitized is! String) {
      return '';
    }
    return sanitized.length > 240 ? sanitized.substring(0, 240) : sanitized;
  }

  bool _isUnsafeWarpMetaKey(String key) {
    final lowered = key.toLowerCase().replaceAll('-', '_');
    const unsafeFragments = <String>[
      'account',
      'auth',
      'cookie',
      'key',
      'private',
      'secret',
      'subscription',
      'token',
      'url',
      'warp_config',
      'wireguard',
    ];
    return unsafeFragments.any((fragment) => lowered.contains(fragment));
  }

  String _profileName({
    required HostPlatform hostPlatform,
    required String profileRevision,
  }) {
    final revision = profileRevision.isEmpty ? 'managed' : profileRevision;
    final normalized = revision.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    return 'pokrov-${hostPlatform.name}-$normalized';
  }

  Future<String> _deviceName(HostPlatform hostPlatform) async {
    var host = '';
    try {
      host = _trim(
        (await deviceNameResolver?.call(hostPlatform)) ?? '',
        80,
      );
    } catch (_) {
      // A platform identity is helpful presentation data, never a bootstrap
      // dependency. Fall back without exposing a native channel failure.
    }
    if (host.isEmpty) {
      host = _safeLocalHostName();
    }
    final normalized = host.trim().toLowerCase();
    final usefulHost = normalized.isEmpty ||
            normalized == 'localhost' ||
            normalized == 'localhost.localdomain' ||
            normalized == 'device'
        ? ''
        : host.trim();
    return _trim(
      usefulHost.isEmpty
          ? 'POKROV ${hostPlatform.label}'
          : 'POKROV ${hostPlatform.label} $usefulHost',
      120,
    );
  }

  String _userAgent(HostPlatform hostPlatform) =>
      'POKROV/${hostPlatform.name}/$pokrovClientVersion';

  String _generateInstallId(HostPlatform hostPlatform) {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final suffix = base64Url.encode(bytes).replaceAll('=', '');
    return '${hostPlatform.name}-$suffix';
  }

  String _safeLocalHostName() {
    try {
      return _trim(Platform.localHostname, 48);
    } catch (_) {
      return 'device';
    }
  }

  String _errorMessageForResponse(String text, int statusCode) {
    if (statusCode >= HttpStatus.internalServerError && statusCode < 600) {
      return 'Сервис подготовки временно недоступен. Попробуйте ещё раз.';
    }
    if (statusCode >= HttpStatus.badRequest &&
        statusCode < HttpStatus.internalServerError) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          final detailValue = decoded['detail'];
          final detail = detailValue is Map
              ? _readText(detailValue['message'] ?? detailValue['detail'])
              : _readText(detailValue);
          final safeDetail = _safeUserCopy(detail);
          if (safeDetail.isNotEmpty) {
            return safeDetail;
          }
        }
      } catch (_) {
        // Non-JSON error bodies are not consumer copy.
      }
    }
    return 'Не удалось выполнить запрос. Попробуйте ещё раз.';
  }

  String _safeUserCopy(String value) {
    final normalized = _trim(value.replaceAll(RegExp(r'\s+'), ' '), 180);
    if (normalized.isEmpty) {
      return '';
    }
    final unsafeMarker = RegExp(
      r'(?:\b[a-z][a-z0-9+.-]*://|\b(?:\d{1,3}\.){3}\d{1,3}\b|:\d{1,5}\b|\b(?:port|порт)\s*[:=]?\s*\d+|\b(?:exception|stack(?:trace)?|traceback|platformexception|socketexception|handshake|protocol|vless|vmess|trojan|socks|(?:access|refresh)[ _-]?token|token|secret|password|authorization|bearer|cookie|session|api[ _-]?key|credential)\b)',
      caseSensitive: false,
    );
    return unsafeMarker.hasMatch(normalized) ? '' : normalized;
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          item,
        ),
      );
    }
    return const <String, dynamic>{};
  }

  String _readText(Object? value, {String fallback = ''}) {
    final text = value == null ? '' : value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final text = value == null ? '' : value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  double _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    final parsed = _readInt(value);
    return parsed == 0 ? null : parsed;
  }

  Uri? _readOptionalUri(Object? value) {
    final text = _readText(value);
    if (text.isEmpty) {
      return null;
    }
    return Uri.tryParse(text);
  }

  String _trim(String value, int maxLength) {
    final text = value.trim();
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength);
  }
}

abstract interface class SupportTicketService {
  Future<List<SupportTicketThread>> listTickets({
    required HostPlatform hostPlatform,
    int limit,
  });

  Future<SupportTicketThread> getTicket({
    required HostPlatform hostPlatform,
    required int ticketId,
  });

  Future<SupportTicketReceipt> createTicket({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required String statusLabel,
    required String body,
    String subject,
    Map<String, Object?> diagnostics,
  });

  Future<SupportTicketThread> sendMessage({
    required HostPlatform hostPlatform,
    required int ticketId,
    required String body,
    RouteMode? routeMode,
    String statusLabel,
    Map<String, Object?> diagnostics,
  });
}

class SupportTicketThread {
  const SupportTicketThread({
    required this.id,
    required this.status,
    required this.statusTitle,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    required this.closedAt,
    required this.lastMessagePreview,
    required this.messages,
  });

  final int id;
  final String status;
  final String statusTitle;
  final String subject;
  final String createdAt;
  final String updatedAt;
  final String closedAt;
  final String lastMessagePreview;
  final List<SupportTicketMessage> messages;

  bool get isClosed => status.toLowerCase() == 'closed';
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderRole,
    required this.body,
    required this.mediaType,
    required this.mediaFileId,
    required this.mediaPayload,
    required this.createdAt,
  });

  final int id;
  final int ticketId;
  final String senderRole;
  final String body;
  final String mediaType;
  final String mediaFileId;
  final String mediaPayload;
  final String createdAt;

  bool get isUser => senderRole.toLowerCase() == 'user';
}

class SupportTicketReceipt {
  const SupportTicketReceipt({
    required this.ticketId,
    required this.statusTitle,
    required this.messageCount,
  });

  final int ticketId;
  final String statusTitle;
  final int messageCount;
}

class SupportTicketFailure implements Exception {
  const SupportTicketFailure(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class SupportBundleTransferService {
  bool get supportBundleEncryptionConfigured;

  Future<SupportModeActivation> redeemSupportMode({
    required HostPlatform hostPlatform,
    required String activationCode,
    required String appVersion,
    required String buildNumber,
  });

  Future<SupportBundleExportResult> exportSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
  });

  Future<SupportBundleDeliveryResult> deliverSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
    required String caseSummary,
    int? ticketId,
  });
}

abstract interface class SupportBundleExportDestination {
  Future<bool> save({
    required HostPlatform hostPlatform,
    required EncryptedSupportBundle bundle,
  });
}

final class PokrovPlatformSupportBundleExportDestination
    implements SupportBundleExportDestination {
  const PokrovPlatformSupportBundleExportDestination();

  static const _androidChannel = MethodChannel('space.pokrov/support-export');

  @override
  Future<bool> save({
    required HostPlatform hostPlatform,
    required EncryptedSupportBundle bundle,
  }) async {
    if (hostPlatform == HostPlatform.android) {
      final selected = await _androidChannel.invokeMethod<String?>(
        'saveEncryptedBundle',
        <String, Object?>{
          'bytes': bundle.bytes,
          'name': bundle.suggestedFileName,
        },
      );
      return selected != null && selected.isNotEmpty;
    }
    if (hostPlatform == HostPlatform.windows) {
      final location = await getSaveLocation(
        suggestedName: bundle.suggestedFileName,
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'POKROV encrypted support bundle',
            extensions: <String>['pokrov-support'],
          ),
        ],
      );
      if (location == null) {
        return false;
      }
      final file = XFile.fromData(
        bundle.bytes,
        mimeType: 'application/vnd.pokrov.support-bundle+json',
        name: bundle.suggestedFileName,
      );
      await file.saveTo(location.path);
      return true;
    }
    throw const SupportBundleTransferFailure(
      'support_export_unsupported',
      'Экспорт диагностики недоступен на этой платформе.',
    );
  }
}

final class SupportModeActivation {
  SupportModeActivation({
    required Map<String, Object?> signedPolicy,
    required this.policy,
  }) : signedPolicy = Map<String, Object?>.unmodifiable(signedPolicy);

  final Map<String, Object?> signedPolicy;
  final VerifiedSupportCollectionPolicy policy;
}

class SupportBundleTransferFailure implements Exception {
  const SupportBundleTransferFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class PokrovFileSupportBundleOutbox implements SupportBundleEncryptedOutbox {
  const PokrovFileSupportBundleOutbox({
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  static const _maximumEnvelopeBytes = 2621440;
  final Future<Directory> Function() _directoryResolver;

  Future<Directory> _root() async {
    final support = await _directoryResolver();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}support-bundle-outbox',
    );
    await root.create(recursive: true);
    return root;
  }

  String _validateDiagnosticId(String value) {
    if (!RegExp(r'^diag-[a-f0-9]{24}$').hasMatch(value)) {
      throw const SupportBundleTransferFailure(
        'outbox_name_invalid',
        'Не удалось безопасно сохранить пакет диагностики.',
      );
    }
    return value;
  }

  Future<File> _file(String diagnosticId) async {
    final root = await _root();
    final safeId = _validateDiagnosticId(diagnosticId);
    return File('${root.path}${Platform.pathSeparator}$safeId.pokrov-support');
  }

  @override
  Future<StoredEncryptedSupportBundle?> load(String diagnosticId) async {
    final file = await _file(diagnosticId);
    if (!await file.exists()) {
      return null;
    }
    final length = await file.length();
    if (length <= 0 || length > _maximumEnvelopeBytes) {
      throw const SupportBundleTransferFailure(
        'outbox_content_invalid',
        'Сохраненный пакет диагностики поврежден.',
      );
    }
    final bytes = await file.readAsBytes();
    _validateEncryptedEnvelope(bytes, diagnosticId);
    return StoredEncryptedSupportBundle(
      diagnosticId: diagnosticId,
      reference: file.path,
      bytes: bytes,
    );
  }

  @override
  Future<StoredEncryptedSupportBundle> save(
    EncryptedSupportBundle bundle,
  ) async {
    final existing = await load(bundle.diagnosticId);
    if (existing != null) {
      return existing;
    }
    final file = await _file(bundle.diagnosticId);
    final next = File('${file.path}.next');
    final bytes = bundle.bytes;
    _validateEncryptedEnvelope(bytes, bundle.diagnosticId);
    if (await next.exists()) {
      await next.delete();
    }
    await next.writeAsBytes(bytes, flush: true);
    try {
      await next.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) {
        try {
          await next.delete();
        } on FileSystemException {
          // The canonical encrypted object already won the race. A stale
          // temporary file is harmless and will be replaced on the next save.
        }
      } else {
        rethrow;
      }
    }
    return (await load(bundle.diagnosticId))!;
  }

  @override
  Future<void> remove(StoredEncryptedSupportBundle stored) async {
    final file = await _file(stored.diagnosticId);
    if (file.path != stored.reference) {
      throw const SupportBundleTransferFailure(
        'outbox_reference_invalid',
        'Не удалось безопасно удалить отправленный пакет.',
      );
    }
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _validateEncryptedEnvelope(List<int> bytes, String diagnosticId) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      const expectedFields = <String>{
        'algorithm',
        'bundle_sha256',
        'ciphertext_b64',
        'diagnostic_id',
        'ephemeral_public_key_b64',
        'mac_b64',
        'manifest_sha256',
        'nonce_b64',
        'recipient_key_id',
        'schema_version',
      };
      final actualFields = decoded is Map
          ? decoded.keys.map((key) => key.toString()).toSet()
          : const <String>{};
      if (decoded is! Map ||
          actualFields.length != expectedFields.length ||
          !actualFields.containsAll(expectedFields) ||
          decoded['schema_version'] != 1 ||
          decoded['algorithm'] != 'X25519-HKDF-SHA256-AES-256-GCM' ||
          decoded['diagnostic_id'] != diagnosticId ||
          decoded['bundle_sha256'] is! String ||
          decoded['ciphertext_b64'] is! String ||
          decoded['ephemeral_public_key_b64'] is! String ||
          decoded['mac_b64'] is! String ||
          decoded['manifest_sha256'] is! String ||
          decoded['nonce_b64'] is! String ||
          decoded['recipient_key_id'] is! String) {
        throw const FormatException('invalid encrypted envelope');
      }
    } on Object {
      throw const SupportBundleTransferFailure(
        'outbox_content_invalid',
        'Сохраненный пакет диагностики поврежден.',
      );
    }
  }
}

class _SupportBundleSignedKeySetCache {
  const _SupportBundleSignedKeySetCache(this._directoryResolver);

  final Future<Directory> Function() _directoryResolver;

  Future<File> _file() async {
    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}support-key-set-v1.json',
    );
  }

  Future<Map<String, Object?>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists() || await file.length() > 24 * 1024) {
        return null;
      }
      final value = jsonDecode(await file.readAsString());
      return value is Map
          ? value.map((key, item) => MapEntry(key.toString(), item))
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> write(Map<String, Object?> envelope) async {
    final file = await _file();
    final next = File('${file.path}.next');
    await next.writeAsString(jsonEncode(envelope), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await next.rename(file.path);
  }
}

Map<String, String> _compiledSupportSigningKeys() {
  if (pokrovSupportSigningKeyId.isEmpty ||
      pokrovSupportSigningPublicKeyB64.isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{
    pokrovSupportSigningKeyId: pokrovSupportSigningPublicKeyB64,
  };
}

class AppFirstSupportTicketService
    implements SupportTicketService, SupportBundleTransferService {
  AppFirstSupportTicketService({
    String apiBaseUrl = 'https://app.pokrov.space',
    Future<Directory> Function()? supportDirectoryResolver,
    HttpClient Function()? httpClientFactory,
    Future<void> Function(Duration delay)? delayScheduler,
    Duration connectionTimeout = const Duration(seconds: 8),
    Duration requestTimeout = const Duration(seconds: 15),
    int maxRequestAttempts = 3,
    Map<String, String>? supportSigningPublicKeysById,
    SupportBundleEncryptedOutbox? supportBundleOutbox,
    SupportBundleExportDestination? supportBundleExportDestination,
  })  : _supportSigningPublicKeysById = Map<String, String>.unmodifiable(
          supportSigningPublicKeysById ?? _compiledSupportSigningKeys(),
        ),
        _supportBundleOutbox = supportBundleOutbox ??
            PokrovFileSupportBundleOutbox(
              directoryResolver: supportDirectoryResolver,
            ),
        _supportBundleExportDestination = supportBundleExportDestination ??
            const PokrovPlatformSupportBundleExportDestination(),
        _supportKeySetCache = _SupportBundleSignedKeySetCache(
          supportDirectoryResolver ?? getApplicationSupportDirectory,
        ),
        _bootstrapper = AppFirstRuntimeBootstrapper(
          apiBaseUrl: apiBaseUrl,
          supportDirectoryResolver: supportDirectoryResolver,
          httpClientFactory: httpClientFactory,
          delayScheduler: delayScheduler,
          connectionTimeout: connectionTimeout,
          requestTimeout: requestTimeout,
          maxRequestAttempts: maxRequestAttempts,
        );

  final AppFirstRuntimeBootstrapper _bootstrapper;
  final Map<String, String> _supportSigningPublicKeysById;
  final SupportBundleEncryptedOutbox _supportBundleOutbox;
  final SupportBundleExportDestination _supportBundleExportDestination;
  final _SupportBundleSignedKeySetCache _supportKeySetCache;

  static const _defaultSubject = 'Поддержка POKROV';
  static const _diagnosticMediaType = 'app_diagnostics';
  static const _allowedDiagnosticKeys = <String>{
    'app_version',
    'platform',
    'os_version',
    'route_mode',
    'connection_status',
    'entitlement_state',
    'recent_error_category',
    'selected_region',
    'selected_country',
    'dns_health',
    'uplink_health',
    'device_name',
    'app_build',
    'enhanced_protection_state',
    'enhanced_protection_consent',
    'enhanced_protection_available',
    'enhanced_protection_error',
  };

  @override
  bool get supportBundleEncryptionConfigured =>
      _supportSigningPublicKeysById.isNotEmpty;

  @override
  Future<SupportModeActivation> redeemSupportMode({
    required HostPlatform hostPlatform,
    required String activationCode,
    required String appVersion,
    required String buildNumber,
  }) async {
    if (!supportBundleEncryptionConfigured ||
        (hostPlatform != HostPlatform.android &&
            hostPlatform != HostPlatform.windows)) {
      throw const SupportBundleTransferFailure(
        'support_mode_unavailable',
        'Временный режим поддержки недоступен в этой сборке.',
      );
    }
    final response = await _requestJsonWithSession(
      method: 'POST',
      path: '/api/client/support/mode/redeem',
      hostPlatform: hostPlatform,
      body: <String, Object?>{
        'app_version': appVersion,
        'build_number': buildNumber,
        'code': activationCode.trim(),
        'platform': hostPlatform.name,
      },
    );
    final rawPolicy = response['policy'];
    if (rawPolicy is! Map) {
      throw const SupportBundleTransferFailure(
        'support_mode_policy_invalid',
        'Сервер вернул недействительную политику поддержки.',
      );
    }
    final envelope = rawPolicy.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    try {
      final policy = await SupportSignedContractVerifier(
        signingPublicKeysById: _supportSigningPublicKeysById,
      ).verifyCollectionPolicy(
        envelope,
        now: DateTime.now().toUtc(),
        platform: hostPlatform.name,
        appVersion: appVersion,
        buildNumber: buildNumber,
      );
      return SupportModeActivation(signedPolicy: envelope, policy: policy);
    } on SupportBundleFailure {
      throw const SupportBundleTransferFailure(
        'support_mode_policy_invalid',
        'Подпись или параметры режима поддержки недействительны.',
      );
    }
  }

  @override
  Future<SupportBundleExportResult> exportSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
  }) async {
    if (!supportBundleEncryptionConfigured) {
      throw const SupportBundleTransferFailure(
        'support_signing_key_unavailable',
        'Подписанный ключ поддержки не настроен в этой сборке.',
      );
    }
    final now = DateTime.now().toUtc();
    final resolution = await _resolveSupportRecipient(
      hostPlatform: hostPlatform,
      now: now,
    );
    final recipient = resolution.recipient;
    if (recipient == null) {
      throw SupportBundleTransferFailure(
        'support_recipient_unavailable',
        resolution.onlineFailure is SupportTicketFailure
            ? (resolution.onlineFailure! as SupportTicketFailure).message
            : 'Не удалось получить проверенный ключ поддержки.',
      );
    }
    final encrypted = await prepared.encrypt(recipient: recipient, now: now);
    final saved = await _supportBundleExportDestination.save(
      hostPlatform: hostPlatform,
      bundle: encrypted,
    );
    return SupportBundleExportResult(
      state: saved
          ? SupportBundleExportState.exported
          : SupportBundleExportState.cancelled,
      fileName: encrypted.suggestedFileName,
    );
  }

  @override
  Future<SupportBundleDeliveryResult> deliverSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
    required String caseSummary,
    int? ticketId,
  }) async {
    if (!supportBundleEncryptionConfigured) {
      throw const SupportBundleTransferFailure(
        'support_signing_key_unavailable',
        'Подписанный ключ поддержки не настроен в этой сборке.',
      );
    }
    final now = DateTime.now().toUtc();
    final resolution = await _resolveSupportRecipient(
      hostPlatform: hostPlatform,
      now: now,
    );
    final recipient = resolution.recipient;
    final onlineFailure = resolution.onlineFailure;
    final existing = await _supportBundleOutbox.load(
      prepared.preview.diagnosticId,
    );
    if (recipient == null && existing == null) {
      throw SupportBundleTransferFailure(
        'support_recipient_unavailable',
        onlineFailure is SupportTicketFailure
            ? onlineFailure.message
            : 'Не удалось получить проверенный ключ поддержки.',
      );
    }
    return SupportBundleDeliveryCoordinator(
      transport: _AppFirstSupportBundleUploadTransport(
        service: this,
        hostPlatform: hostPlatform,
      ),
      outbox: _supportBundleOutbox,
      delayScheduler: _bootstrapper._delayScheduler,
    ).deliver(
      prepared: prepared,
      recipient: recipient,
      now: now,
      caseSummary: _trimForTicket(caseSummary, 500),
      ticketId: ticketId,
    );
  }

  Future<({VerifiedSupportRecipient? recipient, Object? onlineFailure})>
      _resolveSupportRecipient({
    required HostPlatform hostPlatform,
    required DateTime now,
  }) async {
    final verifier = SupportSignedContractVerifier(
      signingPublicKeysById: _supportSigningPublicKeysById,
    );
    VerifiedSupportRecipient? recipient;
    Object? onlineFailure;
    try {
      final envelope = await _requestJsonWithSession(
        method: 'GET',
        path: '/api/client/support/bundles/key-set',
        hostPlatform: hostPlatform,
      );
      final normalized = envelope.map<String, Object?>(
        (key, value) => MapEntry(key, value),
      );
      final keySet = await verifier.verifyKeySet(normalized, now: now);
      recipient = keySet.activeRecipient(now);
      await _supportKeySetCache.write(normalized);
    } on Object catch (error) {
      onlineFailure = error;
      final cached = await _supportKeySetCache.read();
      if (cached != null) {
        try {
          final keySet = await verifier.verifyKeySet(cached, now: now);
          recipient = keySet.activeRecipient(now);
        } on Object {
          recipient = null;
        }
      }
    }
    return (
      recipient: recipient,
      onlineFailure: onlineFailure,
    );
  }

  @override
  Future<List<SupportTicketThread>> listTickets({
    required HostPlatform hostPlatform,
    int limit = 5,
  }) async {
    final boundedLimit = limit.clamp(1, 20);
    final response = await _requestJsonWithSession(
      method: 'GET',
      path: '/api/tickets?limit=$boundedLimit',
      hostPlatform: hostPlatform,
    );
    final rawTickets = response['tickets'];
    if (rawTickets is! List) {
      return const <SupportTicketThread>[];
    }
    return rawTickets
        .map((item) => _ticketThreadFromMap(_bootstrapper._readMap(item)))
        .where((ticket) => ticket.id > 0)
        .toList(growable: false);
  }

  @override
  Future<SupportTicketThread> getTicket({
    required HostPlatform hostPlatform,
    required int ticketId,
  }) async {
    final response = await _requestJsonWithSession(
      method: 'GET',
      path: '/api/tickets/$ticketId',
      hostPlatform: hostPlatform,
    );
    return _ticketThreadFromResponse(response);
  }

  @override
  Future<SupportTicketReceipt> createTicket({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required String statusLabel,
    required String body,
    String subject = _defaultSubject,
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) async {
    final cleanBody = _trimForTicket(body, 2000);
    if (cleanBody.isEmpty) {
      throw const SupportTicketFailure('Сообщение не должно быть пустым.');
    }

    var state = await _bootstrapper._loadOrCreateState(hostPlatform);
    final client = _bootstrapper._createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          final response = await _bootstrapper._requestJson(
            method: 'POST',
            path: '/api/tickets',
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: <String, Object?>{
              'subject': _trimForTicket(subject, 200).isEmpty
                  ? _defaultSubject
                  : _trimForTicket(subject, 200),
              'body': cleanBody,
              'media_type': _diagnosticMediaType,
              'media_payload': _diagnosticsPayload(
                hostPlatform: hostPlatform,
                routeMode: routeMode,
                statusLabel: statusLabel,
                diagnostics: diagnostics,
              ),
            },
          );
          return _receiptFromResponse(response);
        } on BootstrapFailure catch (error) {
          if (attempt == 0 &&
              _bootstrapper._isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          throw SupportTicketFailure(
            error.message,
            statusCode: error.statusCode,
          );
        }
      }

      throw const SupportTicketFailure(
        'POKROV не смог отправить обращение в поддержку.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<SupportTicketThread> sendMessage({
    required HostPlatform hostPlatform,
    required int ticketId,
    required String body,
    RouteMode? routeMode,
    String statusLabel = '',
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) async {
    final cleanBody = _trimForTicket(body, 2000);
    if (cleanBody.isEmpty) {
      throw const SupportTicketFailure('Сообщение не должно быть пустым.');
    }

    final payload = <String, Object?>{
      'body': cleanBody,
    };
    if (diagnostics.isNotEmpty) {
      payload
        ..['media_type'] = _diagnosticMediaType
        ..['media_payload'] = _diagnosticsPayload(
          hostPlatform: hostPlatform,
          routeMode: routeMode ?? RouteMode.allExceptRu,
          statusLabel: statusLabel,
          diagnostics: diagnostics,
        );
    }

    final response = await _requestJsonWithSession(
      method: 'POST',
      path: '/api/tickets/$ticketId/messages',
      hostPlatform: hostPlatform,
      body: payload,
    );
    return _ticketThreadFromResponse(response);
  }

  Future<Map<String, dynamic>> _requestJsonWithSession({
    required String method,
    required String path,
    required HostPlatform hostPlatform,
    Map<String, Object?>? body,
    Map<String, String> headers = const <String, String>{},
    List<int>? rawBody,
    String rawContentType = 'application/octet-stream',
  }) async {
    var state = await _bootstrapper._loadOrCreateState(hostPlatform);
    final client = _bootstrapper._createHttpClient(hostPlatform);
    try {
      for (var attempt = 0; attempt < 2; attempt += 1) {
        if (!state.hasSession) {
          state = await _startTrial(
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
        }

        try {
          return await _bootstrapper._requestJson(
            method: method,
            path: path,
            client: client,
            bearerToken: state.sessionToken,
            hostPlatform: hostPlatform,
            body: body,
            headers: headers,
            rawBody: rawBody,
            rawContentType: rawContentType,
          );
        } on BootstrapFailure catch (error) {
          if (attempt == 0 &&
              _bootstrapper._isSessionFailure(error.statusCode)) {
            state = await _startTrial(
              state: state.copyWith(
                sessionToken: '',
                accountId: '',
              ),
              hostPlatform: hostPlatform,
              client: client,
            );
            continue;
          }
          throw SupportTicketFailure(
            error.message,
            statusCode: error.statusCode,
          );
        }
      }
    } finally {
      client.close(force: true);
    }

    throw const SupportTicketFailure(
      'POKROV не смог обновить чат поддержки.',
    );
  }

  Future<_StoredBootstrapState> _startTrial({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) {
    return _bootstrapper._startTrial(
      state: state,
      hostPlatform: hostPlatform,
      client: client,
    );
  }

  SupportTicketThread _ticketThreadFromResponse(Map<String, dynamic> response) {
    return _ticketThreadFromMap(_bootstrapper._readMap(response['ticket']));
  }

  SupportTicketThread _ticketThreadFromMap(Map<String, dynamic> ticket) {
    final rawMessages = ticket['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .map((item) => _ticketMessageFromMap(_bootstrapper._readMap(item)))
            .where((message) => message.id > 0 || message.body.isNotEmpty)
            .toList(growable: false)
        : const <SupportTicketMessage>[];
    return SupportTicketThread(
      id: _readInt(ticket['id']),
      status: _bootstrapper._readText(ticket['status']),
      statusTitle: _bootstrapper._readText(ticket['status_title']),
      subject: _bootstrapper._readText(ticket['subject']),
      createdAt: _bootstrapper._readText(ticket['created_at']),
      updatedAt: _bootstrapper._readText(ticket['updated_at']),
      closedAt: _bootstrapper._readText(ticket['closed_at']),
      lastMessagePreview:
          _bootstrapper._readText(ticket['last_message_preview']),
      messages: messages,
    );
  }

  SupportTicketMessage _ticketMessageFromMap(Map<String, dynamic> message) {
    return SupportTicketMessage(
      id: _readInt(message['id']),
      ticketId: _readInt(message['ticket_id']),
      senderRole: _bootstrapper._readText(message['sender_role']),
      body: _bootstrapper._readText(message['body']),
      mediaType: _bootstrapper._readText(message['media_type']),
      mediaFileId: _bootstrapper._readText(message['media_file_id']),
      mediaPayload: _bootstrapper._readText(message['media_payload']),
      createdAt: _bootstrapper._readText(message['created_at']),
    );
  }

  SupportTicketReceipt _receiptFromResponse(Map<String, dynamic> response) {
    final ticket = _bootstrapper._readMap(response['ticket']);
    final messages =
        ticket['messages'] is List ? (ticket['messages'] as List).length : 0;
    return SupportTicketReceipt(
      ticketId: _readInt(ticket['id']),
      statusTitle: _bootstrapper._readText(ticket['status_title']).isEmpty
          ? _bootstrapper._readText(ticket['status'])
          : _bootstrapper._readText(ticket['status_title']),
      messageCount: messages,
    );
  }

  String _diagnosticsPayload({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required String statusLabel,
    required Map<String, Object?> diagnostics,
  }) {
    final safe = <String, Object?>{
      'app_version': pokrovClientVersion,
      'platform': hostPlatform.name,
      'route_mode': _routeModeDiagnosticValue(routeMode),
      'connection_status': _safeDiagnosticValue(statusLabel),
    };

    for (final entry in diagnostics.entries) {
      final key = entry.key.trim();
      if (!_allowedDiagnosticKeys.contains(key)) {
        continue;
      }
      final value = _safeDiagnosticValue(entry.value);
      if (value != null) {
        safe[key] = value;
      }
    }

    final encoded = jsonEncode(safe);
    if (encoded.length <= 1900) {
      return encoded;
    }
    return jsonEncode(<String, Object?>{
      'app_version': safe['app_version'],
      'platform': safe['platform'],
      'route_mode': safe['route_mode'],
      'connection_status': safe['connection_status'],
    });
  }

  Object? _safeDiagnosticValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool || value is int || value is double) {
      return value;
    }
    final text = _trimForTicket(value.toString(), 160);
    if (text.isEmpty || _looksSensitive(text)) {
      return null;
    }
    return text;
  }

  bool _looksSensitive(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('://') ||
        normalized.contains('vless') ||
        normalized.contains('vmess') ||
        normalized.contains('trojan') ||
        normalized.contains('wireguard') ||
        normalized.contains('subscription') ||
        normalized.contains('access_key') ||
        normalized.contains('secret') ||
        normalized.contains('token=') ||
        normalized.contains('uuid=') ||
        normalized.contains('server=');
  }

  String _routeModeDiagnosticValue(RouteMode routeMode) {
    return switch (routeMode) {
      RouteMode.allExceptRu => 'all_except_ru',
      RouteMode.fullTunnel => 'full_tunnel',
      RouteMode.selectedApps => 'selected_apps',
      RouteMode.excludedApps => 'excluded_apps',
    };
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  String _trimForTicket(String value, int maxLength) {
    final text = value.trim();
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength);
  }
}

class _AppFirstSupportBundleUploadTransport
    implements SupportBundleUploadTransport {
  const _AppFirstSupportBundleUploadTransport({
    required this.service,
    required this.hostPlatform,
  });

  final AppFirstSupportTicketService service;
  final HostPlatform hostPlatform;

  @override
  Future<SupportBundleUploadTicket> issue(
    SupportBundleUploadRequest request,
  ) async {
    final response = await service._requestJsonWithSession(
      method: 'POST',
      path: '/api/client/support/bundles/upload-tickets',
      hostPlatform: hostPlatform,
      body: <String, Object?>{
        'bundle_id': request.bundleId,
        'case_summary': request.caseSummary,
        'content_type': request.contentType,
        'idempotency_key': request.idempotencyKey,
        'sha256': request.sha256,
        'size_bytes': request.sizeBytes,
        if (request.ticketId != null) 'ticket_id': request.ticketId,
      },
    );
    final uploadId = (response['upload_id'] ?? '').toString();
    final uploadTicket = (response['upload_ticket'] ?? '').toString();
    final ticketId = service._readInt(response['ticket_id']);
    final nextOffset = service._readInt(response['next_offset']);
    final status = (response['status'] ?? '').toString();
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uploadId) ||
        uploadTicket.isEmpty ||
        ticketId <= 0 ||
        nextOffset < 0 ||
        !<String>{
          'issued',
          'uploading',
          'queued',
          'validated',
        }.contains(status)) {
      throw const SupportBundleTransferFailure(
        'upload_ticket_invalid',
        'Сервис вернул некорректный тикет загрузки.',
      );
    }
    return SupportBundleUploadTicket(
      uploadId: uploadId,
      uploadTicket: uploadTicket,
      ticketId: ticketId,
      nextOffset: nextOffset,
      status: status,
    );
  }

  @override
  Future<SupportBundleChunkReceipt> putChunk({
    required SupportBundleUploadTicket ticket,
    required int offset,
    required String sha256,
    required List<int> bytes,
  }) async {
    final response = await service._requestJsonWithSession(
      method: 'PUT',
      path: '/api/client/support/bundles/uploads/${ticket.uploadId}/chunks',
      hostPlatform: hostPlatform,
      headers: <String, String>{
        'X-Pokrov-Upload-Ticket': ticket.uploadTicket,
        'X-Pokrov-Chunk-Offset': '$offset',
        'X-Pokrov-Chunk-Sha256': sha256,
      },
      rawBody: bytes,
    );
    final nextOffset = service._readInt(response['next_offset']);
    if (nextOffset <= offset || response['complete'] is! bool) {
      throw const SupportBundleTransferFailure(
        'chunk_receipt_invalid',
        'Сервис вернул некорректное подтверждение части пакета.',
      );
    }
    return SupportBundleChunkReceipt(
      nextOffset: nextOffset,
      complete: response['complete'] as bool,
    );
  }

  @override
  Future<String> complete(SupportBundleUploadTicket ticket) async {
    final response = await service._requestJsonWithSession(
      method: 'POST',
      path: '/api/client/support/bundles/uploads/${ticket.uploadId}/complete',
      hostPlatform: hostPlatform,
      headers: <String, String>{
        'X-Pokrov-Upload-Ticket': ticket.uploadTicket,
      },
    );
    return (response['status'] ?? '').toString();
  }
}

class _ManagedManifestEnvelope {
  const _ManagedManifestEnvelope({
    required this.payload,
    required this.profileRevision,
    required this.managedManifestPath,
    required this.response,
    required this.verifiedAt,
  });

  final ManagedProfilePayload payload;
  final String profileRevision;
  final String managedManifestPath;
  final Map<String, dynamic> response;
  final DateTime verifiedAt;
}

class _SmartConnectLatencySample {
  const _SmartConnectLatencySample({
    required this.nodeCode,
    required this.rttMs,
    required this.cpuPenalty,
    required this.backendPenalty,
    required this.rank,
  });

  final String nodeCode;
  final int rttMs;
  final int cpuPenalty;
  final int backendPenalty;
  final int rank;

  int get effectiveScore => rttMs + cpuPenalty + backendPenalty;
}

class _SafeRuBridgeEndpoint {
  const _SafeRuBridgeEndpoint({required this.id, required this.label});

  final String id;
  final String label;
}

class _SmartConnectSelection {
  const _SmartConnectSelection({
    required this.selectedNodeCode,
    required this.previousNodeCode,
    required this.stickinessApplied,
  });

  final String selectedNodeCode;
  final String previousNodeCode;
  final bool stickinessApplied;
}

class _SmartConnectResolution {
  const _SmartConnectResolution({
    required this.selectedNodeCode,
    required this.selection,
    required this.samplePayload,
  });

  const _SmartConnectResolution.empty()
      : selectedNodeCode = '',
        selection = null,
        samplePayload = const <Map<String, Object?>>[];

  final String selectedNodeCode;
  final _SmartConnectSelection? selection;
  final List<Map<String, Object?>> samplePayload;
}

class _StoredBootstrapState {
  const _StoredBootstrapState({
    required this.installId,
    required this.sessionToken,
    required this.accountId,
    required this.managedManifestPath,
    required this.profileRevision,
    this.refreshToken = '',
    this.expectsSecureSessionToken = false,
    this.sourceSchemaVersion = _appFirstBootstrapStateVersion,
  });

  final String installId;
  final String sessionToken;
  final String accountId;
  final String managedManifestPath;
  final String profileRevision;
  final String refreshToken;
  final bool expectsSecureSessionToken;
  final int sourceSchemaVersion;

  bool get hasSession => sessionToken.trim().isNotEmpty;
  bool get requiresSchemaMigration => sourceSchemaVersion == 0;

  _StoredBootstrapState copyWith({
    String? installId,
    String? sessionToken,
    String? accountId,
    String? managedManifestPath,
    String? profileRevision,
    String? refreshToken,
    bool? expectsSecureSessionToken,
  }) {
    return _StoredBootstrapState(
      installId: installId ?? this.installId,
      sessionToken: sessionToken ?? this.sessionToken,
      accountId: accountId ?? this.accountId,
      managedManifestPath: managedManifestPath ?? this.managedManifestPath,
      profileRevision: profileRevision ?? this.profileRevision,
      refreshToken: refreshToken ?? this.refreshToken,
      expectsSecureSessionToken:
          expectsSecureSessionToken ?? this.expectsSecureSessionToken,
      sourceSchemaVersion: sourceSchemaVersion,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': _appFirstBootstrapStateVersion,
      'install_id': installId,
      if (sessionToken.trim().isNotEmpty || expectsSecureSessionToken)
        'session_token_storage': 'secure',
      'account_id': accountId,
      'managed_manifest_path': managedManifestPath,
      'profile_revision': profileRevision,
    };
  }

  static _StoredBootstrapState fromJson(Map<String, dynamic> json) {
    final sourceSchemaVersion = _appFirstBootstrapSchemaVersion(json);
    return _StoredBootstrapState(
      installId: (json['install_id'] ?? '').toString(),
      sessionToken: (json['session_token'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      managedManifestPath: (json['managed_manifest_path'] ??
              AppFirstRuntimeBootstrapper._defaultManagedManifestPath)
          .toString(),
      profileRevision: (json['profile_revision'] ?? '').toString(),
      expectsSecureSessionToken:
          (json['session_token_storage'] ?? '').toString() == 'secure',
      sourceSchemaVersion: sourceSchemaVersion,
    );
  }
}

int _appFirstBootstrapSchemaVersion(Map<String, dynamic> json) {
  if (!json.containsKey('schema_version')) {
    return 0;
  }
  final version = json['schema_version'];
  if (version is int && version == _appFirstBootstrapStateVersion) {
    return version;
  }
  throw const BootstrapFailure(
    'Эта версия POKROV не может безопасно прочитать сохраненное состояние. '
    'Обновите приложение или восстановите совместимую версию.',
  );
}

class _ClientRuleSetCatalog {
  const _ClientRuleSetCatalog({
    required this.definitions,
    required this.domainRuleSetTags,
    required this.ipRuleSetTags,
  });

  static const empty = _ClientRuleSetCatalog(
    definitions: <_ClientRuleSetDefinition>[],
    domainRuleSetTags: <String>[],
    ipRuleSetTags: <String>[],
  );

  final List<_ClientRuleSetDefinition> definitions;
  final List<String> domainRuleSetTags;
  final List<String> ipRuleSetTags;

  bool get isEmpty => definitions.isEmpty;

  List<String> get allRuleSetTags => <String>[
        ...domainRuleSetTags,
        ...ipRuleSetTags,
      ];
}

class _ClientRuleSetDefinition {
  const _ClientRuleSetDefinition({
    required this.tag,
    required this.path,
  });

  final String tag;
  final String path;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': 'local',
      'tag': tag,
      'format': 'binary',
      'path': path,
    };
  }
}

class _CachedRuleSetSpec {
  const _CachedRuleSetSpec({
    required this.tag,
    required this.fileName,
    required this.appliesToDns,
    required this.urls,
  });

  final String tag;
  final String fileName;
  final bool appliesToDns;
  final List<String> urls;

  _ClientRuleSetDefinition toDefinition(String path) {
    return _ClientRuleSetDefinition(
      tag: tag,
      path: path,
    );
  }
}
