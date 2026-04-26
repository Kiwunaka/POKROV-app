import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
    List<String> selectedAppIds = const [],
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

class AppFirstRuntimeBootstrapper implements ManagedProfileBootstrapper {
  AppFirstRuntimeBootstrapper({
    this.apiBaseUrl = 'https://api.pokrov.space',
    Future<Directory> Function()? supportDirectoryResolver,
    HttpClient Function()? httpClientFactory,
    Future<void> Function(Duration delay)? delayScheduler,
    this.connectionTimeout = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 15),
    this.maxRequestAttempts = 3,
    Duration allExceptRuRuleSetCacheMaxAge = const Duration(hours: 6),
    List<String> Function(String tag)? allExceptRuRuleSetUrlsResolver,
  })  : _supportDirectoryResolver =
            supportDirectoryResolver ?? getApplicationSupportDirectory,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _delayScheduler = delayScheduler ?? Future<void>.delayed,
        _allExceptRuRuleSetCacheMaxAge = allExceptRuRuleSetCacheMaxAge,
        _allExceptRuRuleSetUrlsResolver = allExceptRuRuleSetUrlsResolver;

  final String apiBaseUrl;
  final Future<Directory> Function() _supportDirectoryResolver;
  final HttpClient Function() _httpClientFactory;
  final Future<void> Function(Duration delay) _delayScheduler;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final int maxRequestAttempts;
  final Duration _allExceptRuRuleSetCacheMaxAge;
  final List<String> Function(String tag)? _allExceptRuRuleSetUrlsResolver;

  static const _appVersion = '0.2.0-beta.1';
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
    List<String> selectedAppIds = const [],
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
          await _syncRoutePolicy(
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            selectedAppIds: selectedAppIds,
            client: client,
          );
          final manifest = await _fetchManagedManifest(
            state: state,
            hostPlatform: hostPlatform,
            routeMode: routeMode,
            client: client,
          );
          state = state.copyWith(
            profileRevision: manifest.profileRevision,
            managedManifestPath: manifest.managedManifestPath,
          );
          await _saveState(hostPlatform, state);
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
        'POKROV could not finish preparing this device.',
      );
    } finally {
      client.close(force: true);
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
    if (!await file.exists()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const BootstrapFailure(
        'This device needs to be set up again before it can connect.',
      );
    }
    return _StoredBootstrapState.fromJson(
      decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Future<void> _saveState(
    HostPlatform hostPlatform,
    _StoredBootstrapState state,
  ) async {
    final file = await _stateFile(hostPlatform);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  Future<File> _stateFile(HostPlatform hostPlatform) async {
    final supportDirectory = await _supportDirectoryResolver();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'app-first-session-${hostPlatform.name}.json',
    );
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
    final sessionToken = _readText(session['session_token']);
    if (sessionToken.isEmpty) {
      throw const BootstrapFailure(
        'POKROV could not finish preparing this device.',
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
    required List<String> selectedAppIds,
    required HttpClient client,
  }) async {
    final normalizedSelectedApps = routeMode == RouteMode.selectedApps
        ? selectedAppIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false)
        : const <String>[];
    try {
      await _requestJson(
        method: 'POST',
        path: '/api/client/route-policy',
        client: client,
        bearerToken: state.sessionToken,
        hostPlatform: hostPlatform,
        body: <String, Object?>{
          'route_mode': _routeModeWireValue(routeMode),
          'selected_apps': normalizedSelectedApps,
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
    required HttpClient client,
  }) async {
    final path = state.managedManifestPath.isEmpty
        ? _defaultManagedManifestPath
        : state.managedManifestPath;
    final response = await _requestJson(
      method: 'GET',
      path: path,
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
        'POKROV could not finish setup because the connection details were incomplete.',
      );
    }
    final supportContext = _readMap(response['support_context']);
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
        supportContext: supportContext,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
      materializedForRuntime: true,
      routeMode: routeMode,
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
        clientRuleSetCatalog: clientRuleSetCatalog,
      );
      return const JsonEncoder.withIndent('  ').convert(sanitized);
    }
    final runtimeConfig = _buildRuntimeConfig(
      baseConfig: baseConfig,
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      supportContext: supportContext,
      clientRuleSetCatalog: clientRuleSetCatalog,
    );
    return const JsonEncoder.withIndent('  ').convert(runtimeConfig);
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
    return sanitized;
  }

  Map<String, dynamic> _buildRuntimeConfig({
    required Map<String, dynamic> baseConfig,
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
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
        routeMode: routeMode,
        clientRuleSetCatalog: clientRuleSetCatalog,
      ),
      'inbounds': _buildInbounds(
        hostPlatform: hostPlatform,
        routeMode: routeMode,
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
      'Managed profile did not include a safe Android full-tunnel outbound after direct-bypass sanitization.',
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
    required RouteMode routeMode,
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
      ..putIfAbsent('final', () => 'dns-remote')
      ..['independent_cache'] = dns['independent_cache'] ?? false;
    return dns;
  }

  List<Map<String, dynamic>> _buildInbounds({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
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
      tunInbound['include_package'] = const <String>[];
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
      ..['final'] = finalOutboundTag;
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
      routeMode: RouteMode.allExceptRu,
      clientRuleSetCatalog: clientRuleSetCatalog,
    );
    config['route'] = _buildRouteBlock(
      baseRoute: config['route'],
      directTag: directTag,
      dnsOutboundTag: dnsOutboundTag,
      finalOutboundTag: finalOutboundTag,
      hostPlatform: hostPlatform,
      routeMode: RouteMode.allExceptRu,
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
            'POKROV downloaded an empty routing update from ${uri.host}.',
          );
        }
        return bytes;
      } on SocketException catch (error) {
        final failure = BootstrapFailure(
          'A network error blocked a routing update from ${uri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException catch (error) {
        final failure = BootstrapFailure(
          'A secure connection error blocked a routing update from ${uri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        final failure = BootstrapFailure(
          'POKROV timed out while downloading a routing update from ${uri.host}.',
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
          'POKROV could not download a routing update from ${uri.host}.',
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
          'POKROV received an unexpected response while preparing this device.',
        );
      } on SocketException catch (error) {
        final failure = BootstrapFailure(
          'A network error blocked setup while contacting ${requestUri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on HandshakeException catch (error) {
        final failure = BootstrapFailure(
          'A secure connection error blocked setup while contacting ${requestUri.host}: $error',
        );
        if (attempt >= maxRequestAttempts - 1) {
          throw failure;
        }
        lastFailure = failure;
      } on TimeoutException {
        final failure = BootstrapFailure(
          'POKROV timed out while contacting ${requestUri.host}.',
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
        const BootstrapFailure('POKROV could not reach the setup service.');
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
      return 'Setup request failed with status $statusCode.';
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

  String _readText(Object? value) {
    final text = value == null ? '' : value.toString().trim();
    return text;
  }

  String _trim(String value, int maxLength) {
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

class _StoredBootstrapState {
  const _StoredBootstrapState({
    required this.installId,
    required this.sessionToken,
    required this.accountId,
    required this.managedManifestPath,
    required this.profileRevision,
  });

  final String installId;
  final String sessionToken;
  final String accountId;
  final String managedManifestPath;
  final String profileRevision;

  bool get hasSession => sessionToken.trim().isNotEmpty;

  _StoredBootstrapState copyWith({
    String? installId,
    String? sessionToken,
    String? accountId,
    String? managedManifestPath,
    String? profileRevision,
  }) {
    return _StoredBootstrapState(
      installId: installId ?? this.installId,
      sessionToken: sessionToken ?? this.sessionToken,
      accountId: accountId ?? this.accountId,
      managedManifestPath: managedManifestPath ?? this.managedManifestPath,
      profileRevision: profileRevision ?? this.profileRevision,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'install_id': installId,
      'session_token': sessionToken,
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
