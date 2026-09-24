part of pokrov_runtime_engine;

String? _coreModuleDigestFromWire(Object? value) => value is String &&
    RegExp(r'^[a-f0-9]{64}$').hasMatch(value) ? value : null;

class RuntimeTransportCapabilities {
  RuntimeTransportCapabilities._(this.canonicalJson, Set<RuntimeTransportFeature> features)
      : features = Set.unmodifiable(features);

  final String canonicalJson;
  final Set<RuntimeTransportFeature> features;

  /// Missing, oversized, malformed or unknown inventory cannot authorize a
  /// selector candidate. Existing ordinary runtime compatibility is unchanged.
  static RuntimeTransportCapabilities? fromWire(Object? value) {
    if (value is! String || value.isEmpty || value.length > 4096) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map || decoded.length != 2 || decoded['schema'] is! int ||
          decoded['schema'] != 1 || decoded['features'] is! List) return null;
      final names = decoded['features'] as List;
      if (names.isEmpty || names.length > RuntimeTransportFeature.values.length) return null;
      final features = <RuntimeTransportFeature>{};
      String? previous;
      for (final name in names) {
        if (name is! String || (previous != null && previous.compareTo(name) >= 0)) return null;
        final matching = RuntimeTransportFeature.values.where((item) => item.wireName == name);
        if (matching.isEmpty) return null;
        features.add(matching.single);
        previous = name;
      }
      if (features.contains(RuntimeTransportFeature.reality) &&
          !features.containsAll({RuntimeTransportFeature.utls, RuntimeTransportFeature.tls})) return null;
      final canonical = jsonEncode({'schema': 1, 'features': names});
      if (canonical != value) return null;
      return RuntimeTransportCapabilities._(canonical, features);
    } on FormatException {
      return null;
    }
  }
}

/// Optional loaded binding extension; absence is unavailable, not support.
abstract interface class RuntimeTransportCapabilitySource {
  RuntimeTransportCapabilities? get transportCapabilities;
}

RuntimeTransportCapabilities? _readCoreTransportCapabilities(DynamicLibrary library) {
  late final Pointer<Char> Function() read;
  late final void Function(Pointer<Char>) release;
  try {
    read = library.lookupFunction<Pointer<Char> Function(), Pointer<Char> Function()>(
        'pokrovCoreTransportCapabilities');
    release = library.lookupFunction<Void Function(Pointer<Char>), void Function(Pointer<Char>)>('freeString');
  } on ArgumentError {
    return null;
  }
  final pointer = read();
  if (pointer == nullptr) return null;
  try {
    final bytes = pointer.cast<Uint8>();
    var length = 0;
    while (length <= 4096 && bytes[length] != 0) { length++; }
    if (length > 4096) return null;
    return RuntimeTransportCapabilities.fromWire(utf8.decode(bytes.asTypedList(length)));
  } on FormatException {
    return null;
  } finally {
    release(pointer);
  }
}
