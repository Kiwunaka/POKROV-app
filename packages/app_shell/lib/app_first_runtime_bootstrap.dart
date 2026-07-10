import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

InternetAddress? bootstrapDirectAddressForRequest({
  required Uri requestUri,
  required HostPlatform hostPlatform,
}) {
  if (hostPlatform != HostPlatform.android || requestUri.scheme != 'https') {
    return null;
  }

  switch (requestUri.host.toLowerCase()) {
    case 'api.pokrov.space':
      return InternetAddress('82.21.114.104');
    default:
      return null;
  }
}

abstract interface class ManagedProfileBootstrapper {
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
  });
}

typedef SmartConnectLatencyProbe = Future<int?> Function(
  SmartConnectNode node,
);

typedef AppFirstStateFileWriter = Future<void> Function(
  File file,
  String contents,
);

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
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    return _storage.read(key: key);
  }

  @override
  Future<void> writeSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
    required String sessionToken,
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    final value = sessionToken.trim();
    if (value.isEmpty) {
      await deleteSessionToken(
          hostPlatform: hostPlatform, installId: installId);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> deleteSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async {
    final key = _key(hostPlatform: hostPlatform, installId: installId);
    await _storage.delete(key: key);
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
      _values[_key(hostPlatform, installId)];

  @override
  Future<void> writeSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
    required String sessionToken,
  }) async {
    _values[_key(hostPlatform, installId)] = sessionToken.trim();
  }

  @override
  Future<void> deleteSessionToken({
    required HostPlatform hostPlatform,
    required String installId,
  }) async {
    _values.remove(_key(hostPlatform, installId));
  }
}

abstract interface class AppFirstAccountActionService {
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
    String channel = 'beta',
  });
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

  Future<ClientNotificationInbox> fetchClientNotifications({
    required HostPlatform hostPlatform,
    String after = '',
  });

  Future<bool> markClientNotificationsRead({
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
    Map<String, Object?> safeDiagnostics = const <String, Object?>{},
  });
}

class BootstrapFailure implements Exception {
  const BootstrapFailure(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

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

double _clientDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
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
}

class ClientLocationCity {
  const ClientLocationCity({
    required this.code,
    required this.city,
    required this.healthScore,
    required this.latencyMs,
    required this.premium,
    required this.load,
  });

  final String code;
  final String city;
  final double healthScore;
  final int? latencyMs;
  final bool premium;
  final double load;

  factory ClientLocationCity.fromJson(Map<String, dynamic> json) {
    return ClientLocationCity(
      code: _clientText(json['code']),
      city: _clientText(json['city']),
      healthScore: _clientDouble(
        json['healthScore'] ?? json['health_score'],
      ),
      latencyMs: _clientNullableInt(json['latencyMs'] ?? json['latency_ms']),
      premium: _clientBool(json['premium']),
      load: _clientDouble(json['load']),
    );
  }
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
  });

  final String lane;
  final String expiresAt;
  final int daysLeft;
  final bool autoRenew;
  final Uri? renewUrl;
  final List<ClientSubscriptionPlan> plans;
  final Map<String, Object?> trafficPolicy;

  factory ClientSubscriptionInfo.fromJson(Map<String, dynamic> json) {
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

class ClientSupportAssistantReply {
  const ClientSupportAssistantReply({
    required this.reply,
    required this.shouldEscalate,
    required this.suggestedActions,
  });

  final String reply;
  final bool shouldEscalate;
  final List<ClientSupportAssistantAction> suggestedActions;

  factory ClientSupportAssistantReply.fromJson(Map<String, dynamic> json) {
    return ClientSupportAssistantReply(
      reply: _clientText(json['reply']),
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
      mode: mode.isEmpty ? localPolicy.mode : mode,
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
    this.wheelState = AppFirstBonusFeatureState.wheelDisabled,
    this.calendarState = AppFirstBonusFeatureState.calendarDisabled,
    this.referralSummary = AppFirstReferralSummary.empty,
    this.promoSlots = AppFirstPromoSlots.empty,
    this.historyItems = const <AppFirstBonusHistoryItem>[],
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
  final AppFirstBonusFeatureState wheelState;
  final AppFirstBonusFeatureState calendarState;
  final AppFirstReferralSummary referralSummary;
  final AppFirstPromoSlots promoSlots;
  final List<AppFirstBonusHistoryItem> historyItems;

  bool get channelBonusClaimed => channelBonusClaimedAt.trim().isNotEmpty;
}

class AppFirstBonusRewardResult {
  const AppFirstBonusRewardResult({
    required this.ok,
    required this.rewardDays,
    required this.rewardKey,
    required this.expiryAt,
    required this.summary,
  });

  final bool ok;
  final int rewardDays;
  final String rewardKey;
  final String expiryAt;
  final AppFirstBonusSummary summary;
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
  );

  final bool ok;
  final bool enabled;
  final String state;
  final String featureFlag;
  final bool featureFlagEnabled;
  final String actionEndpoint;
  final String lastActionAt;
  final int streakMonths;

  bool get canRun =>
      ok && enabled && featureFlagEnabled && actionEndpoint.trim().isNotEmpty;

  String get statusLabel {
    if (canRun) {
      return 'Готово';
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
    required this.slots,
  });

  static const empty = AppFirstPromoSlots(
    surface: 'app',
    accessState: '',
    remoteAvailable: false,
    fallbackBehavior: 'contextual_only_when_remote_unavailable',
    mode: 'whitelist_slots',
    slots: <AppFirstPromoSlot>[],
  );

  final String surface;
  final String accessState;
  final bool remoteAvailable;
  final String fallbackBehavior;
  final String mode;
  final List<AppFirstPromoSlot> slots;

  List<AppFirstPromoSlot> get visibleSlots => slots
      .where(
        (slot) =>
            slot.enabled &&
            (slot.title.trim().isNotEmpty || slot.body.trim().isNotEmpty),
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
    this.imageUrl = '',
    required this.ctaLabel,
    required this.ctaHref,
    this.placement = '',
    this.dismissible = true,
    this.startsAt = '',
    this.endsAt = '',
    required this.kind,
    required this.goal,
  });

  final String slotId;
  final String contentId;
  final bool enabled;
  final String title;
  final String body;
  final String imageUrl;
  final String ctaLabel;
  final String ctaHref;
  final String placement;
  final bool dismissible;
  final String startsAt;
  final String endsAt;
  final String kind;
  final String goal;
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
      HostPlatform.ios || HostPlatform.macos => ClientAppUpdateInfo.none,
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
    channel: 'beta',
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

  bool get shouldPrompt =>
      url.trim().isNotEmpty &&
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
        AppFirstAccountActionService,
        AppFirstBonusActionService,
        AppFirstWarpActionService,
        AppFirstReleaseActionService,
        AppFirstNodePreferenceService,
        AppFirstClientDataService {
  AppFirstRuntimeBootstrapper({
    this.apiBaseUrl = 'https://api.pokrov.space',
    Future<Directory> Function()? supportDirectoryResolver,
    HttpClient Function()? httpClientFactory,
    Future<void> Function(Duration delay)? delayScheduler,
    this.connectionTimeout = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 15),
    this.smartConnectProbeTimeout = const Duration(milliseconds: 900),
    this.maxRequestAttempts = 3,
    Duration allExceptRuRuleSetCacheMaxAge = const Duration(hours: 6),
    List<String> Function(String tag)? allExceptRuRuleSetUrlsResolver,
    this.smartConnectLatencyProbe,
    AppFirstSessionSecretStore? sessionSecretStore,
    AppFirstStateFileWriter? stateFileWriter,
  })  : _supportDirectoryResolver =
            supportDirectoryResolver ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _delayScheduler = delayScheduler ?? Future<void>.delayed,
        _allExceptRuRuleSetCacheMaxAge = allExceptRuRuleSetCacheMaxAge,
        _allExceptRuRuleSetUrlsResolver = allExceptRuRuleSetUrlsResolver,
        _sessionSecretStore =
            sessionSecretStore ?? FlutterSecureAppFirstSessionSecretStore(),
        _stateFileWriter = stateFileWriter ?? _writeAppFirstStateFileAtomically;

  final String apiBaseUrl;
  final Future<Directory> Function() _supportDirectoryResolver;
  final HttpClient Function() _httpClientFactory;
  final Future<void> Function(Duration delay) _delayScheduler;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final Duration smartConnectProbeTimeout;
  final int maxRequestAttempts;
  final Duration _allExceptRuRuleSetCacheMaxAge;
  final List<String> Function(String tag)? _allExceptRuRuleSetUrlsResolver;
  final SmartConnectLatencyProbe? smartConnectLatencyProbe;
  final AppFirstSessionSecretStore _sessionSecretStore;
  final AppFirstStateFileWriter _stateFileWriter;

  static const _appVersion = '1.0.0-beta.3';
  static const _defaultManagedManifestPath = '/api/client/profile/managed';
  static const _androidShellPackageName = 'space.pokrov.pokrov_android_shell';
  static const _allExceptRuRuleSetCacheDirectoryName =
      'all-except-ru-rule-sets';
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
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
  }) async {
    final normalizedSelectedApps = _normalizeSelectedAppIdentifiers(
      selectedApps,
    );
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
          await _syncRoutePolicy(
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            selectedApps: normalizedSelectedApps,
            client: client,
          );
          final manifest = await _fetchManagedManifest(
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            selectedApps: normalizedSelectedApps,
            preferredNodeCode: preferredNodeCode,
            client: client,
          );
          state = state.copyWith(
            profileRevision: manifest.profileRevision,
            managedManifestPath: manifest.managedManifestPath,
          );
          await _saveState(hostPlatform, state);
          await _maybeUploadSmartConnectLatency(
            smartConnect: manifest.payload.smartConnect,
            state: state,
            hostPlatform: hostPlatform,
            client: client,
          );
          return manifest.payload;
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
        'POKROV не смог завершить подготовку устройства.',
      );
    } finally {
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
    Map<String, Object?> safeDiagnostics = const <String, Object?>{},
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw const BootstrapFailure('Support message is required.');
    }
    final response = await _requestClientJsonWithSession(
      hostPlatform: hostPlatform,
      method: 'POST',
      path: '/api/client/support/assistant',
      body: <String, Object?>{
        'message': text,
        'scope': 'support',
        if (ticketId != null) 'ticketId': ticketId,
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
        channel: _readText(update['channel'], fallback: 'beta'),
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
    String channel = 'beta',
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
          final platformLabel = switch (hostPlatform) {
            HostPlatform.android => 'android',
            HostPlatform.windows => 'windows',
            HostPlatform.ios => 'ios',
            HostPlatform.macos => 'macos',
          };
          final query = Uri(
            queryParameters: <String, String>{
              'platform': platformLabel,
              'current_version': currentVersion.trim(),
              'channel': channel.trim().isEmpty ? 'beta' : channel.trim(),
            },
          ).query;
          final response = await _requestJson(
            method: 'GET',
            path: '/api/client/apps?$query',
            client: client,
            bearerToken: state.sessionToken,
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
        'POKROV could not check app updates.',
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
            wheelState: _readBonusFeatureState(
              wheel,
              fallback: AppFirstBonusFeatureState.wheelDisabled,
              actionEndpointKey: 'spin_endpoint',
              lastActionAtKeys: const <String>['last_spin_at'],
            ),
            calendarState: _readBonusFeatureState(
              calendar,
              fallback: AppFirstBonusFeatureState.calendarDisabled,
              actionEndpointKey: 'checkin_endpoint',
              lastActionAtKeys: const <String>[
                'last_checkin_at',
                'last_wheel_spin',
              ],
            ),
            referralSummary: referralSummary,
            promoSlots: promoSlots,
            historyItems: historyItems,
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
      return AppFirstPromoSlots(
        surface: _readText(response['surface']).isEmpty
            ? 'app'
            : _readText(response['surface']),
        accessState: _readText(response['access_state']),
        remoteAvailable: response['remote_available'] == true,
        fallbackBehavior: _readText(response['fallback_behavior']),
        mode: _readText(response['mode']),
        slots: _readListOfMaps(response['slots'])
            .map(
              (slot) => AppFirstPromoSlot(
                slotId: _readText(slot['slot_id']),
                contentId: _readText(slot['content_id']),
                enabled: slot['enabled'] != false,
                title: _readText(slot['title']),
                body: _readText(slot['body']),
                imageUrl: _readText(slot['image_url']),
                ctaLabel: _readText(slot['cta_label']),
                ctaHref: _readText(slot['cta_href']),
                placement: _readText(slot['placement']),
                dismissible: slot['dismissible'] != false,
                startsAt: _readText(slot['starts_at']),
                endsAt: _readText(slot['ends_at']),
                kind: _readText(slot['kind']),
                goal: _readText(slot['goal']),
              ),
            )
            .where((slot) => slot.slotId.isNotEmpty)
            .take(4)
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
    );
  }

  AppFirstBonusFeatureState _readBonusFeatureState(
    Map<String, dynamic> data, {
    required AppFirstBonusFeatureState fallback,
    required String actionEndpointKey,
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

  HttpClient _createHttpClient(HostPlatform hostPlatform) {
    final client = _httpClientFactory()..connectionTimeout = connectionTimeout;
    if (hostPlatform != HostPlatform.android) {
      return client;
    }

    client.connectionFactory =
        (Uri uri, String? proxyHost, int? proxyPort) async {
      if (proxyHost != null && proxyPort != null) {
        return Socket.startConnect(proxyHost, proxyPort);
      }

      final directAddress = bootstrapDirectAddressForRequest(
        requestUri: uri,
        hostPlatform: hostPlatform,
      );
      if (directAddress == null) {
        if (uri.scheme == 'https') {
          final secureTask = await SecureSocket.startConnect(
            uri.host,
            uri.port,
          );
          return ConnectionTask.fromSocket<Socket>(
            secureTask.socket.then<Socket>((socket) => socket),
            secureTask.cancel,
          );
        }
        return Socket.startConnect(uri.host, uri.port);
      }

      final socketTask = await Socket.startConnect(
        directAddress,
        uri.port,
      );
      return ConnectionTask.fromSocket<Socket>(
        socketTask.socket.then<Socket>(
          (socket) => SecureSocket.secure(
            socket,
            host: uri.host,
          ),
        ),
        socketTask.cancel,
      );
    };

    return client;
  }

  Future<_StoredBootstrapState> _loadOrCreateState(
    HostPlatform hostPlatform,
  ) async {
    final existing = await _loadState(hostPlatform);
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
    await _saveState(hostPlatform, created);
    return created;
  }

  Future<_StoredBootstrapState?> _loadState(HostPlatform hostPlatform) async {
    final file = await _stateFile(hostPlatform);
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
    final secureToken = (await _sessionSecretStore.readSessionToken(
              hostPlatform: hostPlatform,
              installId: parsed.installId,
            ) ??
            '')
        .trim();
    if (secureToken.isNotEmpty) {
      if (parsed.sessionToken.isNotEmpty) {
        await _saveState(
            hostPlatform, parsed.copyWith(sessionToken: secureToken));
      }
      await _cleanupStateWriteArtifacts(file);
      return parsed.copyWith(sessionToken: secureToken);
    }
    if (parsed.sessionToken.isNotEmpty) {
      await _sessionSecretStore.writeSessionToken(
        hostPlatform: hostPlatform,
        installId: parsed.installId,
        sessionToken: parsed.sessionToken,
      );
      await _saveState(hostPlatform, parsed);
      await _cleanupStateWriteArtifacts(file);
      return parsed;
    }
    if (parsed.expectsSecureSessionToken) {
      throw const BootstrapFailure(
        'Сохраненная сессия устройства недоступна. Используйте почту или код, '
        'чтобы восстановить доступ.',
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
    await file.parent.create(recursive: true);
    if (state.sessionToken.trim().isNotEmpty) {
      await _sessionSecretStore.writeSessionToken(
        hostPlatform: hostPlatform,
        installId: state.installId,
        sessionToken: state.sessionToken,
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
  }) async {
    final response = await _requestJson(
      method: 'POST',
      path: '/api/client/session/start-trial',
      client: client,
      body: <String, Object?>{
        'install_id': state.installId,
        'device_name': _deviceName(hostPlatform),
        'platform': hostPlatform.name,
        'os_version': _trim(Platform.operatingSystemVersion, 64),
        'app_version': _appVersion,
        'locale': _trim(Platform.localeName, 32),
        'time_zone': _trim(DateTime.now().timeZoneName, 64),
      },
      hostPlatform: hostPlatform,
    );

    final session = _readMap(response['session']);
    final provisioning = _readMap(response['provisioning']);
    final managedManifest = _readMap(provisioning['managed_manifest']);
    final provisioningReady = _readBool(response['sync_ok']) ||
        _readBool(provisioning['sync_ok']) ||
        _readText(provisioning['status']) == 'ready';
    if (!provisioningReady) {
      throw const BootstrapFailure(
        'POKROV еще завершает первый запуск. Попробуйте через минуту.',
      );
    }
    final sessionToken = _readText(session['session_token']);
    if (sessionToken.isEmpty) {
      throw const BootstrapFailure(
        'POKROV не смог завершить подготовку устройства.',
      );
    }

    final accountId = _readText(session['account_id']);
    final managedManifestPath = _readText(managedManifest['url']);

    final nextState = state.copyWith(
      sessionToken: sessionToken,
      accountId: accountId,
      managedManifestPath: managedManifestPath.isEmpty
          ? _defaultManagedManifestPath
          : managedManifestPath,
    );
    await _saveState(hostPlatform, nextState);
    return nextState;
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
    try {
      await _requestJson(
        method: 'POST',
        path: '/api/client/route-policy',
        client: client,
        bearerToken: state.sessionToken,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'route_mode': _routeModeWireValue(routeMode),
          'selected_apps': policySelectedApps,
          'requires_elevated_privileges':
              hostPlatform.supportsSelectedAppsMode &&
                  routeMode == RouteMode.selectedApps,
        },
      );
    } on BootstrapFailure catch (error) {
      if (_isSessionFailure(error.statusCode)) {
        rethrow;
      }
    }
  }

  Future<_ManagedManifestEnvelope> _fetchManagedManifest({
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required String preferredNodeCode,
    required HttpClient client,
  }) async {
    final path = state.managedManifestPath.isEmpty
        ? _defaultManagedManifestPath
        : state.managedManifestPath;
    final normalizedPreferredNode = preferredNodeCode.trim().toLowerCase();
    final requestPath = normalizedPreferredNode.isEmpty
        ? path
        : '$path${path.contains('?') ? '&' : '?'}selected_node_code=${Uri.encodeQueryComponent(normalizedPreferredNode)}';
    final response = await _requestJson(
      method: 'GET',
      path: requestPath,
      client: client,
      bearerToken: state.sessionToken,
      hostPlatform: hostPlatform,
    );

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
    final clientRuleSetCatalog = await _ensureAllExceptRuRuleSetCatalog(
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      client: client,
    );

    final payload = ManagedProfilePayload(
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
        supportContext: supportContext,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
      materializedForRuntime: true,
      routeMode: routeMode,
      smartConnect: smartConnect,
      warpPolicy: warpPolicy,
    );

    return _ManagedManifestEnvelope(
      payload: payload,
      profileRevision: _readText(response['profile_revision']),
      managedManifestPath: path,
    );
  }

  Future<String> _materializeRuntimeConfig({
    required String rawConfigPayload,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required Map<String, dynamic> supportContext,
    required _ClientRuleSetCatalog clientRuleSetCatalog,
  }) async {
    final decoded = jsonDecode(rawConfigPayload);
    if (decoded is! Map) {
      throw const BootstrapFailure(
        'The connection details for this device were incomplete.',
      );
    }

    final baseConfig = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (hostPlatform != HostPlatform.android &&
        _looksRuntimeReady(baseConfig)) {
      final sanitized = _sanitizeRuntimeReadyConfig(
        baseConfig: baseConfig,
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        clientRuleSetCatalog: clientRuleSetCatalog,
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
    return const JsonEncoder.withIndent('  ').convert(runtimeConfig);
  }

  Future<void> _maybeUploadSmartConnectLatency({
    required SmartConnectProfile? smartConnect,
    required _StoredBootstrapState state,
    required HostPlatform hostPlatform,
    required HttpClient client,
  }) async {
    final probe = smartConnectLatencyProbe ?? _probeSmartConnectNode;
    if (smartConnect == null ||
        !smartConnect.eligible ||
        smartConnect.shortlist.isEmpty ||
        !state.hasSession) {
      return;
    }

    final samples = <_SmartConnectLatencySample>[];
    for (final node in smartConnect.shortlist.take(10)) {
      final nodeCode = node.code.trim().toLowerCase();
      if (nodeCode.isEmpty) {
        continue;
      }
      int? rttMs;
      try {
        rttMs = await probe(node);
      } catch (_) {
        continue;
      }
      if (rttMs == null || rttMs < 1 || rttMs > 60000) {
        continue;
      }
      samples.add(
        _SmartConnectLatencySample(
          nodeCode: nodeCode,
          rttMs: rttMs,
          cpuPenalty: node.rankHint.cpuPenalty,
          backendPenalty: node.rankHint.backendPenalty,
          rank: node.rank,
        ),
      );
    }
    if (samples.isEmpty) {
      return;
    }

    final selection = _selectSmartConnectNode(
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
    try {
      await _requestJson(
        method: 'POST',
        path: '/api/client/nodes/select',
        client: client,
        bearerToken: state.sessionToken,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'mode': 'auto',
          'profile_revision': smartConnect.profileRevision,
          'transport_profile': smartConnect.transportProfile,
          'selected_node_code': selection.selectedNodeCode,
          'previous_node_code': selection.previousNodeCode.isEmpty
              ? null
              : selection.previousNodeCode,
          'samples': samplePayload,
        },
      );
    } on BootstrapFailure {
      // Selection is advisory. The existing managed profile remains usable.
    }
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
          'selected_node_code': selection.selectedNodeCode,
          'previous_node_code': selection.previousNodeCode.isEmpty
              ? null
              : selection.previousNodeCode,
          'stickiness_applied': selection.stickinessApplied,
          'samples': samplePayload,
        },
      );
    } on BootstrapFailure {
      // RTT upload is telemetry/stickiness input. It must not block connecting.
    }
  }

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
        ..remove('auto_detect_interface')
        ..remove('override_android_vpn');
      sanitized['route'] = routeCopy;
    }
    if (routeMode == RouteMode.selectedApps) {
      final inbounds = _readListOfMaps(sanitized['inbounds'])
          .map((inbound) => Map<String, dynamic>.from(inbound))
          .toList(growable: true);
      for (final inbound in inbounds) {
        if (_readText(inbound['type']) == 'tun') {
          inbound['include_package'] = selectedApps;
        }
      }
      if (inbounds.isNotEmpty) {
        sanitized['inbounds'] = inbounds;
      }
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
    if (outbounds.isEmpty) {
      throw const BootstrapFailure(
        'The connection details for this device were incomplete.',
      );
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
    final selectorTag = _findOutboundTag(outbounds, 'selector');
    final urlTestTag = _findOutboundTag(outbounds, 'urltest');
    if (proxyOutboundTags.isEmpty &&
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
    final dnsOutboundTag = _ensureAuxiliaryOutbound(
      outbounds,
      existingTags,
      preferredTag: 'dns-out',
      type: 'dns',
    );

    final baseRoute = _readMap(baseConfig['route']);
    var finalOutboundTag = _readText(baseRoute['final']);
    if (!existingTags.contains(finalOutboundTag) ||
        _isAuxiliaryTag(finalOutboundTag)) {
      finalOutboundTag = '';
    }

    if (hostPlatform == HostPlatform.android) {
      _normalizeAndroidOutboundChains(
        outbounds: outbounds,
        proxyOutboundTags: proxyOutboundTags,
        routeMode: routeMode,
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
    if (finalOutboundTag.isEmpty) {
      finalOutboundTag = proxyOutboundTags.first;
    }

    if (hostPlatform == HostPlatform.android) {
      finalOutboundTag = _normalizeAndroidFinalOutboundTag(
        outbounds: outbounds,
        proxyOutboundTags: proxyOutboundTags,
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
          dnsOutboundTag: dnsOutboundTag,
          finalOutboundTag: finalOutboundTag,
          routeMode: routeMode,
          clientRuleSetCatalog: clientRuleSetCatalog,
        ),
      };
      final experimental = _readMap(baseConfig['experimental']);
      if (experimental.isNotEmpty) {
        runtimeConfig['experimental'] = experimental;
      }
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
    return runtimeConfig;
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

    final localBootstrapServerTag = _selectAndroidBootstrapDnsServerTag(
      baseServers,
      directTag: directTag,
    );
    if (baseServers.isNotEmpty && localBootstrapServerTag != null) {
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
      if (routeMode == RouteMode.fullTunnel) {
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
    const directDnsAddress = '1.1.1.1';
    dns['servers'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'tag': remoteServerTag,
        'address': remoteDnsAddress,
        'address_resolver': directServerTag,
        'detour': finalOutboundTag,
      },
      <String, dynamic>{
        'tag': directServerTag,
        'address': directDnsAddress,
        'address_resolver': localServerTag,
        'detour': directTag,
      },
      <String, dynamic>{
        'tag': localServerTag,
        'address': 'local',
        'detour': directTag,
      },
    ];
    dns['rules'] = <Map<String, dynamic>>[
      if (serverDomains.isNotEmpty)
        <String, dynamic>{
          'domain': serverDomains,
          'server': directServerTag,
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
    required String dnsOutboundTag,
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

    final hasDnsRule = existingRules.any(
      (rule) =>
          _readText(rule['protocol']).toLowerCase() == 'dns' &&
          _readText(rule['outbound']) == dnsOutboundTag,
    );
    if (!hasDnsRule) {
      existingRules.insert(0, <String, dynamic>{
        'protocol': 'dns',
        'outbound': dnsOutboundTag,
      });
    }

    final hasDnsPortRule = existingRules.any(
      (rule) =>
          rule['port'] == 53 && _readText(rule['outbound']) == dnsOutboundTag,
    );
    if (!hasDnsPortRule) {
      existingRules.insert(0, <String, dynamic>{
        'port': 53,
        'outbound': dnsOutboundTag,
      });
    }

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

    route
      ..['auto_detect_interface'] = true
      ..['override_android_vpn'] = true
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

  void _normalizeAndroidOutboundChains({
    required List<Map<String, dynamic>> outbounds,
    required List<String> proxyOutboundTags,
    required RouteMode routeMode,
    required String directTag,
  }) {
    if (routeMode != RouteMode.fullTunnel) {
      return;
    }

    final safeProxyTags = proxyOutboundTags
        .where((tag) => tag.isNotEmpty && tag != directTag)
        .toList(growable: false);
    for (var pass = 0; pass < outbounds.length + 1; pass += 1) {
      final safeTags = _computeAndroidSafeOutboundTags(
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
    if (routeMode != RouteMode.fullTunnel) {
      return currentFinalOutboundTag;
    }

    final safeTags = _computeAndroidSafeOutboundTags(
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

  Set<String> _computeAndroidSafeOutboundTags({
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
    return _readText(server['address']).toLowerCase() == 'local' ||
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

  List<Map<String, dynamic>> _buildInbounds({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required List<String> selectedApps,
    required Map<String, dynamic> supportContext,
  }) {
    final ipVersionPreference =
        _readText(supportContext['ip_version_preference']).toLowerCase();
    final tunInbound = <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'mtu': 9000,
      'auto_route': true,
      'strict_route': true,
      'endpoint_independent_nat': true,
      'stack': hostPlatform == HostPlatform.android ? 'mixed' : 'system',
      'sniff': true,
    };
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
      tunInbound['inet6_address'] = 'fdfe:dcba:9876::1/126';
      tunInbound['domain_strategy'] = 'ipv6_only';
    } else if (ipVersionPreference == 'ipv4_only') {
      tunInbound['inet4_address'] = '172.19.0.1/28';
      tunInbound['domain_strategy'] = 'ipv4_only';
    } else {
      tunInbound['inet4_address'] = '172.19.0.1/28';
      tunInbound['inet6_address'] = 'fdfe:dcba:9876::1/126';
      tunInbound['domain_strategy'] = 'prefer_ipv4';
    }
    if (hostPlatform == HostPlatform.android &&
        routeMode == RouteMode.selectedApps) {
      tunInbound['include_package'] = selectedApps;
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
        'sniff': true,
        'sniff_override_destination': true,
        'domain_strategy': 'ipv4_only',
      },
      <String, dynamic>{
        'type': 'direct',
        'tag': 'dns-in',
        'listen': '127.0.0.1',
        'listen_port': 16450,
      },
    ];
  }

  Map<String, dynamic> _buildRouteBlock({
    required Object? baseRoute,
    required String directTag,
    required String dnsOutboundTag,
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
    final hasDnsInboundRule = rules.any(
      (rule) =>
          _readText(rule['inbound']) == 'dns-in' &&
          _readText(rule['outbound']) == dnsOutboundTag,
    );
    if (hostPlatform != HostPlatform.android && !hasDnsInboundRule) {
      rules.insert(0, <String, dynamic>{
        'inbound': 'dns-in',
        'outbound': dnsOutboundTag,
      });
    }
    final hasDnsPortRule = rules.any(
      (rule) =>
          rule['port'] == 53 && _readText(rule['outbound']) == dnsOutboundTag,
    );
    if (!hasDnsPortRule) {
      rules.insert(0, <String, dynamic>{
        'port': 53,
        'outbound': dnsOutboundTag,
      });
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
        outboundTag: finalOutboundTag,
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
          selectedProcessNames.isNotEmpty ? directTag : finalOutboundTag;
    if (hostPlatform != HostPlatform.android) {
      route['auto_detect_interface'] = true;
    }
    if (hostPlatform == HostPlatform.windows) {
      route['find_process'] = true;
    }
    return route;
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
    final dnsOutboundTag = _ensureAuxiliaryOutbound(
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
      rules.insert(0, <String, dynamic>{
        'inbound': const <String>['tun-in'],
        'package_name': const <String>[_androidShellPackageName],
        'outbound': directTag,
      });
    }
  }

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
      rules.add(<String, dynamic>{
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
      if (_readText(server['address']).toLowerCase() == 'local' &&
          _readText(server['detour']) == directTag) {
        final tag = _readText(server['tag']);
        if (tag.isNotEmpty) {
          return tag;
        }
      }
    }
    for (final server in servers) {
      if (_readText(server['detour']) == directTag) {
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
      final address = _readText(server['address']).toLowerCase();
      if (address.isEmpty || address == 'local') {
        continue;
      }
      if (address == '1.1.1.1' ||
          address == 'udp://1.1.1.1' ||
          address == 'tls://1.1.1.1' ||
          address == 'https://1.1.1.1/dns-query') {
        return '1.1.1.1';
      }
    }
    return '1.1.1.1';
  }

  bool _isProxyTransportOutbound(Map<String, dynamic> outbound) {
    final type = _readText(outbound['type']).toLowerCase();
    return !const {'direct', 'block', 'dns', 'selector', 'urltest'}
        .contains(type);
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
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
        }
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
      } on SocketException catch (error) {
        final failure = BootstrapFailure(
          'Сеть не дала обновить правила с ${uri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException catch (error) {
        final failure = BootstrapFailure(
          'Не удалось проверить TLS-соединение с ${uri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        final failure = BootstrapFailure(
          'POKROV не дождался обновления правил от ${uri.host}.',
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
        BootstrapFailure(
          'POKROV не смог скачать обновление правил от ${uri.host}.',
        );
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    required HostPlatform hostPlatform,
    required HttpClient client,
    String bearerToken = '',
    Map<String, Object?>? body,
  }) async {
    BootstrapFailure? lastFailure;
    final requestUri = Uri.parse(apiBaseUrl).resolve(path);
    for (var attempt = 0; attempt < maxRequestAttempts; attempt += 1) {
      try {
        final request = await client.openUrl(
          method,
          requestUri,
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          _userAgent(hostPlatform),
        );
        if (bearerToken.isNotEmpty) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $bearerToken',
          );
        }
        if (body != null) {
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.write(jsonEncode(body));
        }

        final response = await request.close().timeout(requestTimeout);
        final text = await utf8.decoder.bind(response).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final failure = BootstrapFailure(
            _errorMessageForResponse(text, response.statusCode),
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
        );
      } on SocketException catch (error) {
        final failure = BootstrapFailure(
          'Сеть не дала подготовить устройство через ${requestUri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException catch (error) {
        final failure = BootstrapFailure(
          'Не удалось проверить соединение с ${requestUri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        final failure = BootstrapFailure(
          'POKROV не дождался ответа от ${requestUri.host}.',
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
            'POKROV не смог связаться с сервисом подготовки.');
  }

  bool _isSessionFailure(int? statusCode) =>
      statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.forbidden ||
      statusCode == HttpStatus.notFound;

  bool _shouldRetryStatus(int statusCode) =>
      statusCode == HttpStatus.requestTimeout ||
      statusCode == HttpStatus.tooManyRequests ||
      statusCode == HttpStatus.badGateway ||
      statusCode == HttpStatus.serviceUnavailable ||
      statusCode == HttpStatus.gatewayTimeout;

  Duration _retryDelayForAttempt(int attempt) {
    final baseMs = 350 * (attempt + 1) * (attempt + 1);
    return Duration(milliseconds: baseMs);
  }

  String _routeModeWireValue(RouteMode routeMode) {
    switch (routeMode) {
      case RouteMode.selectedApps:
        return 'selected_apps';
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

  String _deviceName(HostPlatform hostPlatform) {
    final host = _safeLocalHostName();
    return _trim('POKROV ${hostPlatform.label} $host', 120);
  }

  String _userAgent(HostPlatform hostPlatform) =>
      'POKROV/${hostPlatform.name}/$_appVersion';

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
    if (text.trim().isEmpty) {
      return 'Сервис подготовки ответил с ошибкой $statusCode.';
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final detail = _readText(decoded['detail']);
        if (detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Keep the raw fallback below when the response is not JSON.
    }
    return _trim(text.replaceAll(RegExp(r'\s+'), ' '), 280);
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

class AppFirstSupportTicketService implements SupportTicketService {
  AppFirstSupportTicketService({
    String apiBaseUrl = 'https://api.pokrov.space',
    Future<Directory> Function()? supportDirectoryResolver,
    HttpClient Function()? httpClientFactory,
    Future<void> Function(Duration delay)? delayScheduler,
    Duration connectionTimeout = const Duration(seconds: 8),
    Duration requestTimeout = const Duration(seconds: 15),
    int maxRequestAttempts = 3,
  }) : _bootstrapper = AppFirstRuntimeBootstrapper(
          apiBaseUrl: apiBaseUrl,
          supportDirectoryResolver: supportDirectoryResolver,
          httpClientFactory: httpClientFactory,
          delayScheduler: delayScheduler,
          connectionTimeout: connectionTimeout,
          requestTimeout: requestTimeout,
          maxRequestAttempts: maxRequestAttempts,
        );

  final AppFirstRuntimeBootstrapper _bootstrapper;

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
      'app_version': AppFirstRuntimeBootstrapper._appVersion,
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

class _ManagedManifestEnvelope {
  const _ManagedManifestEnvelope({
    required this.payload,
    required this.profileRevision,
    required this.managedManifestPath,
  });

  final ManagedProfilePayload payload;
  final String profileRevision;
  final String managedManifestPath;
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

class _StoredBootstrapState {
  const _StoredBootstrapState({
    required this.installId,
    required this.sessionToken,
    required this.accountId,
    required this.managedManifestPath,
    required this.profileRevision,
    this.expectsSecureSessionToken = false,
  });

  final String installId;
  final String sessionToken;
  final String accountId;
  final String managedManifestPath;
  final String profileRevision;
  final bool expectsSecureSessionToken;

  bool get hasSession => sessionToken.trim().isNotEmpty;

  _StoredBootstrapState copyWith({
    String? installId,
    String? sessionToken,
    String? accountId,
    String? managedManifestPath,
    String? profileRevision,
    bool? expectsSecureSessionToken,
  }) {
    return _StoredBootstrapState(
      installId: installId ?? this.installId,
      sessionToken: sessionToken ?? this.sessionToken,
      accountId: accountId ?? this.accountId,
      managedManifestPath: managedManifestPath ?? this.managedManifestPath,
      profileRevision: profileRevision ?? this.profileRevision,
      expectsSecureSessionToken:
          expectsSecureSessionToken ?? this.expectsSecureSessionToken,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'install_id': installId,
      if (sessionToken.trim().isNotEmpty || expectsSecureSessionToken)
        'session_token_storage': 'secure',
      'account_id': accountId,
      'managed_manifest_path': managedManifestPath,
      'profile_revision': profileRevision,
    };
  }

  static _StoredBootstrapState fromJson(Map<String, dynamic> json) {
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
    );
  }
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
