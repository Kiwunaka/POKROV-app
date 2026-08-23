library pokrov_diagnostics_collectors;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pokrov_observability_contracts/observability_contracts.dart';

enum SupportDiagnosticProfile { summary, standard, extended, crash }

enum DiagnosticCategory { build, system, network, events, crashes, redaction }

enum DiagnosticRemovalReason {
  forbiddenField,
  invalidValue,
  eventsTruncated,
  crashesTruncated,
  optionalCategoryRemoved,
}

final class DiagnosticBuildSummary {
  DiagnosticBuildSummary({
    required this.platform,
    required this.appVersion,
    required this.buildId,
    required this.channel,
  }) {
    _requireToken(platform, 'platform', <String>{'android', 'windows'});
    _requireMatch(appVersion, 'appVersion', RegExp(r'^[0-9A-Za-z.+-]{1,48}$'));
    _requireMatch(buildId, 'buildId', RegExp(r'^[0-9A-Za-z._-]{1,80}$'));
    _requireToken(channel, 'channel', <String>{'direct', 'store', 'stable'});
  }

  final String platform;
  final String appVersion;
  final String buildId;
  final String channel;

  Map<String, Object?> toJson() => <String, Object?>{
        'app_version': appVersion,
        'build_id': buildId,
        'channel': channel,
        'platform': platform,
      };
}

final class DiagnosticSystemSummary {
  DiagnosticSystemSummary({
    required this.osFamily,
    required this.osVersion,
    required this.architecture,
    required this.locale,
  }) {
    _requireToken(osFamily, 'osFamily', <String>{'android', 'windows'});
    _requireMatch(osVersion, 'osVersion', RegExp(r'^[0-9A-Za-z ._()-]{1,80}$'));
    _requireToken(architecture, 'architecture', <String>{
      'arm64',
      'arm',
      'x64',
      'x86',
    });
    _requireMatch(locale, 'locale', RegExp(r'^[a-z]{2}(?:-[A-Z]{2})?$'));
  }

  final String osFamily;
  final String osVersion;
  final String architecture;
  final String locale;

  Map<String, Object?> toJson() => <String, Object?>{
        'architecture': architecture,
        'locale': locale,
        'os_family': osFamily,
        'os_version': osVersion,
      };
}

final class DiagnosticNetworkSummary {
  DiagnosticNetworkSummary({
    required this.routeMode,
    required this.connectionState,
    required this.hostHealth,
    required this.dnsState,
    required this.egressState,
    required this.warpState,
  }) {
    _requireToken(routeMode, 'routeMode', <String>{
      'all_except_ru',
      'excluded_apps',
      'full_tunnel',
      'selected_apps',
    });
    _requireToken(connectionState, 'connectionState', <String>{
      'blocked',
      'connecting',
      'degraded',
      'disconnected',
      'verified',
    });
    for (final entry in <String, String>{
      'hostHealth': hostHealth,
      'dnsState': dnsState,
      'egressState': egressState,
    }.entries) {
      _requireToken(entry.value, entry.key, <String>{
        'failed',
        'healthy',
        'pending',
        'unavailable',
        'unknown',
      });
    }
    _requireToken(warpState, 'warpState', <String>{
      'disabled',
      'enabled',
      'fallback',
      'unavailable',
    });
  }

  final String routeMode;
  final String connectionState;
  final String hostHealth;
  final String dnsState;
  final String egressState;
  final String warpState;

  Map<String, Object?> toJson() => <String, Object?>{
        'connection_state': connectionState,
        'dns_state': dnsState,
        'egress_state': egressState,
        'host_health': hostHealth,
        'route_mode': routeMode,
        'warp_state': warpState,
      };
}

final class DiagnosticEventRecord {
  DiagnosticEventRecord({
    required this.occurredAt,
    required this.subsystem,
    required this.stage,
    required this.outcome,
    this.errorCode,
    this.durationMs,
  }) {
    _requireUtc(occurredAt, 'occurredAt');
    _requireMatch(subsystem, 'subsystem', RegExp(r'^[a-z][a-z0-9_]{0,31}$'));
    _requireMatch(stage, 'stage', RegExp(r'^[a-z][a-z0-9_]{0,31}$'));
    _requireToken(outcome, 'outcome', <String>{
      'cancelled',
      'crashed',
      'failed',
      'observed',
      'started',
      'succeeded',
      'superseded',
      'timeout',
    });
    final code = errorCode;
    if (code != null && !KnownOperationalErrorCodes.contains(code)) {
      throw ArgumentError.value(code, 'errorCode');
    }
    if (durationMs != null && (durationMs! < 0 || durationMs! > 86400000)) {
      throw ArgumentError.value(durationMs, 'durationMs');
    }
  }

  final DateTime occurredAt;
  final String subsystem;
  final String stage;
  final String outcome;
  final String? errorCode;
  final int? durationMs;

  Map<String, Object?> toJson() => <String, Object?>{
        if (durationMs != null) 'duration_ms': durationMs,
        if (errorCode != null) 'error_code': errorCode,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'outcome': outcome,
        'stage': stage,
        'subsystem': subsystem,
      };
}

final class DiagnosticCrashRecord {
  DiagnosticCrashRecord({
    required this.occurredAt,
    required this.errorCode,
    required this.signature,
  }) {
    _requireUtc(occurredAt, 'occurredAt');
    if (!KnownOperationalErrorCodes.contains(errorCode) ||
        !errorCode.startsWith('CRASH-')) {
      throw ArgumentError.value(errorCode, 'errorCode');
    }
    _requireMatch(signature, 'signature', RegExp(r'^[a-f0-9]{16,64}$'));
  }

  final DateTime occurredAt;
  final String errorCode;
  final String signature;

  Map<String, Object?> toJson() => <String, Object?>{
        'error_code': errorCode,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'signature': signature,
      };
}

final class DiagnosticSnapshot {
  DiagnosticSnapshot({
    required this.build,
    required this.network,
    this.system,
    List<DiagnosticEventRecord> events = const <DiagnosticEventRecord>[],
    List<DiagnosticCrashRecord> crashes = const <DiagnosticCrashRecord>[],
    Map<DiagnosticRemovalReason, int> removalCounts =
        const <DiagnosticRemovalReason, int>{},
  })  : events = List<DiagnosticEventRecord>.unmodifiable(events),
        crashes = List<DiagnosticCrashRecord>.unmodifiable(crashes),
        removalCounts = Map<DiagnosticRemovalReason, int>.unmodifiable(
          removalCounts,
        ) {
    if (events.length > 2000 || crashes.length > 100) {
      throw ArgumentError('Diagnostic snapshot exceeds bounded input counts.');
    }
    for (final count in removalCounts.values) {
      if (count < 0 || count > 1000000) {
        throw ArgumentError.value(count, 'removalCounts');
      }
    }
  }

  final DiagnosticBuildSummary build;
  final DiagnosticSystemSummary? system;
  final DiagnosticNetworkSummary network;
  final List<DiagnosticEventRecord> events;
  final List<DiagnosticCrashRecord> crashes;
  final Map<DiagnosticRemovalReason, int> removalCounts;
}

final class CollectedDiagnosticFile {
  CollectedDiagnosticFile({
    required this.path,
    required this.category,
    required List<int> bytes,
  }) : bytes = List<int>.unmodifiable(bytes) {
    if (!_fixedPaths.contains(path) || bytes.isEmpty) {
      throw ArgumentError('Diagnostic file path or content is invalid.');
    }
  }

  final String path;
  final DiagnosticCategory category;
  final List<int> bytes;

  static const Set<String> _fixedPaths = <String>{
    'build/identity.json',
    'crash/index.jsonl',
    'events/recent.jsonl',
    'network/summary.json',
    'redaction/report.json',
    'system/summary.json',
  };
}

final class DiagnosticCollection {
  DiagnosticCollection({
    required List<CollectedDiagnosticFile> files,
    required Map<DiagnosticRemovalReason, int> removalCounts,
  })  : files = List<CollectedDiagnosticFile>.unmodifiable(files),
        removalCounts = Map<DiagnosticRemovalReason, int>.unmodifiable(
          removalCounts,
        );

  final List<CollectedDiagnosticFile> files;
  final Map<DiagnosticRemovalReason, int> removalCounts;
}

final class BoundedDiagnosticsCollector {
  const BoundedDiagnosticsCollector();

  static const int maximumEventBytes = 256 * 1024;
  static const int maximumCrashBytes = 64 * 1024;

  DiagnosticCollection collect({
    required DiagnosticSnapshot snapshot,
    required SupportDiagnosticProfile profile,
    Set<DiagnosticCategory> excludedOptionalCategories =
        const <DiagnosticCategory>{},
  }) {
    const optional = <DiagnosticCategory>{
      DiagnosticCategory.system,
      DiagnosticCategory.events,
      DiagnosticCategory.crashes,
    };
    if (excludedOptionalCategories.any((value) => !optional.contains(value))) {
      throw ArgumentError(
        'Only optional diagnostic categories may be removed.',
      );
    }
    final categories = _profileCategories(profile)
      ..removeAll(excludedOptionalCategories);
    final removals = Map<DiagnosticRemovalReason, int>.from(
      snapshot.removalCounts,
    );
    if (excludedOptionalCategories.isNotEmpty) {
      removals[DiagnosticRemovalReason.optionalCategoryRemoved] =
          (removals[DiagnosticRemovalReason.optionalCategoryRemoved] ?? 0) +
              excludedOptionalCategories.length;
    }

    final files = <CollectedDiagnosticFile>[];
    void addJson(String path, DiagnosticCategory category, Object value) {
      files.add(
        CollectedDiagnosticFile(
          path: path,
          category: category,
          bytes: Uint8List.fromList(utf8.encode(jsonEncode(value))),
        ),
      );
    }

    addJson(
      'build/identity.json',
      DiagnosticCategory.build,
      snapshot.build.toJson(),
    );
    addJson(
      'network/summary.json',
      DiagnosticCategory.network,
      snapshot.network.toJson(),
    );
    if (categories.contains(DiagnosticCategory.system)) {
      final system = snapshot.system;
      if (system == null) {
        throw StateError(
          'The selected diagnostic profile requires a system summary.',
        );
      }
      addJson(
        'system/summary.json',
        DiagnosticCategory.system,
        system.toJson(),
      );
    }
    if (categories.contains(DiagnosticCategory.events)) {
      final bounded = _boundedJsonLines(
        snapshot.events.map((event) => event.toJson()),
        maximumEventBytes,
      );
      if (bounded.dropped > 0) {
        removals[DiagnosticRemovalReason.eventsTruncated] =
            (removals[DiagnosticRemovalReason.eventsTruncated] ?? 0) +
                bounded.dropped;
      }
      files.add(
        CollectedDiagnosticFile(
          path: 'events/recent.jsonl',
          category: DiagnosticCategory.events,
          bytes: bounded.bytes,
        ),
      );
    }
    if (categories.contains(DiagnosticCategory.crashes)) {
      final bounded = _boundedJsonLines(
        snapshot.crashes.map((crash) => crash.toJson()),
        maximumCrashBytes,
      );
      if (bounded.dropped > 0) {
        removals[DiagnosticRemovalReason.crashesTruncated] =
            (removals[DiagnosticRemovalReason.crashesTruncated] ?? 0) +
                bounded.dropped;
      }
      files.add(
        CollectedDiagnosticFile(
          path: 'crash/index.jsonl',
          category: DiagnosticCategory.crashes,
          bytes: bounded.bytes,
        ),
      );
    }
    addJson(
      'redaction/report.json',
      DiagnosticCategory.redaction,
      <String, Object?>{
        'removed': <String, Object?>{
          for (final reason in DiagnosticRemovalReason.values)
            reason.name: removals[reason] ?? 0,
        },
        'schema_version': 1,
      },
    );
    files.sort((left, right) => left.path.compareTo(right.path));
    return DiagnosticCollection(files: files, removalCounts: removals);
  }

  Set<DiagnosticCategory> _profileCategories(
    SupportDiagnosticProfile profile,
  ) =>
      switch (profile) {
        SupportDiagnosticProfile.summary => <DiagnosticCategory>{
            DiagnosticCategory.build,
            DiagnosticCategory.network,
            DiagnosticCategory.redaction,
          },
        SupportDiagnosticProfile.standard => <DiagnosticCategory>{
            DiagnosticCategory.build,
            DiagnosticCategory.system,
            DiagnosticCategory.network,
            DiagnosticCategory.events,
            DiagnosticCategory.redaction,
          },
        SupportDiagnosticProfile.extended ||
        SupportDiagnosticProfile.crash =>
          <DiagnosticCategory>{
            DiagnosticCategory.build,
            DiagnosticCategory.system,
            DiagnosticCategory.network,
            DiagnosticCategory.events,
            DiagnosticCategory.crashes,
            DiagnosticCategory.redaction,
          },
      };
}

final class _BoundedLines {
  const _BoundedLines(this.bytes, this.dropped);

  final Uint8List bytes;
  final int dropped;
}

_BoundedLines _boundedJsonLines(
  Iterable<Map<String, Object?>> values,
  int maximumBytes,
) {
  final encoded = <List<int>>[
    for (final value in values) utf8.encode('${jsonEncode(value)}\n'),
  ];
  final kept = <List<int>>[];
  var total = 0;
  for (final line in encoded.reversed) {
    if (line.length > maximumBytes || total + line.length > maximumBytes) {
      continue;
    }
    kept.add(line);
    total += line.length;
  }
  final bytes = BytesBuilder(copy: false);
  for (final line in kept.reversed) {
    bytes.add(line);
  }
  if (total == 0) {
    bytes.add(const <int>[0x0A]);
  }
  return _BoundedLines(bytes.takeBytes(), encoded.length - kept.length);
}

void _requireToken(String value, String name, Set<String> allowed) {
  if (!allowed.contains(value)) {
    throw ArgumentError.value(value, name);
  }
}

void _requireMatch(String value, String name, RegExp expression) {
  if (!expression.hasMatch(value)) {
    throw ArgumentError.value(value, name);
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc || value.year < 2020 || value.year > 2100) {
    throw ArgumentError.value(value, name);
  }
}
