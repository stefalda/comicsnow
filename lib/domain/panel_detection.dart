import 'dart:ui';

/// A raw detection produced by a model.
///
/// This is deliberately separate from [ComicPanel]: a detection is *model
/// output*, while a `ComicPanel` is *application state* (it has a reading
/// order, can be deleted, edited or created by hand). Keeping the two apart
/// means a new model version can re-detect a page without destroying manual
/// corrections.
class PanelDetection {
  const PanelDetection({
    required this.bounds,
    required this.confidence,
    required this.modelVersion,
    this.className,
  });

  /// Bounding box in the original image's pixel coordinates.
  final Rect bounds;

  /// Confidence score in the `0.0..1.0` range.
  final double confidence;

  /// Identifier of the model (and version) that produced this detection.
  final String modelVersion;

  /// Class label returned by the model, when available.
  final String? className;

  @override
  String toString() =>
      'PanelDetection(bounds=$bounds, confidence=$confidence, '
      'modelVersion=$modelVersion, className=$className)';
}
