import Cocoa
import FlutterMacOS

/// Takes over the files the system asks ComicsNow to open (double click,
/// "Apri con", drag on the Dock icon).
///
/// The file is copied into the app container first, because the access the
/// sandbox grants to a document opened through Launch Services does not outlive
/// the delegate call; the path of the copy is what crosses over to Dart.
///
/// Dart may not be listening yet — a cold start delivers the file before the
/// Flutter UI exists — so paths wait here until Dart announces itself with
/// `ready`; `takePending` flushes the queue.
final class OpenWithBridge {
  static let shared = OpenWithBridge()

  private static let channelName = "comicsnow/open_with"

  private var channel: FlutterMethodChannel?
  private var pending: [String] = []
  private var ready = false

  /// Last file handed over, to ignore the same one arriving twice (AppKit and
  /// the explicit AppleEvent handler can both report it).
  private var lastDelivery: (path: String, at: Date)?

  private init() {}

  /// Connects the channel; called when the Flutter window is created.
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

  /// Copies the file at [path] into the app container and queues it.
  func deliver(path: String) {
    let now = Date()
    if let last = lastDelivery, last.path == path, now.timeIntervalSince(last.at) < 3 {
      return
    }
    lastDelivery = (path, now)

    guard let inboxPath = Self.copyIntoInbox(URL(fileURLWithPath: path)) else { return }

    if ready, let channel {
      channel.invokeMethod("open", arguments: inboxPath)
    } else {
      pending.append(inboxPath)
    }
  }

  /// Copies a file the system offered us into `tmp/inbox`.
  ///
  /// The temporary directory on purpose: the archive reader moves the copy into
  /// its own storage, which it only does for files it considers temporary (and
  /// the empty `inbox` is cleaned up with it).
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
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Installs the handler for the `odoc` AppleEvent ("Apri con", double click).
  ///
  /// AppKit would normally forward this event to `application(_:openFiles:)`,
  /// but in this app it does not: the event reaches the process and the
  /// delegate method is never called (verified by logging both). It is
  /// therefore handled at the AppleEvent level, which works for a cold start
  /// (the app is launched by the document) and for a warm one.
  override func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
    super.applicationWillFinishLaunching(notification)
  }

  @objc private func handleOpenDocuments(
    _ event: NSAppleEventDescriptor,
    replyEvent: NSAppleEventDescriptor
  ) {
    guard let list = event.paramDescriptor(forKeyword: keyDirectObject) else { return }

    for index in 1...max(list.numberOfItems, 1) {
      guard let item = list.atIndex(index) else { continue }
      if let url = item.fileURLValue {
        OpenWithBridge.shared.deliver(path: url.path)
      } else if let path = item.stringValue {
        OpenWithBridge.shared.deliver(path: path)
      }
    }
  }

  /// Kept as a fallback: the bridge ignores a repeated delivery of one file.
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      OpenWithBridge.shared.deliver(path: filename)
    }
    sender.reply(toOpenOrPrint: .success)
  }
}
