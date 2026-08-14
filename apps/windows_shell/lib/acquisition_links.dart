import 'dart:async';

import 'package:flutter/services.dart';

final class PokrovWindowsAcquisitionLinks {
  PokrovWindowsAcquisitionLinks({
    MethodChannel channel = const MethodChannel(
      'space.pokrov/acquisition-links',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  Stream<Uri> get stream => _controller.stream;

  Future<Uri?> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'uriChanged') {
        final uri = _safeUri(call.arguments);
        if (uri != null && !_controller.isClosed) {
          _controller.add(uri);
        }
      }
    });
    try {
      return _safeUri(await _channel.invokeMethod<String>('getInitialUri'));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }

  static Uri? _safeUri(Object? value) {
    if (value is! String || value.length > 512) {
      return null;
    }
    return Uri.tryParse(value.trim());
  }
}
