import 'dart:math' as math;

import 'package:comicsnow/reader/camera_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraView.lerp', () {
    const a = CameraView(focalX: 100, focalY: 200, scale: 1);
    const b = CameraView(focalX: 300, focalY: 0, scale: 4);

    test('returns the endpoints unchanged', () {
      expect(CameraView.lerp(a, b, 0), a);
      expect(CameraView.lerp(a, b, 1), b);
    });

    test('interpolates the focal point linearly', () {
      final mid = CameraView.lerp(a, b, 0.5);

      expect(mid.focalX, closeTo(200, 1e-9));
      expect(mid.focalY, closeTo(100, 1e-9));
    });

    test('interpolates the scale geometrically (constant zoom rate)', () {
      final mid = CameraView.lerp(a, b, 0.5);

      // Half the time must give the square root of the zoom ratio, not the
      // arithmetic mean.
      expect(mid.scale, closeTo(math.sqrt(1 * 4), 1e-9));
      expect(mid.scale, isNot(closeTo((1 + 4) / 2, 1e-9)));
    });

    test('keeps a constant ratio between equal time steps', () {
      final first = CameraView.lerp(a, b, 0.25);
      final second = CameraView.lerp(a, b, 0.5);
      final third = CameraView.lerp(a, b, 0.75);

      final ratio1 = second.scale / first.scale;
      final ratio2 = third.scale / second.scale;

      expect(ratio1, closeTo(ratio2, 1e-9));
    });

    test('is symmetric when the endpoints are swapped', () {
      final forward = CameraView.lerp(a, b, 0.3);
      final backward = CameraView.lerp(b, a, 0.7);

      expect(forward.scale, closeTo(backward.scale, 1e-9));
      expect(forward.focalX, closeTo(backward.focalX, 1e-9));
      expect(forward.focalY, closeTo(backward.focalY, 1e-9));
    });

    test('survives a degenerate scale', () {
      const broken = CameraView(focalX: 0, focalY: 0, scale: 0);

      final mid = CameraView.lerp(broken, b, 0.5);

      expect(mid.scale, greaterThan(0));
      expect(mid.scale.isFinite, isTrue);
    });
  });
}
