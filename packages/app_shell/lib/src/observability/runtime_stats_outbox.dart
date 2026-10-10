part of '../../app_first_runtime_bootstrap.dart';

final class _RuntimeStatsBinding {
  const _RuntimeStatsBinding(this.accountId, this.installId);
  final String accountId;
  final String installId;

  bool matches(_StoredBootstrapState? state) =>
      state?.hasSession == true &&
      state!.accountId == accountId &&
      state.installId == installId;
}

final class _RuntimeStatsRecord {
  _RuntimeStatsRecord(this.binding, this.bodyJson);
  final _RuntimeStatsBinding binding;
  final String bodyJson;
  Map<String, dynamic> get body => jsonDecode(bodyJson) as Map<String, dynamic>;
  String get key => '${body['report_run_id']}:${body['report_sequence']}';
  DateTime get occurredAt =>
      DateTime.parse(body['occurred_at'] as String).toUtc();
  Map<String, Object?> toJson() => {
        'account_id': binding.accountId,
        'install_id': binding.installId,
        'body': body,
      };

  static _RuntimeStatsRecord fromJson(Object? value) {
    if (value is! Map ||
        value.length != 3 ||
        value['account_id'] is! String ||
        (value['account_id'] as String).isEmpty ||
        value['install_id'] is! String ||
        (value['install_id'] as String).isEmpty ||
        value['body'] is! Map) {
      throw const FormatException('runtime_stats_record_invalid');
    }
    final body = value['body'] as Map;
    const fields = {
      'runtime_phase',
      'connected',
      'client_application',
      'platform',
      'app_version',
      'build_number',
      'report_run_id',
      'report_sequence',
      'occurred_at',
      'connectivity',
      'error_code',
      'failure_kind',
      'selected_node_code',
      'route_mode',
      'duration_ms',
      'attempt_number',
      'retryable',
      'network_class',
      'carrier_mcc_mnc',
      'carrier_name',
      'candidate_transport',
      'candidate_ref',
      'candidate_variant',
      'access_network_asn',
      'candidate_probes'
    };
    if (body.keys.any((key) => !fields.contains(key)) ||
        body.entries.any((entry) =>
            entry.key != 'connectivity' &&
            entry.key != 'candidate_probes' &&
            entry.value is! String &&
            entry.value is! int &&
            entry.value is! bool) ||
        body['runtime_phase'] is! String ||
        body['connected'] is! bool ||
        body['report_run_id'] is! String ||
        !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(body['report_run_id'] as String) ||
        body['report_sequence'] is! int ||
        (body['report_sequence'] as int) < 1 ||
        body['occurred_at'] is! String ||
        DateTime.tryParse(body['occurred_at'] as String) == null ||
        (body.containsKey('client_application') &&
            body['client_application'] != 'pokrov')) {
      throw const FormatException('runtime_stats_body_invalid');
    }
    final connectivity = body['connectivity'];
    const connectivityFields = {
      'fetched_revision',
      'fetched_protocol',
      'staged_revision',
      'staged_protocol',
      'effective_revision',
      'effective_protocol',
      'proof_stage',
      'observed_at_ms'
    };
    if (connectivity is! Map ||
        connectivity.keys.any((key) => !connectivityFields.contains(key)) ||
        connectivity.values.any((value) => value is! String && value is! int)) {
      throw const FormatException('runtime_stats_connectivity_invalid');
    }
    final probes = body['candidate_probes'];
    const probeFields = {
      'candidate_ref',
      'candidate_transport',
      'candidate_variant',
      'stage',
      'probe_stage',
      'connected',
      'duration_ms',
      'failure_kind'
    };
    if (probes != null &&
        (probes is! List ||
            probes.length > 16 ||
            probes.any((probe) =>
                probe is! Map ||
                probe.keys.any((key) => !probeFields.contains(key)) ||
                probe.values.any((value) =>
                    value is! String && value is! int && value is! bool)))) {
      throw const FormatException('runtime_stats_probes_invalid');
    }
    final bodyJson = jsonEncode(body);
    OperationalPrivacyGuard.validateSerialized(bodyJson);
    return _RuntimeStatsRecord(
        _RuntimeStatsBinding(
            value['account_id'] as String, value['install_id'] as String),
        bodyJson);
  }
}

final _runtimeStatsDeliveryFlights = <String, Future<Set<String>>>{};

final class _RuntimeStatsOutbox {
  _RuntimeStatsOutbox(this.owner);
  final AppFirstRuntimeBootstrapper owner;
  static const maximumRecords = 4096;
  static const maximumBytes = 4 * 1024 * 1024;
  static const maximumRecordBytes = 8 * 1024;
  static const maximumAge = Duration(days: 7);

  Future<File> _file(HostPlatform platform) async {
    final root = await owner._supportDirectoryResolver();
    return File(
        '${root.path}${Platform.pathSeparator}runtime-stats-outbox-${platform.name}.json');
  }

  Future<List<_RuntimeStatsRecord>> _read(File file) async {
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists())
      await backup.rename(file.path);
    if (!await file.exists()) return [];
    if (await file.length() > maximumBytes)
      throw const FormatException('runtime_stats_outbox_too_large');
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded['schema_version'] != 1 ||
        decoded['records'] is! List ||
        (decoded['records'] as List).length > maximumRecords) {
      throw const FormatException('runtime_stats_outbox_invalid');
    }
    final records = <_RuntimeStatsRecord>[];
    for (final value in decoded['records'] as List) {
      if (utf8.encode(jsonEncode(value)).length > maximumRecordBytes) {
        throw const FormatException('runtime_stats_record_too_large');
      }
      final record = _RuntimeStatsRecord.fromJson(value);
      records.add(record);
    }
    return records;
  }

  String _encode(List<_RuntimeStatsRecord> records) => jsonEncode({
        'schema_version': 1,
        'records': records.map((record) => record.toJson()).toList(),
      });

  Future<bool> rebindAccount(HostPlatform platform, {
    required String legacyAccountId,
    required String canonicalAccountId,
    required String installId,
  }) async {
    if (legacyAccountId.isEmpty || canonicalAccountId.isEmpty ||
        legacyAccountId == canonicalAccountId) return false;
    try {
      final file = await _file(platform);
      return await _withAppFirstStateFileLock(file, () async {
        final records = await _read(file);
        var changed = false;
        final rebound = records.map((record) {
          if (record.binding.accountId != legacyAccountId ||
              record.binding.installId != installId) return record;
          changed = true;
          return _RuntimeStatsRecord(
              _RuntimeStatsBinding(canonicalAccountId, installId), record.bodyJson);
        }).toList();
        if (!changed) return true;
        final encoded = _encode(rebound);
        if (utf8.encode(encoded).length > maximumBytes ||
            rebound.any((record) =>
                utf8.encode(jsonEncode(record.toJson())).length > maximumRecordBytes)) {
          return false;
        }
        await owner._stateFileWriter(file, encoded);
        return true;
      });
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<bool> enqueue(
      HostPlatform platform, _RuntimeStatsRecord record) async {
    final file = await _file(platform);
    _RuntimeStatsRecord.fromJson(record.toJson());
    if (utf8.encode(jsonEncode(record.toJson())).length > maximumRecordBytes)
      return false;
    return _withAppFirstStateFileLock(file, () async {
      final records = await _read(file);
      records.removeWhere((item) => item.occurredAt
          .isBefore(DateTime.now().toUtc().subtract(maximumAge)));
      for (final existing in records) {
        if (existing.key == record.key)
          return jsonEncode(existing.toJson()) == jsonEncode(record.toJson());
      }
      final next = [...records, record];
      final encoded = _encode(next);
      if (next.length > maximumRecords ||
          utf8.encode(encoded).length > maximumBytes) return false;
      await owner._stateFileWriter(file, encoded);
      return true;
    });
  }

  Future<Set<String>> flush(HostPlatform platform,
      {String? priorityPacketKey,
      void Function(int? httpStatus, String? failureKind)? onCurrentPacketResult}) async {
    final file = await _file(platform);
    final key = file.absolute.path.toLowerCase();
    final previous = _runtimeStatsDeliveryFlights[key];
    if (previous != null) return previous;
    final pending = _drain(platform, file, priorityPacketKey, onCurrentPacketResult);
    _runtimeStatsDeliveryFlights[key] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_runtimeStatsDeliveryFlights[key], pending))
        _runtimeStatsDeliveryFlights.remove(key);
    }
  }

  Future<Set<String>> _drain(
      HostPlatform platform, File file, String? priorityPacketKey,
      void Function(int? httpStatus, String? failureKind)? onCurrentPacketResult) async {
    final accepted = <String>{};
    final records = await _withAppFirstStateFileLock(file, () async {
      final records = await _read(file);
      // Persist TTL cleanup even when another account owns the current session.
      final previousLength = records.length;
      records.removeWhere((item) => item.occurredAt
          .isBefore(DateTime.now().toUtc().subtract(maximumAge)));
      if (records.length != previousLength)
        await owner._stateFileWriter(file, _encode(records));
      return records;
    });
    final initialState = await owner._loadState(platform);
    if (initialState == null ||
        !initialState.hasSession ||
        owner.invitationNetworkDeferred) return accepted;
    final matching = records
        .where((record) => record.binding.matches(initialState))
        .toList();
    final priorityIndex =
        matching.indexWhere((record) => record.key == priorityPacketKey);
    if (priorityIndex > 0) matching.insert(0, matching.removeAt(priorityIndex));
    final elapsed = Stopwatch()..start();
    for (final record in matching.take(16)) {
      final state = await owner._loadState(platform);
      if (!record.binding.matches(state) || owner.invitationNetworkDeferred)
        return accepted;
      HttpClient? client;
      var requestStarted = false;
      try {
        client = owner._createHttpClient(platform);
        for (var attempt = 0;; attempt++) {
          final remaining =
              owner.smartConnectTelemetryDeadline - elapsed.elapsed;
          if (remaining <= Duration.zero) return accepted;
          try {
            requestStarted = true;
            final response = await owner
                ._requestJson(
                    client: client,
                    bearerToken: state!.sessionToken,
                    hostPlatform: platform,
                    method: 'POST',
                    path: '/api/client/runtime/stats',
                    body: record.body)
                .timeout(remaining);
            // _requestJson accepts only HTTP 200 for this exact stats POST.
            if (record.key == priorityPacketKey) onCurrentPacketResult?.call(200, null);
            if (response['ok'] != true) return accepted;
            break;
          } on BootstrapFailure catch (error) {
            if (record.key == priorityPacketKey) {
              onCurrentPacketResult?.call(
                  error.statusCode ?? error.observedHttpStatus, error.apiFailureKind);
            }
            if (record.body['candidate_probes'] == null ||
                attempt > 0 ||
                (error.operationalCode != 'API-002' &&
                    error.operationalCode != 'API-003' &&
                    (error.statusCode == null ||
                        !owner._shouldRetryStatus(error.statusCode!))))
              return accepted;
            await owner._delayScheduler(owner._retryDelayForAttempt(attempt));
          }
        }
      } on Object catch (error) {
        if (requestStarted && record.key == priorityPacketKey) {
          onCurrentPacketResult?.call(null, error is TimeoutException ? 'request_timeout' : null);
        }
        return accepted;
      } finally {
        client?.close(force: true);
      }
      accepted.add(record.key);
      await _withAppFirstStateFileLock(file, () async {
        final retained = await _read(file);
        retained.removeWhere((item) => item.key == record.key);
        await owner._stateFileWriter(file, _encode(retained));
      });
    }
    return accepted;
  }
}
