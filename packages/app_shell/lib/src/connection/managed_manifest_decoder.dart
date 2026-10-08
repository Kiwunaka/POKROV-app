part of '../../app_first_runtime_bootstrap.dart';

extension _ManagedManifestDecoder on AppFirstRuntimeBootstrapper {
  Future<_ManagedManifestEnvelope> _decodeManagedManifestResponse(Map<String, dynamic> response, {
    required _StoredBootstrapState state, required HostPlatform hostPlatform, required RouteMode routeMode,
    required List<String> selectedApps, required String normalizedPreferredNode, required String preferredVariantId,
    required String path, required DateTime verifiedAt, HttpClient? client, bool offline = false,
    String tcpFallbackFromRevision = '', Set<RuntimeTransportFeature> runtimeFeatures = const {},
    String? coreRelease, String selectedCandidateRef = '', String preferredCountryCode = '',
  }) async {
    final transportCatalog = response.containsKey('transport_catalog')
        ? decodeManagedTransportCatalog(response['transport_catalog'], platform: hostPlatform,
            clientRelease: '$pokrovClientVersion+$pokrovClientBuildNumber', runtimeFeatures: runtimeFeatures,
            coreRelease: coreRelease, requestedNodeCode: normalizedPreferredNode,
            requestedCandidateRef: selectedCandidateRef)
        : null;
    if (selectedCandidateRef.isNotEmpty && transportCatalog == null) {
      throw const TransportManifestFailure('transport_catalog_selection_mismatch');
    }
    if (preferredCountryCode.isNotEmpty &&
        (transportCatalog == null || (transportCatalog.selected.warpMode != 'warp_direct' &&
          transportCatalog.selected.nodeCountryCode(
            transportCatalog.candidates) != preferredCountryCode))) {
      throw const TransportManifestFailure('transport_catalog_selection_mismatch');
    }
    if (transportCatalog != null &&
        (transportCatalog.revision != _readText(response['profile_revision']) ||
         transportCatalog.selected.profileRef != _readText(response['transport_profile']))) {
      throw const TransportManifestFailure('transport_catalog_profile_mismatch');
    }

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
      _traceBootstrap('managed_response', 'fail', reason: 'config_format',
        operationalCode: 'API-008');
      throw BootstrapFailure(
        'This device received connection details it cannot use yet.',
      );
    }

    final configPayload = response['config_payload'];
    if (configPayload == null) {
      _traceBootstrap('managed_response', 'fail', reason: 'config_payload_missing',
        operationalCode: 'API-008');
      throw const BootstrapFailure(
        'POKROV не смог завершить настройку: данных подключения недостаточно.',
      );
    }
    void validateMaterial(TransportCandidate? candidate, String kind, String format, Object? raw) {
      if (format != 'singbox-json' || raw == null) {
        throw const TransportManifestFailure('transport_catalog_profile_mismatch');
      }
      if (candidate != null && (candidate.protocol, candidate.transport, candidate.protection) != switch (kind) {
        'reality' => ('vless', 'tcp', 'reality'),
        'grpc' => ('vless', 'grpc', 'tls'),
        'xhttp' => ('vless', 'xhttp', candidate.protection),
        'awg31' => ('awg', 'udp', 'awg31'),
        'hysteria2' => ('hysteria2', 'udp', 'tls'),
        'warp_direct' => ('warp', 'udp', 'warp'),
        _ => ('', '', ''),
      }) {
        throw const TransportManifestFailure('transport_catalog_profile_mismatch');
      }
      if (candidate?.warpMode == 'warp_direct') {
        try {
          validatePokrovDirectWarpProfile(raw);
        } on Object {
          throw const TransportManifestFailure('transport_catalog_profile_mismatch');
        }
      }
      if (candidate?.transport == 'xhttp') {
        try {
          final config = _readMap(raw is String ? jsonDecode(raw) : raw);
          final graph = (config['outbounds'] as List).map(_readMap).toList();
          final ingressTags = graph.map((outbound) => _readText(outbound['detour']))
              .where((tag) => tag.isNotEmpty).toSet();
          final outbounds = graph.where((outbound) => outbound['type'] == 'vless' &&
              !ingressTags.contains(_readText(outbound['tag']))).toList();
          if (outbounds.isEmpty) throw const FormatException();
          for (final outbound in outbounds) {
            final tls = _readMap(outbound['tls']);
            final transport = _readMap(outbound['transport']);
            final reality = _readMap(tls['reality'])['enabled'] == true;
            if (tls['enabled'] != true ||
                (reality ? 'reality' : 'tls') != candidate!.protection ||
                transport['type'] != 'xhttp' ||
                !const {'stream-one', 'stream-up', 'packet-up'}.contains(transport['mode']) ||
                _readText(outbound['flow']).isNotEmpty ||
                (reality && (_readMap(tls['utls'])['enabled'] != true ||
                    tls['alpn'] is! List || (tls['alpn'] as List).firstOrNull != 'h2'))) {
              throw const FormatException();
            }
          }
        } on Object {
          throw const TransportManifestFailure('transport_catalog_profile_mismatch');
        }
      }
    }
    validateMaterial(transportCatalog?.selected, _readText(response['transport_kind']), configFormat, configPayload);
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
    var smartConnect = SmartConnectProfile.tryParse(
      response['smart_connect'],
    );
    if (transportCatalog != null && smartConnect != null) {
      final nodes = transportCatalog.candidates.map((candidate) => candidate.nodeCode).toSet();
      final previous = smartConnect;
      smartConnect = SmartConnectProfile(eligible: previous.eligible,
        fallbackRequired: previous.fallbackRequired, shortlistReason: previous.shortlistReason,
        shortlistLimit: previous.shortlistLimit, shortlistRevision: previous.shortlistRevision,
        transportProfile: previous.transportProfile, profileRevision: previous.profileRevision,
        fallbackOrder: previous.fallbackOrder, stickiness: previous.stickiness,
        shortlist: previous.shortlist.where((node) => nodes.contains(node.code)).toList(growable: false));
    }
    final isOwnedTransportLab = _ownedTransportLabProfiles.contains(
      _readText(response['transport_profile']).trim().toLowerCase(),
    );
    final effectiveSmartConnect = isOwnedTransportLab && transportCatalog == null
        ? null : smartConnect;
    final effectivePreferredNode = isOwnedTransportLab || transportCatalog != null
        ? '' : normalizedPreferredNode;
    final clientRuleSetCatalog = offline ? _ClientRuleSetCatalog.empty
        : await _ensureAllExceptRuRuleSetCatalog(hostPlatform: hostPlatform, routeMode: routeMode, client: client!);

    final fallbackOrder = response['fallback_order'];
    final reportedAsn = _readText(_readMap(response['access_network'])['asn']);
    final accessNetworkAsn = RegExp(r'^AS[0-9]{1,10}$').hasMatch(reportedAsn)
        ? reportedAsn : '';
    final tcpFallbackRevision =
        isOwnedTransportLab &&
            fallbackOrder is List &&
            fallbackOrder.contains('legacy_reality_fallback')
        ? _readText(response['profile_revision'])
        : '';
    Future<ManagedProfilePayload> materialize(Object raw, String kind, TransportCandidate? candidate,
        {String materialRef = ''}) async => ManagedProfilePayload(
      cacheEntryId: ManagedProfileCache.newEntryId(),
      accessNetworkAsn: accessNetworkAsn,
      disableMemoryLimit: hostPlatform == HostPlatform.windows,
      tcpFallbackFromRevision: candidate == null || candidate.candidateRef == transportCatalog?.selectedCandidateRef
          ? tcpFallbackRevision : '',
      source: RuntimeProfileSource(
        revision: _readText(response['profile_revision']),
        origin: RuntimeProfileSourceOrigin.managedManifest,
        protocol: switch (kind) {
          'awg2' => 'awg2', 'awg31' => 'awg31', 'hysteria2' => 'hysteria2',
          'warp_direct' => 'warp',
          'reality' || 'grpc' || 'xhttp' || 'ru_bridge' => 'vless',
          _ => 'unknown',
        },
      ),
      profileName: _profileName(
        hostPlatform: hostPlatform,
        profileRevision: _readText(response['profile_revision']),
      ),
      configPayload: await _materializeRuntimeConfig(
        rawConfigPayload:
            raw is String ? raw : jsonEncode(raw),
        hostPlatform: hostPlatform,
        routeMode: routeMode,
        selectedApps: selectedApps,
        preferredNodeCode: effectivePreferredNode,
        preferredVariantId:
            effectivePreferredNode.isEmpty ? 'direct' : preferredVariantId,
        smartConnect: effectiveSmartConnect,
        supportContext: supportContext,
        clientRuleSetCatalog: clientRuleSetCatalog,
        directWarp: candidate?.warpMode == 'warp_direct',
      ),
      materializedForRuntime: true,
      routeMode: routeMode,
      smartConnect: effectiveSmartConnect,
      transportCatalog: transportCatalog,
      resolvedNodeCode: candidate?.nodeCode ?? effectivePreferredNode,
      materialCandidateRef: materialRef,
      warpPolicy: candidate?.warpMode == 'warp_direct'
          ? pokrovDirectWarpPolicy(state.installId).withUserConsent(warpPolicy.userConsented)
          : warpPolicy,
      freeProfileAccess: FreeProfileAccess.tryParse(
        access: response['access'],
        freeCaps: response['free_caps'],
      ),
    );

    final supplied = response['candidate_materials'];
    final bundled = <String, ManagedProfilePayload>{};
    final ManagedProfilePayload payload;
    if (response.containsKey('candidate_materials')) {
      if (transportCatalog == null || supplied is! List || supplied.isEmpty || supplied.length > 6) {
        throw const TransportManifestFailure('transport_catalog_materials_mismatch');
      }
      for (final value in supplied) {
        final row = _readMap(value);
        final ref = _readText(row['candidate_ref']);
        final admitted = transportCatalog.candidates.where((candidate) => candidate.candidateRef == ref).firstOrNull;
        if (admitted == null || bundled.containsKey(ref) ||
            (bundled.isEmpty && ref != transportCatalog.selectedCandidateRef) ||
            (preferredCountryCode.isNotEmpty && admitted.warpMode != 'warp_direct' && admitted.nodeCountryCode(
                transportCatalog.candidates) != preferredCountryCode)) {
          throw const TransportManifestFailure('transport_catalog_materials_mismatch');
        }
        final kind = _readText(row['transport_kind']);
        final raw = row['config_payload'];
        validateMaterial(admitted, kind, _readText(row['config_format']), raw);
        bundled[ref] = await materialize(raw!, kind, admitted, materialRef: ref);
      }
      payload = bundled[transportCatalog.selectedCandidateRef]!.copyWith(candidateMaterials: bundled);
    } else {
      payload = await materialize(configPayload, _readText(response['transport_kind']), transportCatalog?.selected);
    }

    return _ManagedManifestEnvelope(
      payload: payload,
      response: response,
      verifiedAt: verifiedAt,
      profileRevision: _readText(response['profile_revision']),
      managedManifestPath: path,
    );
  }
}
