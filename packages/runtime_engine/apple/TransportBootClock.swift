import Darwin
import Foundation

// Local admission input only: never send boot identity to telemetry or APIs.
enum PokrovBootClock {
  static func read(platform: String) -> [String: Any]? {
    var bootBytes = [CChar](repeating: 0, count: 37)
    var size = bootBytes.count
    let status = bootBytes.withUnsafeMutableBufferPointer { buffer in
      sysctlbyname("kern.bootsessionuuid", buffer.baseAddress, &size, nil, 0)
    }
    guard status == 0, size == bootBytes.count, bootBytes[36] == 0,
          let boot = UUID(uuidString: String(cString: bootBytes)) else {
      return nil
    }

    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS,
          timebase.numer > 0, timebase.denom > 0 else {
      return nil
    }
    let product = mach_continuous_time().multipliedFullWidth(by: UInt64(timebase.numer))
    let divisor = UInt64(timebase.denom)
    guard product.high < divisor else { return nil }
    let milliseconds = divisor.dividingFullWidth(product).quotient / 1_000_000
    guard milliseconds <= 9_007_199_254_740_991 else { return nil }
    return [
      "schema": 1,
      "boot_ref": "\(platform):\(boot.uuidString.lowercased())",
      "elapsed_ms": Int64(milliseconds),
      "quantum_ms": 1,
    ]
  }
}
