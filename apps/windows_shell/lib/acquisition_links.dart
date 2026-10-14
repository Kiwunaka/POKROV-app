import 'dart:async';

import 'package:flutter/services.dart';

final class PokrovWindowsAcquisitionLinks {
  PokrovWindowsAcquisitionLinks({
    MethodChannel channel = const MethodChannel(
      'space.pokrov/acquisition-links',
    ),
  }) : _channel = channel {
    _controller = StreamController<Uri>.broadcast(onListen: () {
      final pending = _pendingUri;
      _pendingUri = null;
      if (pending != null) _controller.add(pending);
    });
  }

  final MethodChannel _channel;
  late final StreamController<Uri> _controller;
  Uri? _pendingUri;

  Stream<Uri> get stream => _controller.stream;

  Future<Uri?> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'uriChanged') {
        final uri = _safeUri(call.arguments);
        if (uri != null && !_controller.isClosed) {
          if (_controller.hasListener) {
            _controller.add(uri);
          } else {
            // main awaits startup services before the shell subscribes.
            _pendingUri = uri;
          }
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
    _pendingUri = null;
    await _controller.close();
  }

  static Uri? _safeUri(Object? value) {
    if (value is! String || value.length > 512) {
      return null;
    }
    return Uri.tryParse(value.trim());
  }
}
