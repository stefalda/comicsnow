import 'dart:typed_data';
import 'dart:ui';

import 'package:comicsnow/detection/gutter_panel_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Builds a page with black-bordered panels, like a typical comic page.
Uint8List syntheticPage({
  required int width,
  required int height,
  required List<Rect> panels,
  img.Color? background,
}) {
  final page = img.Image(width: width, height: height);
  img.fill(page, color: background ?? img.ColorRgb8(255, 255, 255));

  for (final panel in panels) {
    final x1 = panel.left.toInt();
    final y1 = panel.top.toInt();
    final x2 = panel.right.toInt() - 1;
    final y2 = panel.bottom.toInt() - 1;

    // Border, like a real panel frame.
    img.drawRect(
      page,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 4,
    );

    // A couple of strokes so the panel interior is not completely empty.
    img.drawLine(
      page,
      x1: x1 + 12,
      y1: y1 + 12,
      x2: x2 - 12,
      y2: y2 - 12,
      color: img.ColorRgb8(30, 30, 30),
      thickness: 6,
    );
  }

  return Uint8List.fromList(img.encodePng(page));
}

Rect rect(double l, double t, double r, double b) => Rect.fromLTRB(l, t, r, b);

void main() {
  group('GutterPanelDetector', () {
    test('finds the four panels of a 2x2 page', () async {
      const width = 400;
      const height = 600;
      final panels = [
        rect(20, 20, 190, 290),
        rect(210, 20, 380, 290),
        rect(20, 310, 190, 580),
        rect(210, 310, 380, 580),
      ];

      final detector = GutterPanelDetector();
      final detections = await detector.detect(
        imageBytes: syntheticPage(width: width, height: height, panels: panels),
        imageWidth: width,
        imageHeight: height,
      );

      expect(detections, hasLength(4));

      // Every detected box should contain the center of one input panel.
      for (final source in panels) {
        final center = source.center;
        final match = detections.where(
          (d) => d.bounds.contains(center),
        );
        expect(match, hasLength(1), reason: 'no detection around $source');
      }
    });

    test('returns a single panel for a page with one frame', () async {
      const width = 400;
      const height = 600;

      final detections = await GutterPanelDetector().detect(
        imageBytes: syntheticPage(
          width: width,
          height: height,
          panels: [rect(20, 20, 380, 580)],
        ),
        imageWidth: width,
        imageHeight: height,
      );

      expect(detections, hasLength(1));
      final bounds = detections.single.bounds;
      expect(bounds.left, closeTo(20, 3));
      expect(bounds.top, closeTo(20, 3));
      expect(bounds.right, closeTo(380, 3));
      expect(bounds.bottom, closeTo(580, 3));
    });

    test('reports coordinates in the original image space', () async {
      const width = 1200;
      const height = 1800;

      final detections = await GutterPanelDetector().detect(
        imageBytes: syntheticPage(
          width: width,
          height: height,
          panels: [rect(60, 60, 1140, 1740)],
        ),
        imageWidth: width,
        imageHeight: height,
      );

      expect(detections, hasLength(1));
      expect(detections.single.bounds.right, greaterThan(width / 2));
      expect(detections.single.bounds.bottom, greaterThan(height / 2));
      expect(detections.single.bounds.right, lessThanOrEqualTo(width.toDouble()));
    });

    test('handles a page with light-grey gutters (scanned paper)', () async {
      // A fixed 235 cutoff would treat this background as ink and find nothing.
      const width = 400;
      const height = 600;
      final panels = [
        rect(20, 20, 190, 290),
        rect(210, 20, 380, 290),
        rect(20, 310, 190, 580),
        rect(210, 310, 380, 580),
      ];

      final detections = await GutterPanelDetector().detect(
        imageBytes: syntheticPage(
          width: width,
          height: height,
          panels: panels,
          background: img.ColorRgb8(205, 205, 200),
        ),
        imageWidth: width,
        imageHeight: height,
      );

      expect(detections, hasLength(4));
    });

    test('handles a tinted page background', () async {
      const width = 400;
      const height = 600;

      final detections = await GutterPanelDetector().detect(
        imageBytes: syntheticPage(
          width: width,
          height: height,
          panels: [rect(20, 20, 380, 280), rect(20, 300, 380, 580)],
          background: img.ColorRgb8(226, 218, 196),
        ),
        imageWidth: width,
        imageHeight: height,
      );

      expect(detections, hasLength(2));
    });

    test('uses a stable model version for the cache key', () {
      expect(GutterPanelDetector().modelVersion, isNotEmpty);
    });
  });
}
