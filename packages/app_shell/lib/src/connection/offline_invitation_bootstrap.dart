part of '../../app_first_runtime_bootstrap.dart';

class OfflineInvitationManagedProfile {
  OfflineInvitationManagedProfile._(this.payload, this._authority, this._receiver);
  final ManagedProfilePayload payload;
  final VerifiedOfflineInvitation _authority;
  final OfflineInvitationReceiver _receiver;
  void requireLive() {
    try {
      _authority.requireLive(_receiver.now);
    } on OfflineInvitationFailure {
      throw const BootstrapFailure('Срок приглашения истёк.', statusCode: 403,
          code: 'offline_invitation_expired');
    }
  }
}

extension OfflineInvitationBootstrap on AppFirstRuntimeBootstrapper {
  OfflineInvitationReceiver get _receiver => _invitationReceiver ??
      (throw const OfflineInvitationFailure('trust_unconfigured'));

  Future<OfflineInvitationRequest> createOfflineInvitationRequest({required HostPlatform hostPlatform,
      required RouteMode routeMode, required bool consent, required String coreRelease,
      required Set<RuntimeTransportFeature> runtimeFeatures, required bool Function() operationIsCurrent}) async {
    if (routeMode != RouteMode.fullTunnel || transportManifestEnabled) {
      throw const OfflineInvitationFailure('mode_unsupported');
    }
    final state = await _loadOrCreateState(hostPlatform);
    if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
    if (state.hasSession || state.accountId.isNotEmpty) throw const OfflineInvitationFailure('existing_account');
    return _receiver.createRequest(installId: state.installId, platform: hostPlatform.name, consent: consent,
      clientRelease: '$pokrovClientVersion+$pokrovClientBuildNumber', coreRelease: coreRelease,
      runtimeFeatures: runtimeFeatures.map((feature) => feature.wireName).toList(), routeMode: 'full_tunnel',
      operationIsCurrent: operationIsCurrent);
  }

  Future<void> importOfflineInvitation({required HostPlatform hostPlatform, required RouteMode routeMode,
      required String packet, required Set<RuntimeTransportFeature> runtimeFeatures,
      required String coreRelease, required bool Function() operationIsCurrent}) async {
    if (routeMode != RouteMode.fullTunnel || transportManifestEnabled) {
      throw const OfflineInvitationFailure('mode_unsupported');
    }
    final file = await _stateFile(hostPlatform);
    await _withAppFirstStateFileLock(file, () async {
      final state = await _loadStateFromFile(hostPlatform, file);
      if (state == null) throw const OfflineInvitationFailure('request_missing');
      if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
      await _receiver.importPacket(platform: hostPlatform.name, installId: state.installId,
          packet: packet, operationIsCurrent: operationIsCurrent, beforeCommit: (authority) async {
        final recipient = authority.recipient;
        if (state.hasSession && (state.accountId != recipient['account_id'] ||
            state.sessionToken != (recipient['session'] as Map)['access_token'])) {
          throw const OfflineInvitationFailure('existing_account');
        }
        if (state.hasSession) return; // Same request is consumed once, not rearmed.
        final pair = _sessionPairFromResponse({'session': recipient['session']})!;
        final next = state.copyWith(accountId: recipient['account_id'] as String,
            sessionToken: pair.accessToken, refreshToken: pair.refreshToken, expectsSecureSessionToken: true,
            invitationId: authority.inviteId,
            invitationPendingUntil: authority.expiresAt.millisecondsSinceEpoch ~/ 1000);
        // Admit actual normal material before identity or invitation consumption.
        await _invitationProfile(authority, next, hostPlatform, routeMode, runtimeFeatures, coreRelease);
        authority.requireLive(_receiver.now);
        if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
        await _persistStateToFile(hostPlatform: hostPlatform, file: file, state: next);
        if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
      });
    });
  }

  Future<void> completeOfflineInvitationConnect(HostPlatform platform, {
      required bool Function() operationIsCurrent}) async {
    // Called only after the normal native evidence reducer proves connection.
    final file = await _stateFile(platform);
    await _withAppFirstStateFileLock(file, () async {
      final state = await _loadStateFromFile(platform, file);
      if (state == null || state.invitationId.isEmpty || !operationIsCurrent()) return;
      await _persistStateToFile(hostPlatform: platform, file: file,
          state: state.copyWith(invitationId: '', invitationPendingUntil: 0));
    });
  }

  Future<void> cancelOfflineInvitation(HostPlatform platform) async {
    final file = await _stateFile(platform);
    await _withAppFirstStateFileLock(file, () async {
      final state = await _loadStateFromFile(platform, file);
      if (state == null) return;
      await _receiver.cancel(platform: platform.name, installId: state.installId);
      await _persistStateToFile(hostPlatform: platform, file: file,
          state: state.copyWith(invitationId: '', invitationPendingUntil: 0));
    });
  }

  Future<OfflineInvitationManagedProfile?> openOfflineInvitationProfile(ManagedProfileCacheInputs inputs, {
      required Set<RuntimeTransportFeature> runtimeFeatures, required String? coreRelease,
      required bool Function() operationIsCurrent}) async {
    if (_invitationReceiver == null) return null;
    final state = await _loadState(inputs.hostPlatform);
    if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
    if (state == null || !state.hasSession) return null;
    final authority = await _receiver.open(platform: inputs.hostPlatform.name, installId: state.installId,
        accountId: state.accountId, accessToken: state.sessionToken);
    if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
    if (authority == null) {
      if (state.invitationId.isNotEmpty) {
        final file = await _stateFile(inputs.hostPlatform);
        await _withAppFirstStateFileLock(file, () async {
          final current = await _loadStateFromFile(inputs.hostPlatform, file);
          if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
          if (current?.accountId == state.accountId && current?.installId == state.installId &&
              current?.sessionToken == state.sessionToken) {
            await _persistStateToFile(hostPlatform: inputs.hostPlatform, file: file,
                state: current!.copyWith(invitationId: '', invitationPendingUntil: 0));
          }
        });
      }
      return null;
    }
    final recipient = authority.recipient;
    if (state.accountId != recipient['account_id'] ||
        state.sessionToken != (recipient['session'] as Map)['access_token']) return null;
    if (transportManifestEnabled || inputs.routeMode != RouteMode.fullTunnel || coreRelease == null) {
      throw const OfflineInvitationFailure('mode_unsupported');
    }
    final payload = await _invitationProfile(authority, state, inputs.hostPlatform, inputs.routeMode,
        runtimeFeatures, coreRelease);
    if (!operationIsCurrent()) throw const ConnectionOperationSuperseded();
    final candidate = payload.materialCandidate!;
    if ((inputs.preferredCandidateRef.isNotEmpty && inputs.preferredCandidateRef != candidate.candidateRef) ||
        (inputs.preferredNodeCode.isNotEmpty && inputs.preferredNodeCode != candidate.nodeCode) ||
        (inputs.preferredCountryCode.isNotEmpty && inputs.preferredCountryCode != candidate.countryCode)) {
      throw const OfflineInvitationFailure('selection_mismatch');
    }
    authority.requireLive(_receiver.now);
    return OfflineInvitationManagedProfile._(payload, authority, _receiver);
  }

  Future<ManagedProfilePayload> _invitationProfile(VerifiedOfflineInvitation authority,
      _StoredBootstrapState state, HostPlatform platform, RouteMode routeMode,
      Set<RuntimeTransportFeature> features, String coreRelease) async {
    if (authority.request['route_mode'] != 'full_tunnel' || routeMode != RouteMode.fullTunnel) {
      throw const OfflineInvitationFailure('mode_unsupported');
    }
    final response = _readMap(authority.recipient['managed_response']);
    final catalog = decodeManagedTransportCatalog(response['transport_catalog'], platform: platform,
        clientRelease: '$pokrovClientVersion+$pokrovClientBuildNumber', runtimeFeatures: features,
        coreRelease: coreRelease);
    if (catalog.candidates.length != 1 || catalog.selected.warpMode != null) {
      throw const OfflineInvitationFailure('material_scope_invalid');
    }
    final raw = _readMap(response['config_payload']);
    if ((_readMap(raw['route'])['rule_set'] as List? ?? const []).isNotEmpty ||
        response['smart_connect'] != null || response.containsKey('candidate_materials')) {
      throw const OfflineInvitationFailure('material_not_self_contained');
    }
    final expiry = DateTime.tryParse(_readText(_readMap(response['access'])['expiry_at']));
    if (expiry == null || expiry.toUtc() != authority.expiresAt) {
      throw const OfflineInvitationFailure('access_deadline_mismatch');
    }
    final decoded = await _decodeManagedManifestResponse(response, state: state, hostPlatform: platform,
      routeMode: routeMode, selectedApps: const [], normalizedPreferredNode: catalog.selected.nodeCode,
      preferredVariantId: 'direct', path: AppFirstRuntimeBootstrapper._defaultManagedManifestPath, verifiedAt: _receiver.now,
      offline: true, runtimeFeatures: features, coreRelease: coreRelease,
      selectedCandidateRef: catalog.selectedCandidateRef);
    authority.requireLive(_receiver.now);
    return decoded.payload;
  }
}
