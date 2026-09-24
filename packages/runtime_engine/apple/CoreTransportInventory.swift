import Foundation
import PokrovCore

enum PokrovCoreTransportInventory {
  static let providerMessage = Data("transport_capabilities".utf8)

  // gomobile produces a static archive. This generated call keeps the actual
  // implementation linked into each host image and uses its declared ownership.
  // Building these sources requires the matching Core headers and archive.
  static func read() -> String? {
    bounded(LibboxTransportCapabilities())
  }

  static func bounded(_ value: String) -> String? {
    let bytes = value.utf8
    guard !bytes.isEmpty, bytes.count <= 4096,
          bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) else { return nil }
    // Shared Dart code owns canonical JSON and known-feature validation.
    return value
  }
}
