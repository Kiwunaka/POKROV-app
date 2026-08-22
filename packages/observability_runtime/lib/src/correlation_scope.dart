import 'dart:async';

import 'ids.dart';

abstract final class PortalCorrelationScope {
  static final Object _zoneKey = Object();
  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static String? get current {
    final value = Zone.current[_zoneKey];
    return value is String && _uuidV4.hasMatch(value) ? value : null;
  }

  static String currentOrCreate([OperationalIdFactory? ids]) =>
      current ?? (ids ?? OperationalIdFactory()).uuidV4();

  static Future<T> run<T>(String correlationId, Future<T> Function() body) {
    if (!_uuidV4.hasMatch(correlationId)) {
      throw ArgumentError.value(correlationId, 'correlationId');
    }
    return runZoned(body, zoneValues: <Object, Object>{
      _zoneKey: correlationId,
    });
  }
}
