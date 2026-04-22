import Foundation

enum PacketTunnelSharedPaths {
  static let appGroupInfoKey = "POKROVAppGroupIdentifier"
  static let packetTunnelBundleInfoKey = "POKROVPacketTunnelBundleIdentifier"
  private static let runtimeRootDirectoryName = "pokrov-runtime"
  private static let sharedConfigDirectoryName = "staged-configs"

  struct RuntimeEnvironment {
    let appGroupIdentifier: String?
    let sharedContainerDirectory: String?
    let usesSharedAppGroup: Bool
    let baseDirectory: URL
    let workingDirectory: URL
    let tempDirectory: URL
    let configDirectory: URL
  }

  static func hostRuntimeEnvironment(bundle: Bundle = .main) -> RuntimeEnvironment? {
    runtimeEnvironment(component: "host", bundle: bundle)
  }

  static func packetTunnelRuntimeEnvironment(bundle: Bundle = .main) -> RuntimeEnvironment? {
    runtimeEnvironment(component: "packet-tunnel", bundle: bundle)
  }

  static func packetTunnelBundleIdentifier(bundle: Bundle = .main) -> String? {
    if let configuredBundleIdentifier = bundle.object(
      forInfoDictionaryKey: packetTunnelBundleInfoKey
    ) as? String {
      let normalized = configuredBundleIdentifier.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      if !normalized.isEmpty {
        return normalized
      }
    }

    guard let bundleIdentifier = bundle.bundleIdentifier, !bundleIdentifier.isEmpty else {
      return nil
    }
    return "\(bundleIdentifier).PacketTunnel"
  }

  private static func runtimeEnvironment(
    component: String,
    bundle: Bundle
  ) -> RuntimeEnvironment? {
    let appGroupIdentifier = appGroupIdentifier(bundle: bundle)
    let sharedContainer = appGroupContainer(
      bundle: bundle,
      appGroupIdentifier: appGroupIdentifier
    )
    let usesSharedAppGroup = sharedContainer != nil

    let rootDirectory =
      sharedContainer ??
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    guard let rootDirectory else {
      return nil
    }

    let runtimeRoot = rootDirectory.appendingPathComponent(
      runtimeRootDirectoryName,
      isDirectory: true
    )
    let baseDirectory = runtimeRoot.appendingPathComponent(component, isDirectory: true)
    let workingDirectory = baseDirectory.appendingPathComponent("working", isDirectory: true)
    let tempDirectory = baseDirectory.appendingPathComponent("temp", isDirectory: true)
    let configDirectory = runtimeRoot.appendingPathComponent(
      sharedConfigDirectoryName,
      isDirectory: true
    )

    [runtimeRoot, baseDirectory, workingDirectory, tempDirectory, configDirectory].forEach {
      try? FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
    }

    return RuntimeEnvironment(
      appGroupIdentifier: appGroupIdentifier,
      sharedContainerDirectory: sharedContainer?.path,
      usesSharedAppGroup: usesSharedAppGroup,
      baseDirectory: baseDirectory,
      workingDirectory: workingDirectory,
      tempDirectory: tempDirectory,
      configDirectory: configDirectory
    )
  }

  private static func appGroupContainer(
    bundle: Bundle,
    appGroupIdentifier: String?
  ) -> URL? {
    guard let appGroupIdentifier, !appGroupIdentifier.isEmpty else {
      return nil
    }
    return FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )
  }

  private static func appGroupIdentifier(bundle: Bundle) -> String? {
    guard
      let configuredGroup = bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String
    else {
      return nil
    }
    let normalized = configuredGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }
}
