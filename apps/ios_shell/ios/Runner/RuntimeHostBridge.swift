import Foundation
import Flutter
import Libcore
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
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func snapshot() -> [String: Any?] {
    guard let environment = runtimeEnvironment() else {
      phase = .artifactMissing
      stagedConfigPath = nil
      lastMessage = "Libcore.framework is not embedded in this iOS host build."
      return buildSnapshot(
        artifactDirectory: nil,
        coreBinaryPath: nil,
        canInitialize: false,
        canConnect: false
      )
    }

    if phase == .artifactMissing {
      phase = .artifactReady
      lastMessage = "iOS host bridge found the bundled libcore framework and can initialize it."
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

    var error: NSError?
    let ok = MobileSetup(
      environment.baseDirectory.path,
      environment.workingDirectory.path,
      environment.tempDirectory.path,
      false,
      &error
    )
    if ok {
      phase = phase == .running ? .running : .initialized
      lastMessage = "Runtime bootstrap completed on the iOS host bridge."
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
      let profileName = payload["profileName"] as? String,
      let configPayload = payload["configPayload"] as? String
    else {
      return unavailableSnapshot(message: "Missing managed-profile payload for iOS host staging.")
    }

    _ = initialize()

    let tempPath = environment.tempDirectory.appendingPathComponent("\(profileName).seed.json")
    let finalPath = environment.configDirectory.appendingPathComponent("\(profileName).json")

    do {
      try configPayload.write(to: tempPath, atomically: true, encoding: .utf8)
      var error: NSError?
      let ok = MobileParse(finalPath.path, tempPath.path, false, &error)
      if ok {
        phase = .configStaged
        stagedConfigPath = finalPath.path
        lastMessage = "Managed profile staged on the iOS host bridge."
      } else {
        phase = .initialized
        lastMessage = "iOS managed profile staging failed: \(error?.localizedDescription ?? "unknown error")"
      }
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
      .appendingPathComponent("Libcore.framework", isDirectory: true)
    let binaryPath = frameworkPath.appendingPathComponent("Libcore")
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
