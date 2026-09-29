import 'dart:ui';

import 'package:comicsnow/reader/magnifier_lens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(400, 800);
  const size = 140.0;
  const lift = 76.0;

  MagnifierPlacement place(Offset focalPoint) => magnifierPlacement(
    focalPoint: focalPoint,
    viewportSize: viewport,
    size: size,
    lift: lift,
  );

  /// The lens must always show the content *under the finger*: `RawMagnifier`
  /// displays, at its centre, the content at `focalPointOffset + centre`.
  void expectShowsFocalPoint(Offset focalPoint) {
    final placement = place(focalPoint);
    final shown = placement.focalPointOffset + placement.lens.center;

    expect(
      shown.dx,
      closeTo(focalPoint.dx, 0.001),
      reason: 'x wrong for $focalPoint',
    );
    expect(
      shown.dy,
      closeTo(focalPoint.dy, 0.001),
      reason: 'y wrong for $focalPoint',
    );
  }

  void expectInsideViewport(Offset focalPoint) {
    final lens = place(focalPoint).lens;

    expect(lens.left, greaterThanOrEqualTo(-0.001), reason: '$focalPoint');
    expect(lens.top, greaterThanOrEqualTo(-0.001), reason: '$focalPoint');
    expect(
      lens.right,
      lessThanOrEqualTo(viewport.width + 0.001),
      reason: '$focalPoint',
    );
    expect(
      lens.bottom,
      lessThanOrEqualTo(viewport.height + 0.001),
      reason: '$focalPoint',
    );
  }

  group('magnifierPlacement', () {
    test('floats above the finger when there is room', () {
      const focalPoint = Offset(200, 400);

      final placement = place(focalPoint);

      expect(placement.lens.center.dy, lessThan(focalPoint.dy));
      expect(placement.lens.center.dx, closeTo(focalPoint.dx, 0.001));
      expect(placement.focalPointOffset.dy, closeTo(lift, 0.001));
    });

    test('shows the finger point in the middle of the viewport', () {
      expectShowsFocalPoint(const Offset(200, 400));
    });

    // The edges are where the lens has to be nudged to stay on screen; the
    // focal offset must follow, otherwise the lens magnifies another spot.
    test('shows the finger point at every edge', () {
      for (final focalPoint in const [
        Offset(0, 400), // left
        Offset(400, 400), // right
        Offset(200, 0), // top
        Offset(200, 800), // bottom
        Offset(0, 0), // top-left corner
        Offset(400, 0), // top-right corner
        Offset(0, 800), // bottom-left corner
        Offset(400, 800), // bottom-right corner
        Offset(5, 5),
        Offset(395, 795),
      ]) {
        expectShowsFocalPoint(focalPoint);
      }
    });

    test('stays inside the viewport at every edge', () {
      for (final focalPoint in const [
        Offset(0, 400),
        Offset(400, 400),
        Offset(200, 0),
        Offset(200, 800),
        Offset(0, 0),
        Offset(400, 800),
      ]) {
        expectInsideViewport(focalPoint);
      }
    });

    test('flips below the finger when the top edge is near', () {
      final placement = place(const Offset(200, 10));

      expect(placement.lens.center.dy, greaterThan(10));
      expectShowsFocalPoint(const Offset(200, 10));
    });

    test('adapts the focal offset in the corners', () {
      const focalPoint = Offset(400, 800);
      final placement = place(focalPoint);

      expectInsideViewport(focalPoint);
      expectShowsFocalPoint(focalPoint);
      // The lens was nudged left to stay on screen, so the offset is no longer
      // the nominal (0, lift): it compensates the shift.
      expect(placement.focalPointOffset.dx, isNot(closeTo(0, 0.001)));
    });
  });

  group('lens size', () {
    test('is 280 px wide and still magnifies 2.5x', () {
      const lens = MagnifierLens(
        focalPoint: Offset(200, 500),
        viewportSize: viewport,
      );

      expect(lens.size, 280);
      expect(lens.magnification, 2.5);
    });

    test('the default lift keeps the whole lens above the finger', () {
      final placement = magnifierPlacement(
        focalPoint: const Offset(200, 500),
        viewportSize: viewport,
        size: 280,
      );

      expect(placement.lens.height, 280);
      expect(
        placement.lens.bottom,
        lessThanOrEqualTo(500),
        reason: 'the finger must not cover the magnified content',
      );
    });

    test('the finger gap does not depend on the lens size', () {
      // The lift grows with the lens, so the free space between the lens and
      // the finger stays the same.
      for (final size in const [140.0, 280.0]) {
        final placement = magnifierPlacement(
          focalPoint: const Offset(200, 500),
          viewportSize: viewport,
          size: size,
        );

        expect(
          500 - placement.lens.bottom,
          closeTo(defaultGap, 0.001),
          reason: 'size $size',
        );
      }
    });
  });
}
