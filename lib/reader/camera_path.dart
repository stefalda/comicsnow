import 'dart:math' as math;

/// A camera over the page: the content point currently under the centre of the
/// viewport ([focalX], [focalY]) plus the magnification ([scale]).
///
/// Animating a panel change by blending two raw `Matrix4`s mixes scale and
/// translation independently: the effective centre of the zoom drifts, so the
/// eye has no stable aim point, and the zoom rate is not constant. Blending two
/// [CameraView]s instead — linear on the focal point, **logarithmic on the
/// scale** — gives one coherent camera move with a constant perceived zoom rate
/// and a straight focal path. That is markedly easier on the vestibular system.
class CameraView {
  const CameraView({
    required this.focalX,
    required this.focalY,
    required this.scale,
  });

  /// Content-space x under the viewport centre.
  final double focalX;

  /// Content-space y under the viewport centre.
  final double focalY;

  /// Magnification (1 = content shown at its fitted size).
  final double scale;

  /// Interpolates between two camera views.
  ///
  /// [t] is expected in `0..1`. The scale is interpolated geometrically, so the
  /// perceived zoom rate is constant (half the time gives the square root of
  /// the zoom ratio).
  static CameraView lerp(CameraView a, CameraView b, double t) {
    final logA = math.log(_safeScale(a.scale));
    final logB = math.log(_safeScale(b.scale));
    return CameraView(
      focalX: _lerp(a.focalX, b.focalX, t),
      focalY: _lerp(a.focalY, b.focalY, t),
      scale: math.exp(_lerp(logA, logB, t)),
    );
  }

  @override
  String toString() =>
      'CameraView(focal: ${focalX.toStringAsFixed(1)},'
      '${focalY.toStringAsFixed(1)} scale: ${scale.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      other is CameraView &&
      other.focalX == focalX &&
      other.focalY == focalY &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(focalX, focalY, scale);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _safeScale(double scale) => scale.isFinite && scale > 0 ? scale : 1;
