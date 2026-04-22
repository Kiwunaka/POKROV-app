import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ios shell project wires a packet-tunnel extension scaffold', () {
    final projectRoot = Directory.current.path;
    final extensionDirectory = Directory(
      '$projectRoot/ios/PacketTunnelExtension',
    );
    final providerFile = File(
      '$projectRoot/ios/PacketTunnelExtension/PacketTunnelProvider.swift',
    );
    final infoPlist = File('$projectRoot/ios/PacketTunnelExtension/Info.plist');
    final entitlementsFile = File(
      '$projectRoot/ios/PacketTunnelExtension/PacketTunnelExtension.entitlements',
    );
    final hostEntitlements =
        File('$projectRoot/ios/Runner/Runner.entitlements');
    final projectFile =
        File('$projectRoot/ios/Runner.xcodeproj/project.pbxproj');

    expect(extensionDirectory.existsSync(), isTrue);
    expect(providerFile.existsSync(), isTrue);
    expect(infoPlist.existsSync(), isTrue);
    expect(entitlementsFile.existsSync(), isTrue);

    final hostEntitlementsText = hostEntitlements.readAsStringSync();
    expect(
      hostEntitlementsText,
      contains('com.apple.developer.networking.networkextension'),
    );

    final projectText = projectFile.readAsStringSync();
    expect(projectText, contains('PacketTunnelExtension.appex'));
    expect(projectText, contains('PacketTunnelProvider.swift in Sources'));
    expect(projectText, contains('Embed App Extensions'));
    expect(projectText, contains('com.apple.product-type.app-extension'));
  });

  test('packet tunnel provider carries live libbox service wiring markers', () {
    final projectRoot = Directory.current.path;
    final providerFile = File(
      '$projectRoot/ios/PacketTunnelExtension/PacketTunnelProvider.swift',
    );

    final providerText = providerFile.readAsStringSync();

    expect(
      providerText,
      isNot(contains('not implemented yet')),
      reason: 'the iOS provider should no longer stop at the scaffold error',
    );
    expect(
      providerText,
      isNot(contains('packet-tunnel-scaffold')),
      reason:
          'the iOS provider should no longer identify itself as scaffold-only',
    );
    expect(
      providerText,
      contains('LibboxNewCommandServer'),
      reason: 'the provider should start the libbox command server',
    );
    expect(
      providerText,
      contains('LibboxNewService'),
      reason: 'the provider should boot a real libbox box service',
    );
    expect(
      providerText,
      contains('openTun('),
      reason:
          'the provider should expose a platform interface that opens the tunnel fd',
    );
    expect(
      providerText,
      contains('setTunnelNetworkSettings'),
      reason:
          'the provider should apply packet tunnel network settings before handing tun to libbox',
    );
  });
}
