import Flutter
import UIKit

/// Delivers the files the system opens while the app is using scenes.
///
/// `didInitializeImplicitFlutterEngine` runs before the scene connects, so the
/// bridge is already in place by the time a URL arrives.
class SceneDelegate: FlutterSceneDelegate {
  /// Cold start from "Apri con": the URL is part of the connection options.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts {
      OpenWithBridge.shared.deliver(context.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  /// Warm start: the app was already running.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      OpenWithBridge.shared.deliver(context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
