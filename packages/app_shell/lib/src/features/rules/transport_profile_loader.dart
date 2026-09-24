part of '../../../app_first_runtime_bootstrap.dart';

/// Created only by the session-owned HTTPS resolver, never from a cached file.
/// Material remains tied to this exact selection; callers must sample before use.
class AuthenticatedTransportProfile {
  const AuthenticatedTransportProfile._(this.selection, this.profile, this._isCurrent);
  final TransportManifestSelection selection;
  final TransportResolvedProfile profile;
  final bool Function() _isCurrent;

  void requireCurrent(TransportManifestSelection expected, TransportTimeWindow now) {
    if (!identical(selection, expected) || !_isCurrent()) {
      throw const TransportManifestFailure('transport_profile_selection_mismatch');
    }
    selection.requireCurrent();
    selection.deadline.requireCurrent(now.sample);
    profile.query.requirePolicy(selection.admission);
    if (now.earliest.isBefore(profile.authorizedFrom) ||
        !now.latest.isBefore(profile.authorizedUntil)) {
      throw const TransportManifestFailure('transport_profile_expired');
    }
  }

  @override
  String toString() => 'AuthenticatedTransportProfile(redacted)';
}

class _TransportProfileLoader {
  const _TransportProfileLoader(this.bootstrapper);
  final AppFirstRuntimeBootstrapper bootstrapper;

  Future<List<TransportEndpointHint>> shortlist({required HostPlatform hostPlatform,
      required TransportManifestSelection selection, required TransportEndpointShortlistQuery query,
      required RuntimeBootClockSnapshot budgetStartedAt, required Duration budget,
      required Future<void> cancelled}) async {
    final store = bootstrapper._transportManifestStore;
    if (store == null || !store.available || query.fields['platform'] != hostPlatform.name) {
      throw const TransportManifestFailure('transport_endpoint_shortlist_unavailable');
    }
    query.requirePolicy(selection.admission);
    final deadline = TransportClockDeadline(budgetStartedAt, budget);
    final ended = Completer<void>();
    void stop() { if (!ended.isCompleted) ended.complete(); }
    unawaited(cancelled.then((_) => stop(), onError: (Object _) => stop()));
    unawaited(selection.whenClosed.then((_) => stop()));
    final timer = Timer(budget, stop);
    final requests = _ManagedProfileRequests(ended.future);
    final pending = <Future<void>>[];
    HttpClient? client;
    Future<T> wait<T>(Future<T> work) {
      pending.add(work.then<void>((_) {}, onError: (Object _) {}));
      return Future.any<T>([work, ended.future.then<T>((_) =>
        throw const TransportManifestFailure('transport_endpoint_shortlist_cancelled'))]);
    }
    void current() {
      if (ended.isCompleted) throw const TransportManifestFailure('transport_endpoint_shortlist_cancelled');
      selection.requireCurrent();
      requests.requireActive();
    }
    try {
      current();
      final state = await wait(bootstrapper._loadOrCreateState(hostPlatform));
      current();
      if (!state.hasSession) throw const TransportManifestFailure('transport_profile_session_required');
      Future<TransportTimeWindow> sample() async {
        final currentState = await bootstrapper._loadOrCreateState(hostPlatform);
        current();
        if (currentState.accountId != state.accountId || currentState.installId != state.installId ||
            currentState.sessionToken != state.sessionToken) {
          throw const TransportManifestFailure('transport_session_changed');
        }
        final now = await selection.sample();
        current();
        deadline.requireCurrent(now.sample);
        return now;
      }
      final sent = await wait(sample());
      final random = Random.secure();
      final nonce = List.generate(16, (_) => random.nextInt(256))
          .map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      final request = query.request(selection.admission, nonce);
      client = requests.attach(bootstrapper._createHttpClient(hostPlatform));
      final response = await wait(bootstrapper._requestJson(
        method: 'POST', path: '/api/client/transport-endpoints/shortlist', hostPlatform: hostPlatform,
        client: client, bearerToken: state.sessionToken, body: request, requireHttps: true,
        allowRetries: false, maximumResponseBytes: transportEndpointShortlistMaximumBytes,
        requestTimeoutOverride: Duration(milliseconds: deadline.expiresElapsedMs - sent.sample.elapsedMilliseconds),
        responseDecoder: decodeTransportEndpointShortlistResponse,
      ));
      await wait(sample());
      final hints = admitTransportEndpointShortlist(response, request: request, admission: selection.admission);
      await wait(sample());
      current();
      return hints;
    } on BootstrapFailure catch (error) {
      if (error.statusCode == HttpStatus.unauthorized || error.statusCode == HttpStatus.forbidden ||
          const {'transport_profile_issuer_disabled', 'transport_cohort_unavailable',
            'transport_policy_disabled', 'transport_policy_unavailable',
            'transport_profile_policy_changed', 'transport_profile_not_authorized'}
              .contains(error.code)) selection.close();
      rethrow;
    } finally {
      timer.cancel();
      stop();
      if (client != null) requests.close(client);
      await Future.wait(pending);
    }
  }

  Future<AuthenticatedTransportProfile> resolve({required HostPlatform hostPlatform,
      required TransportManifestSelection selection, required TransportProfileQuery query,
      required RuntimeBootClockSnapshot budgetStartedAt, required Duration budget,
      required Future<void> cancelled}) async {
    final store = bootstrapper._transportManifestStore;
    if (store == null || !store.available || query.fields['platform'] != hostPlatform.name) {
      throw const TransportManifestFailure('transport_profile_unavailable');
    }
    query.requirePolicy(selection.admission);
    final deadline = TransportClockDeadline(budgetStartedAt, budget);
    final ended = Completer<void>();
    var cancelledByOwner = false;
    void stop() { if (!ended.isCompleted) ended.complete(); }
    void cancelByOwner() { cancelledByOwner = true; stop(); }
    unawaited(cancelled.then((_) => cancelByOwner(), onError: (Object _) => cancelByOwner()));
    unawaited(selection.whenClosed.then((_) => stop()));
    final timer = Timer(budget, stop);
    Timer? nativeTimer;
    final requests = _ManagedProfileRequests(ended.future);
    HttpClient? client;
    final pendingSettlements = <Future<void>>[];
    Future<T> wait<T>(Future<T> pending) {
      pendingSettlements.add(pending.then<void>((_) {}, onError: (Object _) {}));
      return Future.any<T>([
        pending, ended.future.then<T>((_) => throw const TransportManifestFailure('transport_profile_cancelled')),
      ]);
    }
    void requireCurrent() {
      if (ended.isCompleted) throw const TransportManifestFailure('transport_profile_cancelled');
      selection.requireCurrent();
      requests.requireActive();
    }
    try {
      requireCurrent();
      final start = await wait(selection.sample());
      deadline.requireCurrent(start.sample);
      nativeTimer = Timer(Duration(milliseconds: deadline.expiresElapsedMs - start.sample.elapsedMilliseconds), stop);
      final state = await wait(bootstrapper._loadOrCreateState(hostPlatform));
      requireCurrent();
      if (!state.hasSession) throw const TransportManifestFailure('transport_profile_session_required');
      Future<TransportTimeWindow> sample() async {
        final current = await bootstrapper._loadOrCreateState(hostPlatform);
        requireCurrent();
        if (current.accountId != state.accountId || current.installId != state.installId ||
            current.sessionToken != state.sessionToken) {
          throw const TransportManifestFailure('transport_session_changed');
        }
        final now = await selection.sample();
        requireCurrent();
        deadline.requireCurrent(now.sample);
        return now;
      }
      final sent = await wait(sample());
      final random = Random.secure();
      final nonce = List.generate(16, (_) => random.nextInt(256))
          .map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      final request = query.request(selection.admission, nonce);
      client = requests.attach(bootstrapper._createHttpClient(hostPlatform));
      final response = await wait(bootstrapper._requestJson(
        method: 'POST', path: '/api/client/transport-profile/resolve', hostPlatform: hostPlatform,
        client: client, bearerToken: state.sessionToken, body: request, requireHttps: true,
        allowRetries: false, maximumResponseBytes: transportProfileResponseMaximumBytes,
        requestTimeoutOverride: Duration(milliseconds: deadline.expiresElapsedMs - sent.sample.elapsedMilliseconds),
        responseDecoder: decodeTransportProfileResponse,
      ));
      await wait(sample());
      final profile = await wait(TransportResolvedProfile.admit(response, request: request, admission: selection.admission));
      final now = await wait(sample());
      final result = AuthenticatedTransportProfile._(selection, profile, () => !cancelledByOwner);
      result.requireCurrent(selection, now);
      requireCurrent();
      return result;
    } on BootstrapFailure catch (error) {
      // Do not let a late response revoke a replacement session's policy.
      // Closing this exact handle only cancels its own outstanding children.
      if (error.statusCode == HttpStatus.unauthorized || error.statusCode == HttpStatus.forbidden ||
          const {'transport_profile_issuer_disabled', 'transport_cohort_unavailable',
            'transport_policy_disabled', 'transport_policy_unavailable',
            'transport_profile_policy_changed', 'transport_profile_not_authorized'}
              .contains(error.code)) selection.close();
      rethrow;
    } finally {
      timer.cancel();
      nativeTimer?.cancel();
      stop();
      if (client != null) requests.close(client);
      // A cancelled future is not settlement of its HTTP/clock/hash work. Keep
      // the caller's preparation permit until those exact operations finish.
      await Future.wait(pendingSettlements);
    }
  }
}
