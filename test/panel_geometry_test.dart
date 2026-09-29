import 'package:comicsnow/reader/panel_viewport.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('containedImageRect', () {
    test('letterboxes a portrait image in a wider viewport', () {
      final rect = containedImageRect(
        const Size(400, 800),
        const Size(1000, 1500),
      );

      // Image aspect ratio 2:3, viewport 1:2 -> width constrained.
      expect(rect.width, closeTo(400, 0.001));
      expect(rect.height, closeTo(600, 0.001));
      expect(rect.top, closeTo(100, 0.001));
      expect(rect.left, closeTo(0, 0.001));
    });

    test('pillarboxes a landscape image in a tall viewport', () {
      final rect = containedImageRect(
        const Size(400, 800),
        const Size(1000, 500),
      );

      expect(rect.width, closeTo(400, 0.001));
      expect(rect.height, closeTo(200, 0.001));
      expect(rect.top, closeTo(300, 0.001));
    });
  });

  group('panelTransformation', () {
    test('centers the panel in the viewport', () {
      const viewport = Size(400, 800);
      const image = Size(1000, 1500);
      final panel = const Rect.fromLTWH(0, 0, 500, 750);

      final matrix = panelTransformation(
        viewportSize: viewport,
        imageSize: image,
        panel: panel,
      );

      // Panel rect in viewport space: (0,100)-(200,400), center (100,250).
      final center = panelRectInViewport(
        viewport: viewport,
        image: image,
        panel: panel,
      ).center;

      final transformed = MatrixUtils.transformPoint(matrix, center);

      expect(transformed.dx, closeTo(viewport.width / 2, 0.001));
      expect(transformed.dy, closeTo(viewport.height / 2, 0.001));
    });

    test('zooms in when the panel is small', () {
      final matrix = panelTransformation(
        viewportSize: const Size(400, 800),
        imageSize: const Size(1000, 1500),
        panel: const Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(matrix.getMaxScaleOnAxis(), greaterThan(1));
    });

    test('falls back to identity for a degenerate panel', () {
      final matrix = panelTransformation(
        viewportSize: const Size(400, 800),
        imageSize: const Size(1000, 1500),
        panel: Rect.zero,
      );

      expect(matrix, Matrix4.identity());
    });
  });
}
