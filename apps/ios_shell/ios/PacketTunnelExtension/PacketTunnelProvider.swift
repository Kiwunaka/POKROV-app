import Foundation
import PokrovCore
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private enum ProviderState: String {
    case idle
    case starting
    case running
    case stopping
    case stopped
    case failed
  }

  private enum ProviderMessageAction: String {
    case snapshot
    case readError
    case clearError
  }

  private static let errorFileName = "network_extension_error"
  private static let stderrFileName = "stderr.log"

  private var providerState: ProviderState = .idle
  private var runtimeEnvironment: PacketTunnelSharedPaths.RuntimeEnvironment?
  private var stagedConfigPath: String?
  private var stagedConfig: String?
  private var commandServer: LibboxCommandServer?
  private var serviceRunning = false
  private var platformInterface: PacketTunnelPlatformInterface?
  private var lastMessage = "Packet tunnel provider has not started yet."
  private var lastErrorMessage: String?

  override func startTunnel(
    options: [String : NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    providerState = .starting

    do {
      let environment = try resolveRuntimeEnvironment()
      runtimeEnvironment = environment
      clearRuntimeArtifacts()

      let configPath = try resolveStagedConfigPath(options: options)
      stagedConfigPath = configPath
      stagedConfig = try loadStagedConfig(at: configPath)

      try setupRuntimes(
        environment: environment,
        disableMemoryLimit: resolveDisableMemoryLimit(options: options)
      )

      let platformInterface = getOrCreatePlatformInterface()
      try startCommandServer(using: platformInterface)
      try startService()

      providerState = .running
      writeMessage("Packet tunnel provider started the POKROV Core service.")
      completionHandler(nil)
    } catch {
      providerState = .failed
      stopService()
      closeCommandServer()
      writeError("Packet tunnel provider failed to start: \(error.localizedDescription)")
      completionHandler(error)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    providerState = .stopping
    writeMessage("Packet tunnel provider stopping, reason: \(reason.rawValue)")
    stopService()
    closeCommandServer()
    providerState = .stopped
    completionHandler()
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)? = nil
  ) {
    switch decodeMessageAction(from: messageData) {
    case .clearError:
      clearErrorArtifact()
      completionHandler?(encodeStatusPayload())
    case .readError:
      completionHandler?(encodeStatusPayload(includeErrorBody: true))
    case .snapshot:
      completionHandler?(encodeStatusPayload())
    }
  }

  func writeMessage(_ message: String) {
    lastMessage = message
    NSLog("%@", message)
  }

  func writeError(_ message: String) {
    lastErrorMessage = message
    writeMessage(message)
    guard let errorFileURL else {
      return
    }
    try? message.write(to: errorFileURL, atomically: true, encoding: .utf8)
  }

  func reloadService() throws {
    guard let stagedConfig else {
      throw seedError(
        code: 1201,
        message: "Packet tunnel provider cannot reload without a staged config."
      )
    }

    writeMessage("Packet tunnel provider reloading the Libbox service.")
    reasserting = true
    defer {
      reasserting = false
    }

    self.stagedConfig = stagedConfig
    try startService()
    providerState = .running
  }

  func markServiceStopped() {
    serviceRunning = false
    platformInterface?.reset()
    providerState = .stopped
    writeMessage("Packet tunnel provider observed the POKROV Core service shutdown.")
  }

  func stopServiceFromCommand() {
    stopService()
    markServiceStopped()
  }

  func applyNetworkSettings(_ settings: NEPacketTunnelNetworkSettings?) async throws {
    try await withCheckedThrowingContinuation { continuation in
      setTunnelNetworkSettings(settings) { error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: ())
      }
    }
  }

  private func resolveRuntimeEnvironment() throws -> PacketTunnelSharedPaths.RuntimeEnvironment {
    guard let runtimeEnvironment = PacketTunnelSharedPaths.packetTunnelRuntimeEnvironment() else {
      throw seedError(
        code: 1001,
        message: "Packet tunnel provider could not resolve its runtime directories."
      )
    }

    guard runtimeEnvironment.usesSharedAppGroup else {
      throw seedError(
        code: 1002,
        message:
          "Packet tunnel provider requires a signed shared app-group container before it can read staged configs."
      )
    }

    return runtimeEnvironment
  }

  private func resolveStagedConfigPath(options: [String : NSObject]?) throws -> String {
    if let optionsPath = normalizedPath(
      options?["stagedConfigPath"] as? String
    ) {
      return optionsPath
    }

    if
      let providerConfiguration = (protocolConfiguration as? NETunnelProviderProtocol)?
        .providerConfiguration,
      let providerPath = normalizedPath(providerConfiguration["stagedConfigPath"] as? String)
    {
      return providerPath
    }

    throw seedError(
      code: 1003,
      message: "Packet tunnel provider did not receive a staged config path from the host runtime."
    )
  }

  private func loadStagedConfig(at path: String) throws -> String {
    guard FileManager.default.fileExists(atPath: path) else {
      throw seedError(
        code: 1004,
        message: "Packet tunnel provider could not find the staged config at \(path)."
      )
    }

    do {
      return try String(contentsOfFile: path, encoding: .utf8)
    } catch let error as NSError where error.domain == "space.pokrov.ios.PacketTunnelExtension" {
      throw error
    } catch {
      throw seedError(
        code: 1007,
        message:
          "Packet tunnel provider could not read the staged config payload: \(error.localizedDescription)."
      )
    }
  }

  private func setupRuntimes(
    environment: PacketTunnelSharedPaths.RuntimeEnvironment,
    disableMemoryLimit: Bool
  ) throws {
    let options = LibboxSetupOptions()
    options.basePath = environment.baseDirectory.path
    options.workingPath = environment.workingDirectory.path
    options.tempPath = environment.tempDirectory.path
    options.fixAndroidStack = false
    options.commandServerListenPort = 0
    options.commandServerSecret = ""
    options.logMaxLines = 30
    options.debug = false

    var setupError: NSError?
    let didSetup = LibboxSetup(options, &setupError)
    guard didSetup else {
      throw seedError(
        code: 1005,
        message:
          "Packet tunnel provider failed POKROV Core setup: \(setupError?.localizedDescription ?? "unknown error")."
      )
    }

    if let stderrLogURL {
      var stderrError: NSError?
      let redirected = LibboxRedirectStderr(stderrLogURL.path, &stderrError)
      if !redirected, let stderrError {
        writeMessage(
          "Packet tunnel provider could not redirect stderr: \(stderrError.localizedDescription)"
        )
      }
    }

    LibboxSetMemoryLimit(!disableMemoryLimit)
    writeMessage("Packet tunnel provider initialized the POKROV Core runtime.")
  }

  private func getOrCreatePlatformInterface() -> PacketTunnelPlatformInterface {
    if let platformInterface {
      return platformInterface
    }

    let platformInterface = PacketTunnelPlatformInterface(tunnel: self)
    self.platformInterface = platformInterface
    return platformInterface
  }

  private func startCommandServer(using platformInterface: PacketTunnelPlatformInterface) throws {
    guard commandServer == nil else {
      return
    }

    var creationError: NSError?
    guard
      let commandServer = LibboxNewCommandServer(
        platformInterface,
        platformInterface,
        &creationError
      )
    else {
      throw seedError(
        code: 1101,
        message:
          "Packet tunnel provider could not create the POKROV Core command server: \(creationError?.localizedDescription ?? "unknown error")."
      )
    }

    do {
      try commandServer.start()
      self.commandServer = commandServer
      writeMessage("Packet tunnel provider started the Libbox command server.")
    } catch {
      throw seedError(
        code: 1102,
        message:
          "Packet tunnel provider could not start the Libbox command server: \(error.localizedDescription)."
      )
    }
  }

  private func startService() throws {
    guard let stagedConfig else {
      throw seedError(
        code: 1103,
        message: "Packet tunnel provider cannot start without a staged config payload."
      )
    }

    guard let commandServer else {
      throw seedError(
        code: 1104,
        message: "Packet tunnel provider cannot start without the POKROV Core command server."
      )
    }

    do {
      try commandServer.checkConfig(stagedConfig)
      try commandServer.startOrReloadService(stagedConfig, options: LibboxOverrideOptions())
      serviceRunning = true
    } catch {
      throw seedError(
        code: 1105,
        message:
          "Packet tunnel provider could not start the POKROV Core service: \(error.localizedDescription)."
      )
    }
  }

  private func stopService() {
    if serviceRunning, let commandServer {
      do {
        try commandServer.closeService()
      } catch {
        writeMessage(
          "Packet tunnel provider could not stop the POKROV Core service cleanly: \(error.localizedDescription)"
        )
      }
    }
    serviceRunning = false
    platformInterface?.reset()
  }

  private func closeCommandServer() {
    if let commandServer {
      commandServer.close()
      self.commandServer = nil
    }
  }

  private func resolveDisableMemoryLimit(options: [String : NSObject]?) -> Bool {
    let optionsValue = normalizedPath(options?["DisableMemoryLimit"] as? String)
    if optionsValue == "YES" {
      return true
    }

    if
      let providerConfiguration = (protocolConfiguration as? NETunnelProviderProtocol)?
        .providerConfiguration,
      let providerValue = normalizedPath(providerConfiguration["DisableMemoryLimit"] as? String),
      providerValue == "YES"
    {
      return true
    }

    return false
  }

  private func clearRuntimeArtifacts() {
    clearErrorArtifact()
    if let stderrLogURL {
      try? FileManager.default.removeItem(at: stderrLogURL)
    }
  }

  private func clearErrorArtifact() {
    lastErrorMessage = nil
    if let errorFileURL {
      try? FileManager.default.removeItem(at: errorFileURL)
    }
  }

  private func decodeMessageAction(from data: Data) -> ProviderMessageAction {
    if data.isEmpty {
      return .snapshot
    }

    if
      let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let actionValue = jsonObject["action"] as? String,
      let action = ProviderMessageAction(rawValue: actionValue)
    {
      return action
    }

    if
      let text = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      let action = ProviderMessageAction(rawValue: text)
    {
      return action
    }

    return .snapshot
  }

  private func encodeStatusPayload(includeErrorBody: Bool = false) -> Data? {
    var payload: [String: Any?] = [
      "status": providerState.rawValue,
      "message": lastMessage,
      "lastErrorMessage": lastErrorMessage,
      "serviceRunning": serviceRunning,
      "commandServerRunning": commandServer != nil,
      "stagedConfigPath": stagedConfigPath,
      "usesSharedAppGroup": runtimeEnvironment?.usesSharedAppGroup ?? false,
      "appGroupIdentifier": runtimeEnvironment?.appGroupIdentifier,
      "sharedContainerDirectory": runtimeEnvironment?.sharedContainerDirectory,
      "errorFilePath": errorFileURL?.path,
      "stderrLogPath": stderrLogURL?.path,
    ]

    if includeErrorBody, let errorFileURL {
      payload["errorFileBody"] = try? String(contentsOf: errorFileURL, encoding: .utf8)
    }

    let compactPayload = payload.compactMapValues { $0 }
    return try? JSONSerialization.data(withJSONObject: compactPayload, options: [])
  }

  private func normalizedPath(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  private var errorFileURL: URL? {
    runtimeEnvironment?.workingDirectory.appendingPathComponent(
      Self.errorFileName,
      isDirectory: false
    )
  }

  private var stderrLogURL: URL? {
    runtimeEnvironment?.tempDirectory.appendingPathComponent(
      Self.stderrFileName,
      isDirectory: false
    )
  }

  private func seedError(code: Int, message: String) -> NSError {
    NSError(
      domain: "space.pokrov.ios.PacketTunnelExtension",
      code: code,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}

final class PacketTunnelPlatformInterface: NSObject,
  LibboxPlatformInterfaceProtocol,
  LibboxCommandServerHandlerProtocol
{
  private let tunnel: PacketTunnelProvider
  private var networkSettings: NEPacketTunnelNetworkSettings?

  init(tunnel: PacketTunnelProvider) {
    self.tunnel = tunnel
  }

  func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
    try runBlocking { [self] in
      try await openTun0(options, ret0_)
    }
  }

  private func openTun0(
    _ options: LibboxTunOptionsProtocol?,
    _ ret0_: UnsafeMutablePointer<Int32>?
  ) async throws {
    guard let options else {
      throw NSError(domain: "PacketTunnelProvider", code: 2001)
    }
    guard let ret0_ else {
      throw NSError(domain: "PacketTunnelProvider", code: 2002)
    }

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

    if options.getAutoRoute() {
      settings.mtu = NSNumber(value: options.getMTU())

      let dnsServer = try options.getDNSServerAddress().value
      settings.dnsSettings = NEDNSSettings(servers: [dnsServer])

      let ipv4Prefixes = routePrefixes(from: options.getInet4Address())
      if !ipv4Prefixes.isEmpty {
        let ipv4Settings = NEIPv4Settings(
          addresses: ipv4Prefixes.map(\.address),
          subnetMasks: ipv4Prefixes.map(\.mask)
        )

        var includedRoutes = ipv4Routes(from: options.getInet4RouteAddress())
        if includedRoutes.isEmpty {
          includedRoutes = [NEIPv4Route.default()]
        }

        for prefix in ipv4Prefixes {
          includedRoutes.append(
            NEIPv4Route(destinationAddress: prefix.address, subnetMask: prefix.mask)
          )
        }

        let excludedRoutes = ipv4Routes(from: options.getInet4RouteExcludeAddress())
        ipv4Settings.includedRoutes = includedRoutes
        if !excludedRoutes.isEmpty {
          ipv4Settings.excludedRoutes = excludedRoutes
        }
        settings.ipv4Settings = ipv4Settings
      }

      let ipv6Prefixes = routePrefixes(from: options.getInet6Address())
      if !ipv6Prefixes.isEmpty {
        let ipv6Settings = NEIPv6Settings(
          addresses: ipv6Prefixes.map(\.address),
          networkPrefixLengths: ipv6Prefixes.map { NSNumber(value: $0.prefix) }
        )

        var includedRoutes = ipv6Routes(from: options.getInet6RouteAddress())
        if includedRoutes.isEmpty {
          includedRoutes = [NEIPv6Route.default()]
        }

        let excludedRoutes = ipv6Routes(from: options.getInet6RouteExcludeAddress())
        ipv6Settings.includedRoutes = includedRoutes
        if !excludedRoutes.isEmpty {
          ipv6Settings.excludedRoutes = excludedRoutes
        }
        settings.ipv6Settings = ipv6Settings
      }
    }

    if options.isHTTPProxyEnabled() {
      let proxySettings = NEProxySettings()
      let proxyServer = NEProxyServer(
        address: options.getHTTPProxyServer(),
        port: Int(options.getHTTPProxyServerPort())
      )
      proxySettings.httpServer = proxyServer
      proxySettings.httpsServer = proxyServer
      proxySettings.httpEnabled = true
      proxySettings.httpsEnabled = true

      let bypassDomains = stringValues(from: options.getHTTPProxyBypassDomain())
      if !bypassDomains.isEmpty {
        proxySettings.exceptionList = bypassDomains
      }

      let matchDomains = stringValues(from: options.getHTTPProxyMatchDomain())
      if !matchDomains.isEmpty {
        proxySettings.matchDomains = matchDomains
      }

      settings.proxySettings = proxySettings
    }

    try await tunnel.applyNetworkSettings(settings)
    networkSettings = settings

    if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
      ret0_.pointee = tunFd
      return
    }

    let loopbackTunFd = LibboxGetTunnelFileDescriptor()
    guard loopbackTunFd != -1 else {
      throw NSError(domain: "PacketTunnelProvider", code: 2003)
    }

    ret0_.pointee = loopbackTunFd
  }

  func readWIFIState() -> LibboxWIFIState? {
    nil
  }

  func usePlatformAutoDetectInterfaceControl() -> Bool {
    false
  }

  func autoDetectInterfaceControl(_: Int32) throws {}

  func findConnectionOwner(
    _: Int32,
    sourceAddress _: String?,
    sourcePort _: Int32,
    destinationAddress _: String?,
    destinationPort _: Int32
  ) throws -> LibboxConnectionOwner {
    throw NSError(domain: "PacketTunnelProvider", code: 2004)
  }

  func useProcFS() -> Bool {
    false
  }

  func startDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {}

  func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {}

  func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
    throw NSError(domain: "PacketTunnelProvider", code: 2006)
  }

  func underNetworkExtension() -> Bool {
    true
  }

  func includeAllNetworks() -> Bool {
    false
  }

  func clearDNSCache() {
    guard let networkSettings else {
      return
    }

    tunnel.reasserting = true
    defer {
      tunnel.reasserting = false
    }

    do {
      try runBlocking {
        try await self.tunnel.applyNetworkSettings(nil)
        try await self.tunnel.applyNetworkSettings(networkSettings)
      }
    } catch {
      tunnel.writeMessage(
        "Packet tunnel provider could not refresh DNS settings: \(error.localizedDescription)"
      )
    }
  }

  func serviceReload() throws {
    try tunnel.reloadService()
  }

  func serviceStop() throws {
    tunnel.stopServiceFromCommand()
  }

  func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
    let status = LibboxSystemProxyStatus()
    guard let proxySettings = networkSettings?.proxySettings else {
      return status
    }
    guard proxySettings.httpServer != nil else {
      return status
    }

    status.available = true
    status.enabled = proxySettings.httpEnabled
    return status
  }

  func setSystemProxyEnabled(_ isEnabled: Bool) throws {
    guard let networkSettings else {
      return
    }
    guard let proxySettings = networkSettings.proxySettings else {
      return
    }
    guard proxySettings.httpServer != nil else {
      return
    }
    guard proxySettings.httpEnabled != isEnabled else {
      return
    }

    proxySettings.httpEnabled = isEnabled
    proxySettings.httpsEnabled = isEnabled
    networkSettings.proxySettings = proxySettings
    self.networkSettings = networkSettings

    try runBlocking {
      try await self.tunnel.applyNetworkSettings(networkSettings)
    }
  }

  func writeDebugMessage(_ message: String?) {
    guard let message else {
      return
    }
    tunnel.writeMessage(message)
  }

  func send(_ notification: LibboxNotification?) throws {
    guard let notification else {
      return
    }
    let detail = notification.body.isEmpty ? notification.subtitle : notification.body
    tunnel.writeMessage("Pokrov notification: \(notification.title) \(detail)")
  }

  func localDNSTransport() -> LibboxLocalDNSTransportProtocol? {
    nil
  }

  func systemCertificates() -> LibboxStringIteratorProtocol? {
    nil
  }

  func reset() {
    networkSettings = nil
  }

  private func routePrefixes(
    from iterator: LibboxRoutePrefixIteratorProtocol?
  ) -> [RoutePrefix] {
    var prefixes: [RoutePrefix] = []
    guard let iterator else {
      return prefixes
    }

    while iterator.hasNext() {
      guard let prefix = iterator.next() else {
        continue
      }
      prefixes.append(
        RoutePrefix(
          address: prefix.address(),
          mask: prefix.mask(),
          prefix: prefix.prefix()
        )
      )
    }

    return prefixes
  }

  private func ipv4Routes(
    from iterator: LibboxRoutePrefixIteratorProtocol?
  ) -> [NEIPv4Route] {
    routePrefixes(from: iterator).map { prefix in
      NEIPv4Route(destinationAddress: prefix.address, subnetMask: prefix.mask)
    }
  }

  private func ipv6Routes(
    from iterator: LibboxRoutePrefixIteratorProtocol?
  ) -> [NEIPv6Route] {
    routePrefixes(from: iterator).map { prefix in
      NEIPv6Route(
        destinationAddress: prefix.address,
        networkPrefixLength: NSNumber(value: prefix.prefix)
      )
    }
  }

  private func stringValues(from iterator: LibboxStringIteratorProtocol?) -> [String] {
    var values: [String] = []
    guard let iterator else {
      return values
    }

    while iterator.hasNext() {
      values.append(iterator.next())
    }

    return values
  }

  private struct RoutePrefix {
    let address: String
    let mask: String
    let prefix: Int32
  }
}

private func runBlocking<T>(_ block: @escaping () async -> T) -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let box = ResultBox<T>()

  Task.detached {
    let value = await block()
    box.value = value
    semaphore.signal()
  }

  semaphore.wait()
  return box.value
}

private func runBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let box = ResultBox<T>()

  Task.detached {
    do {
      box.result = .success(try await block())
    } catch {
      box.result = .failure(error)
    }
    semaphore.signal()
  }

  semaphore.wait()
  return try box.result.get()
}

private final class ResultBox<T> {
  var result: Result<T, Error>!
  var value: T!
}
