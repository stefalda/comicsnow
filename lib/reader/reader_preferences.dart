/// How the reader moves from one panel to the next.
enum PanelTransition {
  /// A comfortable zoom: one coherent camera move (constant perceived zoom
  /// rate) inside a static frame.
  zoom,

  /// Fade to black, jump, fade in. No apparent self-motion at all, for readers
  /// who are sensitive to zooming.
  fade,

  /// Instant cut, no animation.
  none,
}

/// Reader options that affect comfort and can be tuned by the user.
class ReaderPreferences {
  const ReaderPreferences({
    this.transition = PanelTransition.zoom,
    this.animationDuration = const Duration(milliseconds: 200),
    this.maxZoom = 3.5,
  });

  /// Values used when nothing has been saved yet.
  static const defaults = ReaderPreferences();

  final PanelTransition transition;

  /// Duration of a single panel transition.
  final Duration animationDuration;

  /// Upper bound on the zoom used to fill the viewport with a panel. Lower
  /// values mean less "looming" and therefore less discomfort.
  final double maxZoom;

  ReaderPreferences copyWith({
    PanelTransition? transition,
    Duration? animationDuration,
    double? maxZoom,
  }) {
    return ReaderPreferences(
      transition: transition ?? this.transition,
      animationDuration: animationDuration ?? this.animationDuration,
      maxZoom: maxZoom ?? this.maxZoom,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderPreferences &&
      other.transition == transition &&
      other.animationDuration == animationDuration &&
      other.maxZoom == maxZoom;

  @override
  int get hashCode => Object.hash(transition, animationDuration, maxZoom);

  @override
  String toString() =>
      'ReaderPreferences(transition: ${transition.name}, '
      'duration: ${animationDuration.inMilliseconds}ms, '
      'maxZoom: $maxZoom)';
}
