import 'dart:typed_data';
import 'dart:ui';

import 'package:comicsnow/detection/panel_cutter.dart';
import 'package:flutter_test/flutter_test.dart';

ContentMask maskWith(int width, int height, List<Rect> panels) {
  final data = Uint8List(width * height);
  for (final panel in panels) {
    for (var y = panel.top.toInt(); y < panel.bottom.toInt(); y++) {
      for (var x = panel.left.toInt(); x < panel.right.toInt(); x++) {
        data[y * width + x] = 1;
      }
    }
  }
  return ContentMask(width: width, height: height, data: data);
}

void main() {
  group('PanelCutter', () {
    test('splits a 2x2 grid into four panels', () {
      final mask = maskWith(100, 100, [
        const Rect.fromLTRB(10, 10, 40, 40),
        const Rect.fromLTRB(60, 10, 90, 40),
        const Rect.fromLTRB(10, 60, 40, 90),
        const Rect.fromLTRB(60, 60, 90, 90),
      ]);

      final panels = const PanelCutter(
        minGutter: 3,
        minAreaFraction: 0.005,
      ).cut(mask);

      expect(panels, hasLength(4));

      final corners = panels
          .map((r) => '${r.left.round()},${r.top.round()}')
          .toSet();
      expect(corners, {'10,10', '60,10', '10,60', '60,60'});

      for (final panel in panels) {
        expect(panel.width, closeTo(30, 1));
        expect(panel.height, closeTo(30, 1));
      }
    });

    test('returns the whole page when there is no gutter', () {
      final mask = maskWith(100, 100, [const Rect.fromLTRB(0, 0, 100, 100)]);

      final panels = const PanelCutter().cut(mask);

      expect(panels, hasLength(1));
      expect(panels.single, const Rect.fromLTRB(0, 0, 100, 100));
    });

    test('trims the outer margin of a single panel', () {
      final mask = maskWith(100, 100, [const Rect.fromLTRB(8, 12, 92, 88)]);

      final panels = const PanelCutter().cut(mask);

      expect(panels, hasLength(1));
      expect(panels.single.left, 8);
      expect(panels.single.top, 12);
      expect(panels.single.right, 92);
      expect(panels.single.bottom, 88);
    });

    test('handles a vertical three-panel strip', () {
      final mask = maskWith(60, 300, [
        const Rect.fromLTRB(5, 5, 55, 95),
        const Rect.fromLTRB(5, 105, 55, 195),
        const Rect.fromLTRB(5, 205, 55, 295),
      ]);

      final panels = const PanelCutter(
        minGutter: 3,
        minAreaFraction: 0.005,
      ).cut(mask);

      expect(panels, hasLength(3));
      final tops = panels.map((r) => r.top.round()).toList()..sort();
      expect(tops, [5, 105, 205]);
    });

    test('returns nothing for an empty page', () {
      final mask = maskWith(100, 100, const []);

      expect(const PanelCutter().cut(mask), isEmpty);
    });
  });
}
