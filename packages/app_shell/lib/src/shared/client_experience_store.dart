part of pokrov_app_shell;

enum PokrovProtectionEventTone { success, warning, error, neutral }

class PokrovProtectionEvent {
  const PokrovProtectionEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.occurredAt,
    required this.tone,
  });

  final String id;
  final String kind;
  final String title;
  final String detail;
  final String occurredAt;
  final PokrovProtectionEventTone tone;

  factory PokrovProtectionEvent.fromJson(Map<String, dynamic> json) {
    final toneName = _experienceText(json['tone']);
    return PokrovProtectionEvent(
      id: _boundedExperienceText(json['id'], maxLength: 80),
      kind: _boundedExperienceText(json['kind'], maxLength: 32),
      title: _boundedExperienceText(json['title'], maxLength: 80),
      detail: _boundedExperienceText(json['detail'], maxLength: 180),
      occurredAt: _validExperienceIso(json['occurredAt']),
      tone: PokrovProtectionEventTone.values.firstWhere(
        (item) => item.name == toneName,
        orElse: () => PokrovProtectionEventTone.neutral,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title,
        'detail': detail,
        'occurredAt': occurredAt,
        'tone': tone.name,
      };
}

class PokrovPostConnectShortcut {
  const PokrovPostConnectShortcut({
    required this.id,
    required this.label,
    required this.href,
  });

  final String id;
  final String label;
  final Uri href;

  static PokrovPostConnectShortcut? tryCreate({
    required String label,
    required String href,
  }) {
    final normalizedLabel = label.trim();
    final uri = Uri.tryParse(href.trim());
    if (normalizedLabel.isEmpty ||
        normalizedLabel.length > 40 ||
        uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final id = base64Url
        .encode(
            utf8.encode('${normalizedLabel.toLowerCase()}|${uri.toString()}'))
        .replaceAll('=', '');
    return PokrovPostConnectShortcut(
      id: id.length > 72 ? id.substring(0, 72) : id,
      label: normalizedLabel,
      href: uri,
    );
  }

  factory PokrovPostConnectShortcut.fromJson(Map<String, dynamic> json) {
    return tryCreate(
          label: _experienceText(json['label']),
          href: _experienceText(json['href']),
        ) ??
        PokrovPostConnectShortcut(
          id: '',
          label: '',
          href: Uri.https('invalid.local', '/'),
        );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'href': href.toString(),
      };
}

class PokrovClientExperienceState {
  const PokrovClientExperienceState({
    required this.favoriteNodeCodes,
    required this.recentNodeCodes,
    required this.protectionEvents,
    required this.postConnectShortcuts,
    required this.cachedLocations,
    required this.locationsCachedAt,
    required this.cachedNotifications,
    required this.notificationsCachedAt,
    this.routingPreferences = const PokrovRoutingPreferences.defaults(),
  });

  const PokrovClientExperienceState.empty()
      : favoriteNodeCodes = const <String>[],
        recentNodeCodes = const <String>[],
        protectionEvents = const <PokrovProtectionEvent>[],
        postConnectShortcuts = const <PokrovPostConnectShortcut>[],
        cachedLocations = null,
        locationsCachedAt = '',
        cachedNotifications = null,
        notificationsCachedAt = '',
        routingPreferences = const PokrovRoutingPreferences.defaults();

  final List<String> favoriteNodeCodes;
  final List<String> recentNodeCodes;
  final List<PokrovProtectionEvent> protectionEvents;
  final List<PokrovPostConnectShortcut> postConnectShortcuts;
  final ClientLocationsCatalog? cachedLocations;
  final String locationsCachedAt;
  final ClientNotificationInbox? cachedNotifications;
  final String notificationsCachedAt;
  final PokrovRoutingPreferences routingPreferences;

  PokrovClientExperienceState copyWith({
    List<String>? favoriteNodeCodes,
    List<String>? recentNodeCodes,
    List<PokrovProtectionEvent>? protectionEvents,
    List<PokrovPostConnectShortcut>? postConnectShortcuts,
    ClientLocationsCatalog? cachedLocations,
    String? locationsCachedAt,
    ClientNotificationInbox? cachedNotifications,
    String? notificationsCachedAt,
    PokrovRoutingPreferences? routingPreferences,
  }) {
    return PokrovClientExperienceState(
      favoriteNodeCodes: favoriteNodeCodes ?? this.favoriteNodeCodes,
      recentNodeCodes: recentNodeCodes ?? this.recentNodeCodes,
      protectionEvents: protectionEvents ?? this.protectionEvents,
      postConnectShortcuts: postConnectShortcuts ?? this.postConnectShortcuts,
      cachedLocations: cachedLocations ?? this.cachedLocations,
      locationsCachedAt: locationsCachedAt ?? this.locationsCachedAt,
      cachedNotifications: cachedNotifications ?? this.cachedNotifications,
      notificationsCachedAt:
          notificationsCachedAt ?? this.notificationsCachedAt,
      routingPreferences: routingPreferences ?? this.routingPreferences,
    );
  }

  factory PokrovClientExperienceState.fromJson(Map<String, dynamic> json) {
    final favorites =
        _experienceNodeCodes(json['favoriteNodeCodes'], limit: 50);
    final recents = _experienceNodeCodes(json['recentNodeCodes'], limit: 12);
    final events = _experienceListOfMaps(json['protectionEvents'])
        .map(PokrovProtectionEvent.fromJson)
        .where((item) => item.id.isNotEmpty && item.occurredAt.isNotEmpty)
        .take(20)
        .toList(growable: false);
    final shortcuts = _experienceListOfMaps(json['postConnectShortcuts'])
        .map(PokrovPostConnectShortcut.fromJson)
        .where((item) => item.id.isNotEmpty)
        .take(6)
        .toList(growable: false);
    final locationsJson = _experienceMap(json['cachedLocations']);
    final notificationsJson = _experienceMap(json['cachedNotifications']);
    return PokrovClientExperienceState(
      favoriteNodeCodes: favorites,
      recentNodeCodes: recents,
      protectionEvents: events,
      postConnectShortcuts: shortcuts,
      cachedLocations: locationsJson.isEmpty
          ? null
          : ClientLocationsCatalog.fromJson(locationsJson),
      locationsCachedAt: _validExperienceIso(json['locationsCachedAt']),
      cachedNotifications: notificationsJson.isEmpty
          ? null
          : ClientNotificationInbox.fromJson(notificationsJson),
      notificationsCachedAt: _validExperienceIso(json['notificationsCachedAt']),
      routingPreferences: PokrovRoutingPreferences.fromJson(
        _experienceMap(json['routingPreferences']),
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 1,
        'favoriteNodeCodes': favoriteNodeCodes.take(50).toList(growable: false),
        'recentNodeCodes': recentNodeCodes.take(12).toList(growable: false),
        'protectionEvents': protectionEvents
            .take(20)
            .map((item) => item.toJson())
            .toList(growable: false),
        'postConnectShortcuts': postConnectShortcuts
            .take(6)
            .map((item) => item.toJson())
            .toList(growable: false),
        if (cachedLocations != null)
          'cachedLocations': cachedLocations!.toJson(),
        'locationsCachedAt': locationsCachedAt,
        if (cachedNotifications != null)
          'cachedNotifications': cachedNotifications!.toJson(),
        'notificationsCachedAt': notificationsCachedAt,
        'routingPreferences': routingPreferences.toJson(),
      };
}

abstract class PokrovClientExperienceStore {
  Future<PokrovClientExperienceState> read();
  Future<void> write(PokrovClientExperienceState state);
}

class PokrovFileClientExperienceStore implements PokrovClientExperienceStore {
  const PokrovFileClientExperienceStore({this.supportDirectoryResolver});

  static const _fileName = 'pokrov-client-experience-v1.json';
  final Future<Directory> Function()? supportDirectoryResolver;

  Future<File> _stateFile() async {
    final directory = await (supportDirectoryResolver?.call() ??
        getApplicationSupportDirectory());
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<PokrovClientExperienceState> read() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return const PokrovClientExperienceState.empty();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return const PokrovClientExperienceState.empty();
      }
      return PokrovClientExperienceState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on Object {
      return const PokrovClientExperienceState.empty();
    }
  }

  @override
  Future<void> write(PokrovClientExperienceState state) async {
    try {
      final file = await _stateFile();
      await file.writeAsString(jsonEncode(state.toJson()), flush: true);
    } on Object {
      // Local convenience state is best-effort and never blocks VPN control.
    }
  }
}

String _boundedExperienceText(Object? value, {required int maxLength}) {
  final text = _experienceText(value);
  return text.length <= maxLength ? text : text.substring(0, maxLength);
}

String _validExperienceIso(Object? value) {
  final text = _experienceText(value);
  return DateTime.tryParse(text) == null ? '' : text;
}

List<String> _experienceNodeCodes(Object? value, {required int limit}) {
  if (value is! List) {
    return const <String>[];
  }
  final pattern = RegExp(r'^[a-z0-9._-]{1,64}$');
  final result = <String>[];
  for (final item in value) {
    final code = _experienceText(item).toLowerCase();
    if (!pattern.hasMatch(code) || result.contains(code)) {
      continue;
    }
    result.add(code);
    if (result.length >= limit) {
      break;
    }
  }
  return List<String>.unmodifiable(result);
}

String _experienceText(Object? value) {
  return value == null ? '' : value.toString().trim();
}

Map<String, dynamic> _experienceMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _experienceListOfMaps(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}
