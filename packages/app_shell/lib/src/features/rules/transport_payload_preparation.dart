part of '../../../app_first_runtime_bootstrap.dart';

class _TransportPayloadPreparation {
  const _TransportPayloadPreparation(this.bootstrapper);
  final AppFirstRuntimeBootstrapper bootstrapper;

  Future<RuntimePayloadProbeExchange> prepare({required HostPlatform hostPlatform,
      required TransportManifestSelection selection, required RuntimeBoundProbeRequest request,
      required bool Function() operationIsCurrent, required Future<void> cancelled}) async {
    if (!bootstrapper.transportManifestEnabled || request.stage != RuntimeBoundProbeStage.payload ||
        !(selection.admission.payload['probe_set_refs'] as List).contains(request.binding['probe_set_ref'])) {
      throw const TransportManifestFailure('transport_payload_unavailable');
    }
    String? currentOrigin() => bootstrapper._activeApiBaseUrl ??
      (bootstrapper._apiBaseUrls.length == 1 ? bootstrapper._apiBaseUrls.single : null);
    final origin = currentOrigin();
    if (origin == null || !bootstrapper._apiBaseUrls.contains(origin)) {
      throw const TransportManifestFailure('transport_payload_origin_unavailable');
    }
    final base = Uri.tryParse(origin);
    if (base == null || base.scheme != 'https' || base.host.isEmpty || base.userInfo.isNotEmpty ||
        base.hasQuery || base.hasFragment || (base.path.isNotEmpty && base.path != '/')) {
      throw const TransportManifestFailure('transport_payload_origin_invalid');
    }
    final endpoint = base.replace(path: '/api/client/transport-proof/payload');
    final deadline = TransportClockDeadline(request.budgetStartedAt, request.budget);
    var stopped = false;
    _SessionTransportPayloadExchange? exchange;
    void stop() { stopped = true; exchange?.close(); }
    unawaited(cancelled.then((_) => stop(), onError: (Object _) => stop()));
    unawaited(selection.whenClosed.then((_) => stop()));
    void current() {
      if (stopped || !operationIsCurrent() || currentOrigin() != origin) {
        throw const TransportManifestFailure('transport_payload_superseded');
      }
      selection.requireCurrent();
    }
    Future<void> sample() async {
      current();
      final now = await selection.sample(); // includes the captured session reread
      current();
      deadline.requireCurrent(now.sample);
    }
    try {
      await sample();
      final state = await bootstrapper._loadState(hostPlatform);
      await sample();
      if (state == null || !state.hasSession || state.accountId.isEmpty || state.installId.isEmpty) {
        throw const TransportManifestFailure('transport_payload_session_required');
      }
      // No API discovery, preflight or request is performed by preparation.
      final random = Random.secure();
      final upload = List<int>.generate(256, (_) => random.nextInt(256));
      String hex(List<int> value) => value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final uploadSha = hex((await Sha256().hash(upload)).bytes);
      await sample();
      final deviceBinding = hex((await Sha256().hash(utf8.encode(
        'pokrov-transport-payload-device-v1\u0000${request.nonce}\u0000${state.accountId}\u0000${state.installId}'))).bytes);
      await sample();
      final prepared = _SessionTransportPayloadExchange(request, endpoint, state.sessionToken,
        jsonEncode({'schema_version': 'pokrov-transport-payload-request-v1', 'request_nonce': request.nonce,
          'probe_set_ref': request.binding['probe_set_ref'], 'payload_hex': hex(upload)}),
        uploadSha, deviceBinding, sample, selection.close);
      exchange = prepared;
      current();
      return prepared;
    } on Object {
      stop();
      rethrow;
    }
  }
}

class _SessionTransportPayloadExchange implements RuntimePayloadProbeExchange {
  _SessionTransportPayloadExchange(this.request, this._endpoint, this._token, this._body,
    this._uploadSha256, this._deviceBinding, this._sample, this._revokeSelection);
  @override
  final RuntimeBoundProbeRequest request;
  final Uri _endpoint;
  String? _token, _body;
  final String _uploadSha256, _deviceBinding;
  final Future<void> Function() _sample;
  final void Function() _revokeSelection;
  final _closed = Completer<void>();
  bool _taken = false, _issued = false, _received = false;
  RuntimePayloadProbeReceipt? _receipt;
  @override
  Future<void> get whenClosed => _closed.future;
  @override
  RuntimePayloadProbeReceipt? get receipt => _receipt;

  Future<void> _requireCurrent() async {
    if (_closed.isCompleted) throw const TransportManifestFailure('transport_payload_closed');
    await _sample();
    if (_closed.isCompleted) throw const TransportManifestFailure('transport_payload_closed');
  }

  @override
  Future<RuntimePayloadProbeRequest> takeRequest() async {
    if (_taken) throw const TransportManifestFailure('transport_payload_already_sent');
    _taken = true;
    try {
      await _requireCurrent();
      _issued = true;
      return RuntimePayloadProbeRequest(endpoint: _endpoint, bearerToken: _token!, bodyJson: _body!);
    } on Object { close(); rethrow; }
  }

  @override
  Future<RuntimePayloadProbeReceipt> acceptResponse({required Uri responseUrl,
      required int statusCode, required List<int> body}) async {
    if (!_issued || _received) throw const TransportManifestFailure('transport_payload_unexpected_response');
    _received = true;
    try {
      await _requireCurrent();
      if (responseUrl != _endpoint) throw const TransportManifestFailure('transport_payload_origin_changed');
      if (statusCode == HttpStatus.unauthorized || statusCode == HttpStatus.forbidden) _revokeSelection();
      if (statusCode != HttpStatus.ok || body.length > RuntimePayloadProbeRequest.maximumResponseBytes) {
        throw const TransportManifestFailure('transport_payload_response_unavailable');
      }
      final value = decodeTransportPayloadResponse(utf8.decode(body, allowMalformed: false));
      if (value['request_nonce'] != request.nonce || value['probe_set_ref'] != request.binding['probe_set_ref'] ||
          value['device_binding'] != _deviceBinding || value['upload_sha256'] != _uploadSha256) {
        throw const TransportManifestFailure('transport_payload_response_mismatch');
      }
      await _requireCurrent();
      return _receipt = RuntimePayloadProbeReceipt(value['verifier_ref'] as String,
        value['receipt_ref'] as String, value['observed_client_ip'] as String);
    } on Object { close(); rethrow; }
  }

  @override
  void close() {
    _token = null;
    _body = null;
    _receipt = null;
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  String toString() => 'RuntimePayloadProbeExchange(redacted)';
}
