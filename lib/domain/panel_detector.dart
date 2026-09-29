import 'dart:typed_data';

import 'panel_detection.dart';

/// Contract for anything that can find panels inside a single page image.
///
/// The rest of the app only ever talks to this interface: whether the
/// implementation is YOLO, TFLite, CoreML, ONNX, MediaPipe or a hand-written
/// heuristic is an implementation detail.
abstract interface class PanelDetector {
  /// Identifier of the model + version. Used as part of the cache key, so
  /// bumping the version invalidates stale detections.
  String get modelVersion;

  /// Whether [initialize] completed successfully.
  bool get isInitialized;

  /// Loads the model. Implementations must be idempotent and safe to call
  /// concurrently.
  Future<void> initialize();

  /// Runs detection on [imageBytes].
  ///
  /// [imageWidth] / [imageHeight] describe the *original* image, so the
  /// implementation can convert normalized coordinates back to pixels.
  Future<List<PanelDetection>> detect({
    required Uint8List imageBytes,
    required int imageWidth,
    required int imageHeight,
  });

  /// Releases the model and any native resources.
  Future<void> dispose();
}

/// Raised when a [PanelDetector] cannot load its model or run inference.
class PanelDetectionException implements Exception {
  PanelDetectionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PanelDetectionException: $message${cause == null ? '' : ' ($cause)'}';
}
