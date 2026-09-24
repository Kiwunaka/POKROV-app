import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var runtimeClockChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "space.pokrov/runtime_engine",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "runtimeEngine.clockSnapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let clock = PokrovBootClock.read(platform: "macos") else {
        result(FlutterError(code: "runtime_clock_unavailable", message: "Boot clock unavailable", details: nil))
        return
      }
      result(clock)
    }
    runtimeClockChannel = channel

    super.awakeFromNib()
  }
}
