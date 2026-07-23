import Foundation
import Flutter
import PokrovCore
import NetworkExtension

final class RuntimeHostBridge: NSObject, FlutterPlugin {
  private enum RuntimePhase: String {
    case artifactMissing
    case artifactReady
    case initialized
    case configStaged
    case running
  }

  private let packetTunnelController = PacketTunnelSeedController()
  private var phase: RuntimePhase = .artifactMissing
  private var stagedConfigPath: String?
  private var didSetupRuntime = false
  private var lastMessage = "Native runtime bridge has not inspected this host yet."

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "space.pokrov/runtime_engine",
      binaryMessenger: messenger
    )
    let instance = RuntimeHostBridge()
    channel.setMethodCallHandler(instance.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "runtimeEngine.snapshot":
      result(snapshot())
    case "runtimeEngine.initialize":
      result(initialize())
    case "runtimeEngine.stageManagedProfile":
      result(stageManagedProfile(call.arguments))
    case "runtimeEngine.connect":
      connect(result: result)
    case "runtimeEngine.disconnect":
      disconnect(result: result)
    case "runtimeEngine.applyWarp":
      result(applyWarp(call.arguments))
    case "runtimeEngine.liveStats":
      result(["available": false])
    case "runtimeEngine.pushToken":
      result(["token": "", "provider": "poll"])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func snapshot() -> [String: Any?] {
    guard let environment = runtimeEnvironment() else {
      phase = .artifactMissing
      stagedConfigPath = nil
      lastMessage = "PokrovCore.framework is not embedded in this iOS host build."
      return buildSnapshot(
        artifactDirectory: nil,
        coreBinaryPath: nil,
        canInitialize: false,
        canConnect: false
      )
    }

    if phase == .artifactMissing {
      phase = .artifactReady
      lastMessage = "iOS host bridge found the bundled POKROV Core framework and can initialize it."
    }

    return buildSnapshot(
      artifactDirectory: environment.artifactDirectory,
      coreBinaryPath: environment.coreBinaryPath,
      canInitialize: true,
      canConnect: stagedConfigPath != nil
    )
  }

  private func initialize() -> [String: Any?] {
    guard let environment = runtimeEnvironment() else {
      return snapshot()
    }

    if didSetupRuntime {
      phase = phase == .running ? .running : .initialized
      return buildSnapshot(
        artifactDirectory: environment.artifactDirectory,
        coreBinaryPath: environment.coreBinaryPath,
        canInitialize: true,
        canConnect: stagedConfigPath != nil
      )
    }

    let options = LibboxSetupOptions()
    options.basePath = environment.baseDirectory.path
    options.workingPath = environment.workingDirectory.path
    options.tempPath = environment.tempDirectory.path
    options.fixAndroidStack = false
    options.commandServerListenPort = 0
    options.commandServerSecret = ""
    options.logMaxLines = 30
    options.debug = false

    var error: NSError?
    let ok = LibboxSetup(options, &error)
    if ok {
      didSetupRuntime = true
      phase = phase == .running ? .running : .initialized
      lastMessage = "POKROV Core bootstrap completed on the iOS host bridge."
    } else {
      phase = .artifactReady
      lastMessage = "iOS runtime setup failed: \(error?.localizedDescription ?? "unknown error")"
    }

    return buildSnapshot(
      artifactDirectory: environment.artifactDirectory,
      coreBinaryPath: environment.coreBinaryPath,
      canInitialize: true,
      canConnect: stagedConfigPath != nil
    )
  }

  private func stageManagedProfile(_ arguments: Any?) -> [String: Any?] {
    guard
      let environment = runtimeEnvironment(),
      let payload = arguments as? [String: Any],
      let configPayload = payload["configPayload"] as? String,
      payload["materializedForRuntime"] as? Bool == true
    else {
      return unavailableSnapshot(message: "Missing managed-profile payload for iOS host staging.")
    }

    _ = initialize()

    let finalPath = environment.configDirectory.appendingPathComponent("managed-profile.json")

    do {
      try writePrivateConfig(configPayload, to: finalPath)
      phase = .configStaged
      stagedConfigPath = finalPath.path
      lastMessage = "Materialized POKROV Core profile staged on the iOS host bridge."
    } catch {
      phase = .initialized
      lastMessage = "iOS managed profile staging failed: \(error.localizedDescription)"
    }

    return buildSnapshot(
      artifactDirectory: environment.artifactDirectory,
      coreBinaryPath: environment.coreBinaryPath,
      canInitialize: true,
      canConnect: stagedConfigPath != nil
    )
  }

  private func applyWarp(_ arguments: Any?) -> [String: Any?] {
    guard let stagedConfigPath else {
      return warpResult(applied: false, reason: "no_staged_profile")
    }
    guard
      let payload = arguments as? [String: Any],
      let configPayload = payload["configPayload"] as? String,
      !configPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return warpResult(applied: false, reason: "config_payload_missing")
    }

    do {
      try writePrivateConfig(configPayload, to: URL(fileURLWithPath: stagedConfigPath))
      return warpResult(applied: true, effectiveAt: "next_connect")
    } catch {
      return warpResult(applied: false, reason: error.localizedDescription)
    }
  }

  private func warpResult(
    applied: Bool,
    effectiveAt: String = "none",
    reason: String? = nil
  ) -> [String: Any?] {
    [
      "applied": applied,
      "effectiveAt": effectiveAt,
      "fallbackUsed": false,
      "reason": reason,
    ]
  }

  private func writePrivateConfig(_ content: String, to target: URL) throws {
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    guard let data = content.data(using: .utf8) else {
      throw NSError(
        domain: "space.pokrov.ios.RuntimeHostBridge",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Managed profile is not valid UTF-8."]
      )
    }
    try data.write(
      to: target,
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    )
    try FileManager.default.setAttributes(
      [
        .posixPermissions: 0o600,
        .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
      ],
      ofItemAtPath: target.path
    )
  }

  private func connect(result: @escaping FlutterResult) {
    guard let environment = runtimeEnvironment() else {
      result(snapshot())
      return
    }
    _ = initialize()

    guard let stagedConfigPath else {
      lastMessage = "Stage a managed profile before requesting iOS tunnel start."
      result(
        buildSnapshot(
          artifactDirectory: environment.artifactDirectory,
          coreBinaryPath: environment.coreBinaryPath,
          canInitialize: true,
          canConnect: false
        )
      )
      return
    }

    guard let providerBundleIdentifier = packetTunnelBundleIdentifier() else {
      result(
        unavailableSnapshot(
          message: "iOS packet-tunnel seed needs a host bundle identifier before start can be requested."
        )
      )
      return
    }

    packetTunnelController.connect(
      stagedConfigPath: stagedConfigPath,
      displayName: packetTunnelDisplayName(),
      bundleIdentifier: providerBundleIdentifier,
      appGroupIdentifier: environment.appGroupIdentifier
    ) { [weak self] seedResult in
      guard let self else {
        result(nil)
        return
      }

      self.phase = self.phase(for: seedResult.status)
      self.lastMessage = seedResult.message
      result(
        self.buildSnapshot(
          artifactDirectory: environment.artifactDirectory,
          coreBinaryPath: environment.coreBinaryPath,
          canInitialize: true,
          canConnect: self.stagedConfigPath != nil
        )
      )
    }
  }

  private func disconnect(result: @escaping FlutterResult) {
    guard let environment = runtimeEnvironment() else {
      result(snapshot())
      return
    }

    guard let providerBundleIdentifier = packetTunnelBundleIdentifier() else {
      result(
        unavailableSnapshot(
          message: "iOS packet-tunnel seed needs a host bundle identifier before stop can be requested."
        )
      )
      return
    }

    packetTunnelController.disconnect(
      displayName: packetTunnelDisplayName(),
      bundleIdentifier: providerBundleIdentifier
    ) { [weak self] seedResult in
      guard let self else {
        result(nil)
        return
      }

      self.phase = self.phase(for: seedResult.status)
      self.lastMessage = seedResult.message
      result(
        self.buildSnapshot(
          artifactDirectory: environment.artifactDirectory,
          coreBinaryPath: environment.coreBinaryPath,
          canInitialize: true,
          canConnect: self.stagedConfigPath != nil
        )
      )
    }
  }

  private func unavailableSnapshot(message: String) -> [String: Any?] {
    lastMessage = message
    let environment = runtimeEnvironment()
    return buildSnapshot(
      artifactDirectory: environment?.artifactDirectory,
      coreBinaryPath: environment?.coreBinaryPath,
      canInitialize: environment != nil,
      canConnect: environment != nil && stagedConfigPath != nil
    )
  }

  private func buildSnapshot(
    artifactDirectory: String?,
    coreBinaryPath: String?,
    canInitialize: Bool,
    canConnect: Bool
  ) -> [String: Any?] {
    let environment = runtimeEnvironment()
    [
      "phase": phase.rawValue,
      "artifactDirectory": artifactDirectory,
      "coreBinaryPath": coreBinaryPath,
      "helperBinaryPath": nil,
      "stagedConfigPath": stagedConfigPath,
      "appGroupIdentifier": environment?.appGroupIdentifier,
      "sharedContainerDirectory": environment?.sharedContainerDirectory,
      "usesSharedAppGroup": environment?.usesSharedAppGroup ?? false,
      "supportsLiveConnect": true,
      "canInitialize": canInitialize,
      "canConnect": canConnect,
      "message": lastMessage,
    ]
  }

  private func runtimeEnvironment() -> RuntimeEnvironment? {
    guard
      let frameworksPath = Bundle.main.privateFrameworksPath,
      let sharedRuntime = PacketTunnelSharedPaths.hostRuntimeEnvironment(bundle: .main)
    else {
      return nil
    }

    let frameworkPath = URL(fileURLWithPath: frameworksPath)
      .appendingPathComponent("PokrovCore.framework", isDirectory: true)
    let binaryPath = frameworkPath.appendingPathComponent("PokrovCore")
    guard FileManager.default.fileExists(atPath: binaryPath.path) else {
      return nil
    }

    return RuntimeEnvironment(
      artifactDirectory: frameworkPath.path,
      coreBinaryPath: binaryPath.path,
      appGroupIdentifier: sharedRuntime.appGroupIdentifier,
      sharedContainerDirectory: sharedRuntime.sharedContainerDirectory,
      usesSharedAppGroup: sharedRuntime.usesSharedAppGroup,
      baseDirectory: sharedRuntime.baseDirectory,
      workingDirectory: sharedRuntime.workingDirectory,
      tempDirectory: sharedRuntime.tempDirectory,
      configDirectory: sharedRuntime.configDirectory
    )
  }

  private func phase(for status: NEVPNStatus) -> RuntimePhase {
    switch status {
    case .connected, .connecting, .reasserting:
      return .running
    case .disconnecting, .disconnected, .invalid:
      return stagedConfigPath == nil ? .initialized : .configStaged
    @unknown default:
      return stagedConfigPath == nil ? .initialized : .configStaged
    }
  }

  private func packetTunnelBundleIdentifier() -> String? {
    PacketTunnelSharedPaths.packetTunnelBundleIdentifier(bundle: .main)
  }

  private func packetTunnelDisplayName() -> String {
    let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    let baseName = displayName ?? bundleName ?? "POKROV"
    return "\(baseName) Tunnel"
  }

  private struct RuntimeEnvironment {
    let artifactDirectory: String
    let coreBinaryPath: String
    let appGroupIdentifier: String?
    let sharedContainerDirectory: String?
    let usesSharedAppGroup: Bool
    let baseDirectory: URL
    let workingDirectory: URL
    let tempDirectory: URL
    let configDirectory: URL
  }
}
