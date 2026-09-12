import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  if (!Platform.isWindows) throw StateError('Windows fixture only');
  final directory = Directory.systemTemp.createTempSync('pokrov-rename-proof-');
  final results = <Map<String, Object?>>[];
  try {
    for (final synchronous in [false, true]) {
      final marker = File('${directory.path}/marker-$synchronous.json');
      final next = File('${marker.path}.next');
      marker.writeAsStringSync('old-owned-marker', flush: true);
      next.writeAsStringSync('new-owned-marker', flush: true);
      final handle = next.openSync();
      int? errorCode;
      try {
        try {
          if (synchronous) {
            next.renameSync(marker.path);
          } else {
            await next.rename(marker.path);
          }
        } on FileSystemException catch (error) {
          errorCode = error.osError?.errorCode;
        }
        if (errorCode == null) throw StateError('Native failure not reproduced');
        if (marker.readAsStringSync() != 'old-owned-marker') {
          throw StateError('Previous marker lost');
        }
      } finally {
        handle.closeSync();
      }
      if (synchronous) {
        next.renameSync(marker.path);
      } else {
        await next.rename(marker.path);
      }
      if (marker.readAsStringSync() != 'new-owned-marker') {
        throw StateError('Existing destination was not replaced');
      }
      results.add({'synchronous': synchronous, 'native_failure_code': errorCode,
        'old_marker_survived': true, 'replacement_after_unlock': true});
    }
  } finally {
    directory.deleteSync(recursive: true);
  }
  stdout.writeln(jsonEncode({'status': 'PASS_WINDOWS_NATIVE_RENAME', 'results': results}));
}
