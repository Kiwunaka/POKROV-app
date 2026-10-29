import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';

import '../packages/app_shell/lib/src/connection/candidate_ranker_model.dart';

/// Run as an AOT executable against an approved local exported model.
/// Covers the actual DNS pair and the seven-candidate training cohort only.
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Usage: benchmark_candidate_ranker MODEL');
  final rssBefore = ProcessInfo.currentRss;
  final load = Stopwatch()..start();
  final model = CandidateRankerModel.fromBytes(await File(args.single).readAsBytes());
  load.stop();
  final rows = <Map<String, Object>>[];
  for (final count in [2, 7]) {
    final input = Float32List(count * 9 * 82);
    for (var candidate = 0; candidate < count; candidate++) {
      final base = candidate * 738 + 8 * 82;
      // No observed history; current metadata explicitly unknown, 30s budgets.
      for (final feature in [0, 6, 14, 20, 23, 26, 31, 34, 38, 53, 70, 71, 72, 73, 81]) {
        input[base + feature] = 1;
      }
    }
    for (var warm = 0; warm < 3; warm++) {
      model.score(input);
    }
    await Isolate.run(() => model.score(input));
    final direct = <int>[], background = <int>[];
    var mainIsolateTicks = 0;
    for (var run = 0; run < 20; run++) {
      final timer = Stopwatch()..start();
      model.score(input);
      direct.add(timer.elapsedMicroseconds);
      final heartbeat = Timer.periodic(const Duration(milliseconds: 1), (_) => mainIsolateTicks++);
      timer.reset();
      await Isolate.run(() => model.score(input));
      background.add(timer.elapsedMicroseconds);
      heartbeat.cancel();
    }
    direct.sort();
    background.sort();
    rows.add({
      'candidates': count, 'runs': direct.length,
      'score_us_p50': direct[9], 'score_us_p95': direct[18],
      'isolate_us_p50': background[9], 'isolate_us_p95': background[18],
      'main_isolate_timer_ticks_during_inference': mainIsolateTicks,
      'current_RSS_MiB': ProcessInfo.currentRss / (1024 * 1024),
      'process_peak_RSS_MiB': ProcessInfo.maxRss / (1024 * 1024),
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'contract': 'pokrov-preaction-v1', 'runtime': Platform.version,
    'model_parameters': 933700, 'load_ms': load.elapsedMicroseconds / 1000,
    'RSS_before_load_MiB': rssBefore / (1024 * 1024), 'measurements': rows,
    'scope': 'local AOT CPU, no network; isolate timing includes spawn/transfer; peak RSS is cumulative',
  }));
}
