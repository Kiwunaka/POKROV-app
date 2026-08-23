import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

import '../../../app_first_runtime_bootstrap.dart';

final class PokrovSupportModeView {
  const PokrovSupportModeView({
    required this.active,
    required this.expiresAt,
    required this.allowedCategories,
    required this.maximumTotalBytes,
    required this.consumedBytes,
    required this.maximumBundles,
    required this.consumedBundles,
  });

  const PokrovSupportModeView.inactive()
      : active = false,
        expiresAt = null,
        allowedCategories = const <DiagnosticCategory>[],
        maximumTotalBytes = 0,
        consumedBytes = 0,
        maximumBundles = 0,
        consumedBundles = 0;

  final bool active;
  final DateTime? expiresAt;
  final List<DiagnosticCategory> allowedCategories;
  final int maximumTotalBytes;
  final int consumedBytes;
  final int maximumBundles;
  final int consumedBundles;
}

final class PokrovPersistentSupportModeBanner extends StatelessWidget {
  const PokrovPersistentSupportModeBanner({
    required this.view,
    required this.onOpenDiagnostics,
    required this.onDisable,
    super.key,
  });

  final PokrovSupportModeView view;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final expiresAt = view.expiresAt?.toLocal();
    final expires = expiresAt == null
        ? '—'
        : '${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Включен временный режим поддержки до $expires',
      child: Material(
        key: const ValueKey('persistent-support-mode-banner'),
        color: colors.tertiaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onOpenDiagnostics,
                    child: Text(
                      'Режим поддержки до $expires · ${view.consumedBundles}/${view.maximumBundles} пакетов',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('persistent-support-mode-disable'),
                  onPressed: onDisable,
                  child: const Text('Выключить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class PokrovSupportModeController extends ChangeNotifier {
  PokrovSupportModeController({
    required Map<String, String> signingPublicKeysById,
    required this.platform,
    required this.appVersion,
    required this.buildNumber,
    Future<Directory> Function()? directoryResolver,
    DateTime Function()? clock,
  })  : _signingPublicKeysById = Map<String, String>.unmodifiable(
          signingPublicKeysById,
        ),
        _directoryResolver =
            directoryResolver ?? getApplicationSupportDirectory,
        _clock = clock ?? DateTime.now;

  static const _maximumStateBytes = 32 * 1024;
  static const _maximumRememberedNonces = 32;
  final Map<String, String> _signingPublicKeysById;
  final String platform;
  final String appVersion;
  final String buildNumber;
  final Future<Directory> Function() _directoryResolver;
  final DateTime Function() _clock;
  final Set<String> _usedNonces = <String>{};
  SupportModeActivation? _activation;
  SupportModeUsageLedger? _usage;
  Timer? _expiryTimer;
  bool _loaded = false;

  bool get loaded => _loaded;
  VerifiedSupportCollectionPolicy? get activePolicy {
    final activation = _activation;
    final usage = _usage;
    if (activation == null ||
        usage == null ||
        !usage.isActive(_clock().toUtc())) {
      return null;
    }
    return activation.policy;
  }

  PokrovSupportModeView get view {
    final policy = activePolicy;
    final usage = _usage;
    if (policy == null || usage == null) {
      return const PokrovSupportModeView.inactive();
    }
    final categories = policy.allowedCategories.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return PokrovSupportModeView(
      active: true,
      expiresAt: policy.expiresAt,
      allowedCategories: categories,
      maximumTotalBytes: policy.maximumTotalBytes,
      consumedBytes: usage.consumedBytes,
      maximumBundles: policy.maximumBundles,
      consumedBundles: usage.consumedBundles,
    );
  }

  Future<File> _file() async {
    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}support-mode-state-v1.json',
    );
  }

  Future<void> initialize() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final file = await _file();
      if (!await file.exists() || await file.length() > _maximumStateBytes) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map ||
          decoded.length != 3 ||
          decoded['schema_version'] != 1 ||
          decoded['used_nonces'] is! List ||
          !decoded.containsKey('session')) {
        throw const FormatException('support mode state invalid');
      }
      final nonces = (decoded['used_nonces'] as List)
          .whereType<String>()
          .where((value) => RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value))
          .take(_maximumRememberedNonces);
      _usedNonces.addAll(nonces);
      final rawSession = decoded['session'];
      if (rawSession == null) {
        return;
      }
      if (rawSession is! Map ||
          rawSession.length != 4 ||
          rawSession['signed_policy'] is! Map ||
          rawSession['consumed_bytes'] is! int ||
          rawSession['consumed_diagnostic_ids'] is! List ||
          rawSession['disabled'] is! bool) {
        throw const FormatException('support mode session invalid');
      }
      final envelope =
          (rawSession['signed_policy'] as Map).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final policy = await _verify(envelope);
      if (!_usedNonces.contains(policy.nonce) ||
          !_clock().toUtc().isBefore(policy.expiresAt)) {
        await _persist(session: null);
        return;
      }
      final activation = SupportModeActivation(
        signedPolicy: envelope,
        policy: policy,
      );
      final usage = SupportModeUsageLedger(
        policy: policy,
        consumedBytes: rawSession['consumed_bytes'] as int,
        consumedDiagnosticIds:
            (rawSession['consumed_diagnostic_ids'] as List).whereType<String>(),
        disabled: rawSession['disabled'] as bool,
      );
      if (!usage.isActive(_clock().toUtc())) {
        await _persist(session: null);
        return;
      }
      _activation = activation;
      _usage = usage;
      _armExpiry();
      notifyListeners();
    } on Object {
      _activation = null;
      _usage = null;
      try {
        final file = await _file();
        if (await file.exists()) {
          await file.delete();
        }
      } on Object {
        // Corrupt local state stays fail-closed even when cleanup is denied.
      }
    }
  }

  Future<void> activate(
    SupportModeActivation activation, {
    required bool userConfirmed,
  }) async {
    if (!userConfirmed) {
      throw const SupportBundleFailure('support_mode_confirmation_required');
    }
    final policy = await _verify(activation.signedPolicy);
    if (policy.policyId != activation.policy.policyId ||
        policy.nonce != activation.policy.nonce ||
        _usedNonces.contains(policy.nonce)) {
      throw const SupportBundleFailure('support_mode_replay_rejected');
    }
    _usedNonces.add(policy.nonce);
    while (_usedNonces.length > _maximumRememberedNonces) {
      _usedNonces.remove(_usedNonces.first);
    }
    _activation = SupportModeActivation(
      signedPolicy: activation.signedPolicy,
      policy: policy,
    );
    _usage = SupportModeUsageLedger(policy: policy);
    await _persist();
    _armExpiry();
    notifyListeners();
  }

  Future<void> registerBundle(PreparedSupportBundle prepared) async {
    final usage = _usage;
    if (usage == null) {
      throw const SupportBundleFailure('support_mode_inactive');
    }
    usage.register(prepared, now: _clock().toUtc());
    await _persist();
    notifyListeners();
  }

  Future<void> disable() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _usage?.disable();
    _activation = null;
    _usage = null;
    await _persist(session: null);
    notifyListeners();
  }

  Future<VerifiedSupportCollectionPolicy> _verify(
    Map<String, Object?> envelope,
  ) =>
      SupportSignedContractVerifier(
        signingPublicKeysById: _signingPublicKeysById,
      ).verifyCollectionPolicy(
        envelope,
        now: _clock().toUtc(),
        platform: platform,
        appVersion: appVersion,
        buildNumber: buildNumber,
      );

  void _armExpiry() {
    _expiryTimer?.cancel();
    final policy = activePolicy;
    if (policy == null) {
      return;
    }
    final remaining = policy.expiresAt.difference(_clock().toUtc());
    if (remaining <= Duration.zero) {
      unawaited(disable());
      return;
    }
    _expiryTimer = Timer(remaining, () => unawaited(disable()));
  }

  Future<void> _persist({Object? session = _currentSessionMarker}) async {
    final file = await _file();
    final next = File('${file.path}.next');
    final selectedSession = identical(session, _currentSessionMarker)
        ? _serializedSession()
        : session;
    final payload = <String, Object?>{
      'schema_version': 1,
      'session': selectedSession,
      'used_nonces': _usedNonces.toList(growable: false),
    };
    await next.writeAsString(jsonEncode(payload), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await next.rename(file.path);
  }

  Map<String, Object?>? _serializedSession() {
    final activation = _activation;
    final usage = _usage;
    if (activation == null || usage == null) {
      return null;
    }
    return <String, Object?>{
      'consumed_bytes': usage.consumedBytes,
      'consumed_diagnostic_ids': usage.consumedDiagnosticIds.toList(),
      'disabled': usage.disabled,
      'signed_policy': activation.signedPolicy,
    };
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

const _currentSessionMarker = Object();
