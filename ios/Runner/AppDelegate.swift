import Flutter
import UIKit

/// Takes over the files the system asks ComicsNow to open.
///
/// The URL that arrives is security scoped and only usable while the delegate
/// call is running, so the file is copied into the app container first: what
/// crosses over to Dart is the path of that copy.
///
/// Dart may not be listening yet — a cold start from "Apri con" delivers the
/// URL before the Flutter UI exists — so paths wait here until Dart announces
/// itself with `ready`; `takePending` flushes the queue.
final class OpenWithBridge {
  static let shared = OpenWithBridge()

  private static let channelName = "comicsnow/open_with"

  private var channel: FlutterMethodChannel?
  private var pending: [String] = []
  private var ready = false

  private init() {}

  /// Connects the channel; called once the implicit engine exists.
  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ready":
        self?.ready = true
        result(nil)
      case "takePending":
        let paths = self?.pending ?? []
        self?.pending = []
        result(paths)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Copies the file behind [url] into the app container and queues it.
  func deliver(_ url: URL) {
    guard url.isFileURL, let path = Self.copyIntoInbox(url) else { return }

    // Once Dart is listening it gets the path pushed; before that the path
    // waits for `takePending`. The native side hands a path over exactly once.
    if ready, let channel {
      channel.invokeMethod("open", arguments: path)
    } else {
      pending.append(path)
    }
  }

  /// Copies a file the system offered us into `tmp/inbox`.
  ///
  /// The temporary directory on purpose: the archive reader moves the copy
  /// into its own storage, which it only does for files it considers temporary
  /// (and the empty `inbox` is cleaned up with it).
  private static func copyIntoInbox(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let manager = FileManager.default
    let inbox = manager.temporaryDirectory.appendingPathComponent("inbox", isDirectory: true)
    let name = url.lastPathComponent.isEmpty ? "comic" : url.lastPathComponent
    let target = inbox.appendingPathComponent(name)

    do {
      try manager.createDirectory(at: inbox, withIntermediateDirectories: true)
      try? manager.removeItem(at: target)
      try manager.copyItem(at: url, to: target)
      NSLog("ComicsNow: \"apri con\" \(name)")
      return target.path
    } catch {
      NSLog("ComicsNow: impossibile copiare \(name): \(error)")
      return nil
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    OpenWithBridge.shared.attach(to: engineBridge.applicationRegistrar.messenger())
  }

  /// A document the system hands to the app.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Keeps the plugins that register for URLs working; the file is ours.
    _ = super.application(app, open: url, options: options)
    OpenWithBridge.shared.deliver(url)
    return true
  }
}
