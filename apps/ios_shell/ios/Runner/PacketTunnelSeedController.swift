import Foundation
import NetworkExtension

final class PacketTunnelSeedController {
  // Read-only lookup: this path never creates/saves a manager or starts a VPN.
  func readTransportCapabilities(bundleIdentifier: String, completion: @escaping (String?) -> Void) {
    var finished = false
    func finish(_ value: String?) {
      DispatchQueue.main.async {
        guard !finished else { return }
        finished = true
        completion(value)
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { finish(nil) }
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      DispatchQueue.main.async {
        guard !finished else { return }
        let matching = (managers ?? []).filter {
          ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleIdentifier
        }
        guard error == nil, matching.count == 1,
              let session = matching[0].connection as? NETunnelProviderSession,
              session.status == .connected else {
          finish(nil)
          return
        }
        do {
          try session.sendProviderMessage(PokrovCoreTransportInventory.providerMessage) { data in
            DispatchQueue.main.async {
              guard !finished, session.status == .connected,
                    let data, data.count <= 4096,
                    let value = String(data: data, encoding: .utf8) else {
                finish(nil)
                return
              }
              finish(PokrovCoreTransportInventory.bounded(value))
            }
          }
        } catch {
          finish(nil)
        }
      }
    }
  }

  func connect(
    stagedConfigPath: String,
    displayName: String,
    bundleIdentifier: String,
    appGroupIdentifier: String?,
    completion: @escaping (PacketTunnelSeedResult) -> Void
  ) {
    loadManager(displayName: displayName, bundleIdentifier: bundleIdentifier) { result in
      switch result {
      case .failure(let error):
        completion(
          PacketTunnelSeedResult(
            status: .invalid,
            message: "iOS packet-tunnel seed setup failed: \(error.localizedDescription)"
          )
        )
      case .success(let manager):
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleIdentifier
        protocolConfiguration.serverAddress = "POKROV"
        protocolConfiguration.providerConfiguration = [
          "stagedConfigPath": stagedConfigPath,
          "seedMode": "runtimeEngine",
          "appGroupIdentifier": appGroupIdentifier ?? "",
        ]
        protocolConfiguration.disconnectOnSleep = false

        manager.localizedDescription = displayName
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true

        manager.saveToPreferences { saveError in
          if let saveError {
              completion(
                PacketTunnelSeedResult(
                  status: .invalid,
                  message: "iOS packet-tunnel seed save failed: \(saveError.localizedDescription)"
                )
              )
            return
          }

          manager.loadFromPreferences { loadError in
            if let loadError {
              completion(
                PacketTunnelSeedResult(
                  status: .invalid,
                  message: "iOS packet-tunnel seed reload failed: \(loadError.localizedDescription)"
                )
              )
              return
            }

            do {
              try manager.connection.startVPNTunnel(
                options: [
                  "stagedConfigPath": stagedConfigPath as NSString,
                  "seedMode": "runtimeEngine" as NSString,
                ]
              )
              completion(
                PacketTunnelSeedResult(
                  status: manager.connection.status,
                  message: "iOS packet-tunnel start was requested through NETunnelProviderManager."
                )
              )
            } catch {
              completion(
                PacketTunnelSeedResult(
                  status: .disconnected,
                  message: "iOS packet-tunnel start failed: \(error.localizedDescription)"
                )
              )
            }
          }
        }
      }
    }
  }

  func disconnect(
    displayName: String,
    bundleIdentifier: String,
    completion: @escaping (PacketTunnelSeedResult) -> Void
  ) {
    loadManager(displayName: displayName, bundleIdentifier: bundleIdentifier) { result in
      switch result {
      case .failure(let error):
        completion(
          PacketTunnelSeedResult(
            status: .invalid,
            message: "iOS packet-tunnel stop lookup failed: \(error.localizedDescription)"
          )
        )
      case .success(let manager):
        manager.connection.stopVPNTunnel()
        completion(
          PacketTunnelSeedResult(
            status: .disconnecting,
            message: "iOS packet-tunnel stop was requested through NETunnelProviderManager."
          )
        )
      }
    }
  }

  private func loadManager(
    displayName: String,
    bundleIdentifier: String,
    completion: @escaping (Result<NETunnelProviderManager, Error>) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        completion(.failure(error))
        return
      }

      if let existingManager = managers?.first(where: { manager in
        let provider = manager.protocolConfiguration as? NETunnelProviderProtocol
        return provider?.providerBundleIdentifier == bundleIdentifier
      }) {
        completion(.success(existingManager))
        return
      }

      let manager = NETunnelProviderManager()
      manager.localizedDescription = displayName
      completion(.success(manager))
    }
  }
}

struct PacketTunnelSeedResult {
  let status: NEVPNStatus
  let message: String
}
