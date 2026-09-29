import 'dart:ui';

/// A single comic panel (a.k.a. frame) on a page.
///
/// A panel is intentionally *not* a cropped image: it is only the rectangle
/// that describes where the panel lives inside the original page, expressed in
/// the page's own pixel coordinate system. This keeps the original resolution
/// available and makes manual editing cheap.
class ComicPanel {
  const ComicPanel({
    required this.bounds,
    required this.confidence,
    required this.order,
    this.id,
    this.isManual = false,
  });

  /// A panel that covers an entire page.
  ///
  /// Used as a safe fallback when detection is unavailable or returns nothing,
  /// so the reader can always show *something* meaningful.
  factory ComicPanel.fullPage(Size pageSize) {
    return ComicPanel(
      bounds: Offset.zero & pageSize,
      confidence: 1,
      order: 0,
    );
  }

  /// Stable identifier once the panel has been persisted. Detections coming
  /// straight from a model have no id yet.
  final String? id;

  /// Bounding box in the original page's pixel coordinates.
  final Rect bounds;

  /// Confidence returned by the model. Manually created panels use `1`.
  final double confidence;

  /// Reading order inside the page.
  final int order;

  /// `true` when the user created or edited this panel by hand.
  final bool isManual;

  ComicPanel copyWith({
    String? id,
    Rect? bounds,
    double? confidence,
    int? order,
    bool? isManual,
  }) {
    return ComicPanel(
      id: id ?? this.id,
      bounds: bounds ?? this.bounds,
      confidence: confidence ?? this.confidence,
      order: order ?? this.order,
      isManual: isManual ?? this.isManual,
    );
  }

  @override
  String toString() =>
      'ComicPanel(bounds=$bounds, confidence=$confidence, order=$order)';
}
