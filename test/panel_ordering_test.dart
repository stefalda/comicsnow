import 'dart:ui';

import 'package:comicsnow/detection/panel_ordering.dart';
import 'package:comicsnow/domain/comic_panel.dart';
import 'package:flutter_test/flutter_test.dart';

ComicPanel panel(double left, double top, double width, double height) {
  return ComicPanel(
    bounds: Rect.fromLTWH(left, top, width, height),
    confidence: 0.9,
    order: 0,
  );
}

void main() {
  group('PanelOrdering', () {
    test('orders western pages top-to-bottom, left-to-right', () {
      const ordering = PanelOrdering();
      final panels = [
        panel(400, 0, 200, 200), // top right
        panel(0, 0, 200, 200), // top left
        panel(0, 400, 200, 200), // bottom
      ];

      final ordered = ordering.order(panels);

      expect(ordered.map((p) => p.bounds.left).toList(), [0, 400, 0]);
      expect(ordered.map((p) => p.order).toList(), [0, 1, 2]);
    });

    test('orders manga pages top-to-bottom, right-to-left', () {
      const ordering = PanelOrdering(
        direction: ReadingDirection.rightToLeft,
      );
      final panels = [
        panel(0, 0, 200, 200),
        panel(400, 0, 200, 200),
      ];

      final ordered = ordering.order(panels);

      expect(ordered.first.bounds.left, 400);
      expect(ordered.last.bounds.left, 0);
    });

    test('keeps panels whose centers are close vertically in the same row', () {
      const ordering = PanelOrdering();
      final panels = [
        panel(0, 0, 200, 200),
        panel(400, 10, 200, 200),
      ];

      final ordered = ordering.order(panels);

      expect(ordered.first.bounds.left, 0);
      expect(ordered.last.bounds.left, 400);
    });

    test('does not modify the input list', () {
      const ordering = PanelOrdering();
      final panels = [
        panel(400, 0, 200, 200),
        panel(0, 0, 200, 200),
      ];

      ordering.order(panels);

      expect(panels.first.bounds.left, 400);
    });

    test('deduplicate drops overlapping detections', () {
      final panels = [
        panel(0, 0, 200, 200),
        panel(4, 4, 196, 196), // almost the same box
        panel(0, 400, 200, 200),
      ];

      final kept = PanelOrdering.deduplicate(panels);

      expect(kept, hasLength(2));
    });
  });
}
