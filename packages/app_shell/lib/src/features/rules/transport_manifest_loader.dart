part of '../../../app_first_runtime_bootstrap.dart';

class _TransportManifestLoader {
  const _TransportManifestLoader(this.bootstrapper);
  final AppFirstRuntimeBootstrapper bootstrapper;

  Future<TransportManifestSelection?> openSelection({required HostPlatform hostPlatform,
      required RuntimeBootClockSnapshot operationStarted, required Duration operationBudget,
      required bool Function() operationIsCurrent, required Future<void> cancelled,
      bool cacheOnly = false}) async {
    final store = bootstrapper._transportManifestStore;
    if (store == null || !store.enabled) return null;
    if (!store.available) throw const TransportManifestFailure('transport_trust_unconfigured');
    final deadline = TransportClockDeadline(operationStarted, operationBudget);
    final generation = store.invalidationGeneration;
    var stopped = false;
    TransportManifestSelection? handle;
    void Function()? removeSessionObserver;
    void stop() {
      stopped = true;
      handle?.close();
      removeSessionObserver?.call();
    }
    unawaited(cancelled.then((_) => stop(), onError: (Object _) => stop()));
    bool isCurrent() => !stopped && operationIsCurrent() && generation == store.invalidationGeneration;
    void requireCurrent() {
      if (!isCurrent()) throw const TransportManifestFailure('transport_selection_superseded');
    }
    requireCurrent();
    final stateFile = await bootstrapper._stateFile(hostPlatform);
    requireCurrent();
    final state = await _withAppFirstStateFileLock(stateFile,
      () => bootstrapper._loadStateFromFile(hostPlatform, stateFile));
    requireCurrent();
    if (state == null || !state.hasSession) {
      throw const BootstrapFailure('Для обновления правил нужен вход.', statusCode: HttpStatus.unauthorized);
    }
    Future<void> requireSameSession() async {
      final current = await bootstrapper._loadState(hostPlatform);
      requireCurrent();
      if (current?.accountId != state.accountId || current?.installId != state.installId ||
          current?.sessionToken != state.sessionToken) {
        throw const TransportManifestFailure('transport_session_changed');
      }
    }
    final observerKey = stateFile.absolute.path.toLowerCase();
    void observer(_StoredBootstrapState next) {
      if (next.accountId != state.accountId || next.installId != state.installId ||
          next.sessionToken != state.sessionToken) stop();
    }
    removeSessionObserver = () {
      final observers = _transportSelectionSessionObservers[observerKey];
      observers?.remove(observer);
      if (observers != null && observers.isEmpty) _transportSelectionSessionObservers.remove(observerKey);
    };
    (_transportSelectionSessionObservers[observerKey] ??= {}).add(observer);
    try {
      final now = await store.clock.readBootClock();
      requireCurrent();
      deadline.requireCurrent(now);
      final result = await fetch(hostPlatform: hostPlatform, cacheOnly: cacheOnly,
        remainingBudget: Duration(milliseconds: deadline.expiresElapsedMs - now.elapsedMilliseconds),
        cancelled: cancelled);
      requireCurrent();
      await requireSameSession();
      if (result == null) throw const TransportManifestFailure('transport_cache_unavailable');
      handle = await store.openSelection(admission: result.admission, expectedGeneration: generation,
        operationStarted: operationStarted, operationBudget: operationBudget,
        operationIsCurrent: isCurrent, requireSession: requireSameSession);
      handle!.requireCurrent();
      unawaited(handle!.whenClosed.then((_) => removeSessionObserver?.call()));
      return handle;
    } on Object {
      stop();
      rethrow;
    }
  }

  Future<TransportManifestFetchResult?> fetch({required HostPlatform hostPlatform,
      required Duration remainingBudget, bool cacheOnly = false, Future<void>? cancelled,
      bool enrollment = false}) async {
    final store = bootstrapper._transportManifestStore;
    if (store == null || !store.enabled) return null;
    if (!store.available) throw const TransportManifestFailure('transport_trust_unconfigured');
    if (remainingBudget <= Duration.zero) {
      throw const TransportManifestFailure('transport_budget_exhausted');
    }
    final elapsed = Stopwatch()..start();
    final ended = Completer<void>();
    final timer = Timer(remainingBudget, () { if (!ended.isCompleted) ended.complete(); });
    final requests = _ManagedProfileRequests(Future.any<void>([
      ended.future, if (cancelled != null) cancelled,
    ]));
    final generation = store.invalidationGeneration;
    HttpClient? client;
    try {
      void requireActive() {
        if (elapsed.elapsed >= remainingBudget) {
          throw const TransportManifestFailure('transport_budget_exhausted');
        }
        requests.requireActive();
        if (generation != store.invalidationGeneration) {
          throw const TransportManifestFailure('transport_admission_superseded');
        }
      }
      requireActive();
      final budgetStart = await store.clock.readBootClock();
      requireActive();
      final deadline = TransportClockDeadline(budgetStart, remainingBudget - elapsed.elapsed);
      final state = await bootstrapper._loadOrCreateState(hostPlatform);
      requireActive();
      if (!state.hasSession) {
        throw const BootstrapFailure('Для обновления правил нужен вход.', statusCode: HttpStatus.unauthorized);
      }
      Future<void> requireSameSession() async {
        final current = await bootstrapper._loadOrCreateState(hostPlatform);
        requireActive();
        if (current.accountId != state.accountId || current.installId != state.installId ||
            current.sessionToken != state.sessionToken) {
          throw const TransportManifestFailure('transport_session_changed');
        }
      }
      Future<TransportManifestFetchResult> readCache() async {
        final cached = await store.read(deadline: deadline);
        await requireSameSession();
        if (cached == null) throw const TransportManifestFailure('transport_cache_unavailable');
        return TransportManifestFetchResult(admission: cached, usingCache: true);
      }
      if (cacheOnly && !enrollment) return await readCache();
      client = requests.attach(bootstrapper._createHttpClient(hostPlatform));
      try {
        requireActive();
        final random = Random.secure();
        final nonce = List.generate(16, (_) => random.nextInt(256))
            .map((value) => value.toRadixString(16).padLeft(2, '0')).join();
        final sentClock = await store.clock.readBootClock();
        deadline.requireCurrent(sentClock);
        requireActive();
        final response = await bootstrapper._requestJson(
          method: 'POST', path: '/api/client/transport-manifest/bootstrap',
          hostPlatform: hostPlatform,
          client: client, bearerToken: state.sessionToken, allowRetries: false,
          requireHttps: true,
          body: {'schema_version': 'pokrov-transport-bootstrap-request-v1', 'request_nonce': nonce},
          maximumResponseBytes: transportBootstrapResponseMaximumBytes,
          requestTimeoutOverride: remainingBudget - elapsed.elapsed,
          responseDecoder: decodeTransportBootstrapResponse,
        );
        final receivedClock = await store.clock.readBootClock();
        deadline.requireCurrent(receivedClock);
        await requireSameSession();
        if (response['request_nonce'] != nonce) {
          throw const TransportManifestFailure('transport_bootstrap_nonce_mismatch');
        }
        final observedAt = DateTime.parse(response['observed_at'] as String);
        final anchor = TransportTimeAnchor.fromOnline(observedAt: observedAt, sent: sentClock, received: receivedClock);
        // Only this explicit online operation can seed an absent floor. No
        // response file, cached reply or ordinary fetch becomes enrollment.
        bool operationIsCurrent() => !requests.isCancelled && elapsed.elapsed < remainingBudget &&
            generation == store.invalidationGeneration;
        final admitted = enrollment
            ? await store.enroll(response['manifest'], rollback: response['rollback'],
                onlineFloor: response['floor']!, observedAt: observedAt, onlineAnchor: anchor,
                expectedGeneration: generation, deadline: deadline, operationIsCurrent: operationIsCurrent)
            : await store.accept(response['manifest'], rollback: response['rollback'],
                expectedGeneration: generation, onlineAnchor: anchor, deadline: deadline,
                operationIsCurrent: operationIsCurrent);
        await requireSameSession();
        return TransportManifestFetchResult(admission: admitted, usingCache: false);
      } on BootstrapFailure catch (error) {
        // Known authenticated denial disables reuse even if cancellation raced
        // the response. A changed session must not receive the old response.
        final current = await bootstrapper._loadOrCreateState(hostPlatform);
        if (current.accountId != state.accountId || current.installId != state.installId ||
            current.sessionToken != state.sessionToken || generation != store.invalidationGeneration) {
          throw const TransportManifestFailure('transport_session_changed');
        }
        if (error.statusCode == HttpStatus.unauthorized || error.statusCode == HttpStatus.forbidden ||
            error.code.startsWith('transport_')) {
          try { await store.discardEnvelopes(); } on Object {
            // Store suspension remains set even when durable withdrawal fails.
          }
          rethrow;
        }
        requireActive();
        final transient = error.operationalCode == 'API-002' || const {
          HttpStatus.requestTimeout, HttpStatus.tooManyRequests, HttpStatus.badGateway,
          HttpStatus.serviceUnavailable, HttpStatus.gatewayTimeout,
        }.contains(error.statusCode);
        if (transient && !enrollment) return await readCache();
        rethrow;
      }
    } finally {
      timer.cancel();
      if (!ended.isCompleted) ended.complete();
      if (client != null) requests.close(client);
      elapsed.stop();
    }
  }
}
