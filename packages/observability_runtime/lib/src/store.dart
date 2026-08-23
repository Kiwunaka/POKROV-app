import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'queue.dart';

enum OperationalStoragePlatform { android, windows }

final class OperationalStoragePolicy {
  const OperationalStoragePolicy._({
    required this.totalBytes,
    required this.segmentBytes,
  });

  factory OperationalStoragePolicy.forPlatform(
    OperationalStoragePlatform platform,
  ) {
    final total = switch (platform) {
      OperationalStoragePlatform.android => 24 * 1024 * 1024,
      OperationalStoragePlatform.windows => 64 * 1024 * 1024,
    };
    return OperationalStoragePolicy._(
      totalBytes: total,
      segmentBytes: total ~/ 2,
    );
  }

  factory OperationalStoragePolicy.forTest({
    required int totalBytes,
    required int segmentBytes,
  }) {
    if (totalBytes < 2048 ||
        segmentBytes < 1024 ||
        segmentBytes * 2 > totalBytes) {
      throw ArgumentError('Storage bounds are invalid');
    }
    return OperationalStoragePolicy._(
      totalBytes: totalBytes,
      segmentBytes: segmentBytes,
    );
  }

  final int totalBytes;
  final int segmentBytes;
}

abstract interface class OperationalEventWriter {
  Future<void> appendBatch(List<SerializedOperationalEvent> records);
}

final class JsonlRecoveryResult {
  JsonlRecoveryResult({
    required List<Map<String, Object?>> records,
    required this.truncatedTailIgnored,
    required this.invalidLines,
  }) : records = List.unmodifiable(records);

  final List<Map<String, Object?>> records;
  final bool truncatedTailIgnored;
  final int invalidLines;
}

final class RotatingOperationalJsonlStore implements OperationalEventWriter {
  RotatingOperationalJsonlStore({
    required this.directory,
    required this.policy,
    this.fileStem = 'operational-events.v1',
  });

  final Directory directory;
  final OperationalStoragePolicy policy;
  final String fileStem;
  bool _initialized = false;
  int _rotations = 0;
  int _flushes = 0;
  int _truncatedTailRecoveries = 0;

  File get currentFile => File(p.join(directory.path, '$fileStem.0.jsonl'));
  File get previousFile => File(p.join(directory.path, '$fileStem.1.jsonl'));
  File get _pendingFile =>
      File(p.join(directory.path, '$fileStem.rotate.pending'));

  int get rotations => _rotations;
  int get flushes => _flushes;
  int get truncatedTailRecoveries => _truncatedTailRecoveries;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await directory.create(recursive: true);
    await _recoverInterruptedRotation();
    if (await _truncatePartialTail(currentFile)) {
      _truncatedTailRecoveries += 1;
    }
    if (await _truncatePartialTail(previousFile)) {
      _truncatedTailRecoveries += 1;
    }
    await _enforceTwoSegments();
    _initialized = true;
  }

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    if (records.isEmpty) {
      return;
    }
    await initialize();
    RandomAccessFile? output;
    try {
      var currentLength =
          await currentFile.exists() ? await currentFile.length() : 0;
      for (final record in records) {
        if (record.byteLength > policy.segmentBytes) {
          throw const FileSystemException('operational_event_exceeds_segment');
        }
        if (currentLength + record.byteLength > policy.segmentBytes) {
          if (output != null) {
            await output.flush();
            await output.close();
            output = null;
            _flushes += 1;
          }
          await _rotate();
          currentLength = 0;
        }
        output ??= await currentFile.open(mode: FileMode.append);
        await output.writeFrom(utf8.encode('${record.json}\n'));
        currentLength += record.byteLength;
      }
      if (output != null) {
        await output.flush();
        _flushes += 1;
      }
    } finally {
      await output?.close();
    }
    await _enforceTwoSegments();
  }

  Future<JsonlRecoveryResult> readCurrent() => readValidRecords(currentFile);

  static Future<JsonlRecoveryResult> readValidRecords(File file) async {
    if (!await file.exists()) {
      return JsonlRecoveryResult(
        records: const [],
        truncatedTailIgnored: false,
        invalidLines: 0,
      );
    }
    final bytes = await file.readAsBytes();
    final completeEnd = bytes.lastIndexOf(10) + 1;
    final truncated = bytes.isNotEmpty && completeEnd != bytes.length;
    if (completeEnd == 0) {
      return JsonlRecoveryResult(
        records: const [],
        truncatedTailIgnored: truncated,
        invalidLines: 0,
      );
    }
    String text;
    try {
      text = utf8.decode(bytes.sublist(0, completeEnd), allowMalformed: false);
    } on FormatException {
      return JsonlRecoveryResult(
        records: const [],
        truncatedTailIgnored: truncated,
        invalidLines: 1,
      );
    }
    final records = <Map<String, Object?>>[];
    var invalidLines = 0;
    for (final line in const LineSplitter().convert(text)) {
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, Object?>) {
          invalidLines += 1;
          continue;
        }
        records.add(decoded);
      } on FormatException {
        invalidLines += 1;
      }
    }
    return JsonlRecoveryResult(
      records: records,
      truncatedTailIgnored: truncated,
      invalidLines: invalidLines,
    );
  }

  Future<void> _rotate() async {
    if (await _pendingFile.exists()) {
      await _pendingFile.delete();
    }
    if (await currentFile.exists()) {
      await currentFile.rename(_pendingFile.path);
    }
    if (await previousFile.exists()) {
      await previousFile.delete();
    }
    if (await _pendingFile.exists()) {
      await _pendingFile.rename(previousFile.path);
    }
    _rotations += 1;
  }

  Future<void> _recoverInterruptedRotation() async {
    if (!await _pendingFile.exists()) {
      return;
    }
    if (await previousFile.exists()) {
      await previousFile.delete();
    }
    await _pendingFile.rename(previousFile.path);
  }

  Future<bool> _truncatePartialTail(File file) async {
    if (!await file.exists()) {
      return false;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.last == 10) {
      return false;
    }
    final lastNewline = bytes.lastIndexOf(10);
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.truncate(lastNewline + 1);
      await handle.flush();
    } finally {
      await handle.close();
    }
    return true;
  }

  Future<void> _enforceTwoSegments() async {
    final allowed = <String>{currentFile.path, previousFile.path};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path).startsWith(fileStem) &&
          !allowed.contains(entity.path)) {
        await entity.delete();
      }
    }
    final currentLength =
        await currentFile.exists() ? await currentFile.length() : 0;
    final previousLength =
        await previousFile.exists() ? await previousFile.length() : 0;
    if (currentLength > policy.segmentBytes ||
        previousLength > policy.segmentBytes ||
        currentLength + previousLength > policy.totalBytes) {
      throw const FileSystemException('operational_volume_cap_exceeded');
    }
  }
}
