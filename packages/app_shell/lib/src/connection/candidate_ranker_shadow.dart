part of '../../app_first_runtime_bootstrap.dart';

/// A local owned-QA observer. It cannot return a candidate to the scheduler.
/// Only a private build with an explicit local model path enables this observer.
class CandidateRankerShadow {
  CandidateRankerShadow(this._model);

  static Future<CandidateRankerShadow> loadLocal(String path) async {
    final model = await Isolate.run(() =>
        CandidateRankerModel.fromBytes(File(path).readAsBytesSync()));
    return CandidateRankerShadow(model);
  }

  final CandidateRankerModel _model;
  String? _network, _catalog;
  var _generation = 0;
  final _refs = <String, int>{};
  final _history = <Map<String, Object?>>[];
  Future<void>? _pending;
  CandidateRankerComparison? lastComparison;
  String? lastFailure;
  Future<void> get settled => _pending ?? Future<void>.value();

  int _begin(String network, String catalog) {
    if (_network != network || _catalog != catalog) {
      _network = network;
      _catalog = catalog;
      _generation++;
      _refs.clear();
      _history.clear();
      lastComparison = null;
    }
    return _generation;
  }

  Map<String, Object?> _descriptor(TransportCandidate candidate,
      Duration probeBudget, Duration selectionBudget) => {
    'candidate_ref': _refs.putIfAbsent(candidate.candidateRef, () => _refs.length),
    for (final entry in <String, String>{
      'protocol': candidate.protocol, 'transport': candidate.transport,
      'protection': candidate.protection, 'network': candidate.network,
      'family': candidate.family,
    }.entries) entry.key: _known(entry.key, entry.value),
    'probe_budget_ms': probeBudget.inMilliseconds,
    'selection_budget_ms': selectionBudget.inMilliseconds,
  };

  void _observe(int generation, TransportCandidate candidate,
      SmartConnectCandidateProbeResult result, DateTime completed,
      Duration probeBudget, Duration selectionBudget, bool? ipv6Available,
      String? networkClass, {required bool nativeStarted}) {
    if (generation != _generation) return;
    final kind = result.failureKind;
    _history.add(Map<String, Object?>.unmodifiable({
      'context_generation': generation,
      'completed_at_ms': completed.millisecondsSinceEpoch,
      'candidate': Map<String, Object?>.unmodifiable(
          _descriptor(candidate, probeBudget, selectionBudget)),
      'result': result.profile != null ? 'pass' : _nativeFailures.contains(kind)
          ? 'network_failure' : 'control',
      'failure_kind': _known('failure_kind', kind.isEmpty ? 'none' : kind),
      'stage': _known('stage', result.probeStage),
      // Preparation failures never ran the native clock.
      'elapsed_ms': nativeStarted ? result.duration.inMilliseconds : null,
      'network_class': _known('network_class', networkClass),
      'ipv6_available': ipv6Available,
    }));
    if (_history.length > 8) _history.removeAt(0);
  }

  void _compare({required int generation, required List<TransportCandidate> candidates,
      required Map<String, int> groups, required String? preferred,
      required DateTime at, required Duration probeBudget,
      required Duration selectionBudget, required bool? ipv6Available,
      required String? networkClass}) {
    if (_pending != null || generation != _generation || candidates.isEmpty) return;
    final first = candidates.first;
    // Initial owned validation covers DNS carriers only. Last-good remains a
    // mandatory head start; ordinary/family/recovery diversity is not learned.
    if (first.candidateRef == preferred || !_dnsCarrier(first)) return;
    final comparable = candidates.where((candidate) => _dnsCarrier(candidate) &&
        groups[candidate.candidateRef] == groups[first.candidateRef] &&
        candidate.family == first.family && candidate.network == first.network).toList();
    if (comparable.length < 2) return;
    final now = at.millisecondsSinceEpoch;
    final decision = <String, Object?>{
      'contract': 'pokrov-preaction-v1', 'at_ms': now,
      'context_generation': generation,
      'network_class': _known('network_class', networkClass),
      'ipv6_available': ipv6Available,
      'candidates': [for (final candidate in comparable) {
        ..._descriptor(candidate, probeBudget, selectionBudget),
        'eligible': true, 'priority_group': groups[candidate.candidateRef],
      }],
      'history': [for (final item in _history)
        if ((item['completed_at_ms'] as int) < now) item],
    };
    final tokens = _encodeRankerDecision(decision);
    final model = _model;
    lastFailure = null;
    // A single background inference cannot delay native probes or accumulate
    // an unbounded queue. Outcomes are still observed while it is running.
    _pending = Isolate.run(() => model.score(tokens)).then((scores) {
      if (generation != _generation) return;
      final order = List<int>.generate(scores.length, (index) => index)
        ..sort((a, b) {
          final scoreOrder = scores[b].compareTo(scores[a]);
          return scoreOrder == 0 ? a.compareTo(b) : scoreOrder;
        });
      lastComparison = CandidateRankerComparison(decision, tokens,
          List.unmodifiable(scores), List.unmodifiable(order));
      debugPrint('POKROV_RANKER shadow candidates=${scores.length} order=${order.join(",")}');
    }).catchError((Object _) {
      if (generation == _generation) lastFailure = 'inference_failed';
      debugPrint('POKROV_RANKER shadow_inference_failed');
    }).whenComplete(() => _pending = null);
  }

  static bool _dnsCarrier(TransportCandidate candidate) =>
      candidate.transport == 'dnstt' || candidate.transport == 'slipstream';
}

class CandidateRankerComparison {
  CandidateRankerComparison(this.decision, this.tokens, this.scores, this.modelOrder);
  /// Only public categories, numeric budgets and local equality IDs; no profile,
  /// node, endpoint, account or physical-network identifiers.
  final Map<String, Object?> decision;
  final Float32List tokens;
  final List<double> scores;
  /// Indices into the snapshot's existing scheduler order; not applied by Auto.
  final List<int> modelOrder;
}

const _nativeFailures = {'connect_failed', 'tls_failed', 'timeout', 'data_stalled',
  'probe_failed', 'unexpected_status'};
const _rankerCategories = <String, List<String>>{
  'protocol': ['unknown', 'vless', 'naive', 'awg', 'hysteria2', 'warp'],
  'transport': ['unknown', 'tcp', 'grpc', 'xhttp', 'h2', 'udp', 'dnstt', 'slipstream'],
  'protection': ['unknown', 'reality', 'tls', 'noise', 'awg31', 'warp'],
  'network': ['unknown', 'tcp', 'udp'],
  'family': ['unknown', 'ipv4', 'ipv6'],
  'network_class': ['unknown', 'wifi', 'cellular', 'ethernet', 'other'],
  'ipv6_state': ['unknown', 'no', 'yes'],
  'result': ['unknown', 'pass', 'network_failure', 'control'],
  'stage': ['unknown', 'parse_profile', 'create_instance', 'start_instance',
    'select_outbound', 'proxy_dial', 'egress_check', 'tls_handshake', 'tls_read',
    'tls_write', 'tls_processing', 'tls_certificate_verified', 'tls_complete',
    'http_204', 'http_64k'],
  'failure_kind': ['unknown', 'none', 'connect_failed', 'tls_failed', 'timeout',
    'data_stalled', 'probe_failed', 'unexpected_status', 'network_changed',
    'cancelled', 'invalid_profile', 'start_failed', 'unavailable', 'prepare_failed',
    'owner_superseded', 'auth', 'access_denied'],
};

String _known(String field, String? value) =>
    _rankerCategories[field]!.contains(value) ? value! : 'unknown';

Float32List _encodeRankerDecision(Map<String, Object?> decision) {
  final candidates = decision['candidates'] as List<Map<String, Object?>>;
  final history = decision['history'] as List<Map<String, Object?>>;
  final result = Float32List(candidates.length * 9 * 82);
  void token(int base, Map<String, Object?> candidate, Map<String, Object?> context,
      {Map<String, Object?>? outcome, double? age, bool? same, bool current = false}) {
    final values = <String, Object?>{
      ...candidate, 'network_class': context['network_class'],
      'ipv6_state': context['ipv6_available'] == null ? 'unknown'
          : context['ipv6_available'] == true ? 'yes' : 'no',
      'result': outcome?['result'], 'stage': outcome?['stage'],
      'failure_kind': outcome?['failure_kind'],
    };
    var offset = base;
    for (final field in _rankerCategories.entries) {
      final index = field.value.indexOf(values[field.key] as String? ?? 'unknown');
      result[offset + index] = 1;
      offset += field.value.length;
    }
    void number(int index, Object? value, double scale) {
      if (value == null) return;
      result[offset + index] = (value as num) / scale;
      result[offset + index + 1] = 1;
    }
    number(0, candidate['probe_budget_ms'], 30000);
    number(2, candidate['selection_budget_ms'], 30000);
    number(4, outcome?['elapsed_ms'], 60000);
    if (age != null) {
      result[offset + 6] = log(1 + min(age, 3600)) / log(3601);
      result[offset + 7] = 1;
    }
    if (same != null) {
      result[offset + 8] = same ? 1 : 0;
      result[offset + 9] = 1;
    }
    result[offset + 10] = current ? 0 : 1;
    result[offset + 11] = current ? 1 : 0;
  }
  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    token(index * 738 + 8 * 82, candidate, decision, current: true);
    for (var item = 0; item < history.length; item++) {
      final observed = history[item];
      final past = observed['candidate'] as Map<String, Object?>;
      token(index * 738 + (8 - history.length + item) * 82, past, observed,
          outcome: observed, age: ((decision['at_ms'] as int) -
              (observed['completed_at_ms'] as int)) / 1000,
          same: candidate['candidate_ref'] == past['candidate_ref']);
    }
  }
  return result;
}
