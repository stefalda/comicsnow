import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The engine exists now, so the channel that receives the files the system
    // asks ComicsNow to open can be connected.
    OpenWithBridge.shared.attach(to: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
