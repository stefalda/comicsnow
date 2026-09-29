import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Files the operating system asks ComicsNow to open.
///
/// On Android, iOS and macOS the app declares the comic formats it understands
/// (manifest intent filters and `Info.plist` document types), so the system can
/// offer ComicsNow in "Apri con", in the Files app and on double click. The
/// native side copies the incoming file into the app container — the URL it
/// receives is security scoped and stops being valid as soon as the delegate
/// call returns — and sends the path of that copy here.
///
/// Windows and Linux are not handled: a Flutter build has nowhere to declare
/// file associations there. They live in the installer (registry or MSIX
/// manifest on Windows, `.desktop` plus a shared-mime-info XML on Linux), so
/// [initialize] quietly does nothing.
class OpenWith {
  OpenWith._();

  static const MethodChannel _channel = MethodChannel('comicsnow/open_with');

  /// Deliberately a single-subscription controller: a controller with no
  /// listener buffers its events, so a file opened during a cold start is not
  /// lost while the UI is still being built. The library page is the only
  /// listener it will ever have.
  static StreamController<String> _incoming = StreamController<String>();

  static bool _initialized = false;

  /// Paths of the files to open, in the order the system delivered them.
  static Stream<String> get incoming => _incoming.stream;

  /// Forgets everything delivered so far. Only for tests.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _incoming.close();
    _incoming = StreamController<String>();
  }

  /// Starts listening to the platform side.
  ///
  /// Safe to call more than once. Subscribe to [incoming] *before* calling this,
  /// so nothing can slip through between the platform reply and the listener.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'open') return null;
      final path = call.arguments;
      if (path is String && path.isNotEmpty) _incoming.add(path);
      return null;
    });

    try {
      // The order matters: first tell the platform side that pushes can be
      // delivered, then collect what arrived while the app was starting up. The
      // native side drops an entry from its queue as soon as it pushes it, so
      // no file is delivered twice.
      await _channel.invokeMethod<void>('ready');
      final pending = await _channel.invokeMethod<List<Object?>>('takePending');
      for (final path in pending ?? const <Object?>[]) {
        if (path is String && path.isNotEmpty) _incoming.add(path);
      }
    } on MissingPluginException {
      // Windows and Linux: nothing to declare, nothing to receive.
    } on PlatformException catch (error) {
      debugPrint('ComicsNow: "apri con" non disponibile: ${error.message}');
    }
  }
}
