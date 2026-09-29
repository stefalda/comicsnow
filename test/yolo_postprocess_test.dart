import 'package:comicsnow/detection/yolo_postprocess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Number of anchors used in the synthetic tensors.
///
/// Real detectors emit thousands of anchors and few features (e.g. `[1,84,8400]`),
/// and the decoder relies on that: the anchor axis is the larger one. The tests
/// therefore pad to a realistic ratio instead of using tensors where features
/// outnumber anchors.
const int kAnchors = 16;

/// Builds a features-first tensor `[1, features, kAnchors]`.
List<num> featuresFirst(List<List<double>> usedAnchors) {
  final features = usedAnchors.first.length;
  final data = List<num>.filled(features * kAnchors, 0);
  for (var anchor = 0; anchor < usedAnchors.length; anchor++) {
    for (var f = 0; f < features; f++) {
      data[f * kAnchors + anchor] = usedAnchors[anchor][f];
    }
  }
  return data;
}

/// Builds an anchors-first tensor `[1, kAnchors, features]`.
List<num> anchorsFirst(List<List<double>> usedAnchors) {
  final features = usedAnchors.first.length;
  final data = <num>[];
  for (final row in usedAnchors) {
    data.addAll(row);
  }
  data.addAll(List<num>.filled((kAnchors - usedAnchors.length) * features, 0));
  return data;
}

List<int> featuresFirstShape(int features) => [1, features, kAnchors];
List<int> anchorsFirstShape(int features) => [1, kAnchors, features];

YoloOutputConfig config({
  double confidence = 0.35,
  double iou = 0.7,
  bool objectness = false,
  bool endToEnd = false,
  bool? normalized,
  List<String>? classNames,
  Set<String>? targetClasses,
}) {
  return YoloOutputConfig(
    modelVersion: 'test',
    confidenceThreshold: confidence,
    iouThreshold: iou,
    hasObjectness: objectness,
    isEndToEnd: endToEnd,
    boxesAreNormalized: normalized,
    classNames: classNames,
    targetClasses: targetClasses,
  );
}

void main() {
  group('computeLetterbox', () {
    test('letterboxes a landscape image', () {
      final lb = computeLetterbox(
        imageWidth: 2000,
        imageHeight: 1000,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(lb.newWidth, 640);
      expect(lb.newHeight, 320);
      expect(lb.padX, 0);
      expect(lb.padY, 160);
      expect(lb.toImageX(0), 0);
      expect(lb.toImageX(640), 2000);
      expect(lb.toImageY(160), 0);
      expect(lb.toImageY(480), 1000);
    });

    test('letterboxes a portrait image', () {
      final lb = computeLetterbox(
        imageWidth: 1000,
        imageHeight: 2000,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(lb.newWidth, 320);
      expect(lb.newHeight, 640);
      expect(lb.padX, 160);
      expect(lb.padY, 0);
    });

    test('does not upscale by default', () {
      final lb = computeLetterbox(
        imageWidth: 320,
        imageHeight: 320,
        inputWidth: 640,
        inputHeight: 640,
      );

      expect(lb.newWidth, 320);
      expect(lb.padX, 160);
    });

    test('upscales when asked', () {
      final lb = computeLetterbox(
        imageWidth: 320,
        imageHeight: 320,
        inputWidth: 640,
        inputHeight: 640,
        allowUpscale: true,
      );

      expect(lb.newWidth, 640);
      expect(lb.padX, 0);
    });
  });

  group('buildYoloInput', () {
    test('produces a normalized CHW tensor', () {
      final image = img.Image(width: 2, height: 2);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));

      final lb = computeLetterbox(
        imageWidth: 2,
        imageHeight: 2,
        inputWidth: 2,
        inputHeight: 2,
      );

      final tensor = buildYoloInput(image: image, letterbox: lb);

      expect(tensor.length, 3 * 2 * 2);
      expect(tensor[0], closeTo(1.0, 1e-6)); // R plane
      expect(tensor[4], closeTo(0.0, 1e-6)); // G plane
      expect(tensor[8], closeTo(0.0, 1e-6)); // B plane
    });

    test('pads with 114/255', () {
      final image = img.Image(width: 2, height: 2);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));

      final lb = computeLetterbox(
        imageWidth: 2,
        imageHeight: 2,
        inputWidth: 4,
        inputHeight: 4,
      );

      final tensor = buildYoloInput(image: image, letterbox: lb);
      const area = 16;

      expect(tensor[0], closeTo(114 / 255, 1e-6)); // top-left padding
      expect(tensor[1 * 4 + 1], closeTo(1.0, 1e-6)); // image R at (1,1)
      expect(tensor[area + 1 * 4 + 1], closeTo(0.0, 1e-6));
    });
  });

  group('decodeYoloOutput', () {
    final identity = computeLetterbox(
      imageWidth: 640,
      imageHeight: 640,
      inputWidth: 640,
      inputHeight: 640,
    );

    test('decodes features-first output and applies NMS', () {
      final data = featuresFirst([
        [100, 100, 50, 50, 0.9],
        [102, 102, 50, 50, 0.8], // overlaps the first, suppressed
        [400, 400, 100, 100, 0.5],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: identity,
        config: config(),
      );

      expect(detections, hasLength(2));
      expect(detections.first.confidence, closeTo(0.9, 1e-6));
      expect(detections.first.bounds.left, closeTo(75, 1e-6));
      expect(detections.first.bounds.top, closeTo(75, 1e-6));
      expect(detections.first.bounds.right, closeTo(125, 1e-6));
      expect(detections.first.className, 'panel');
      expect(detections.last.bounds.left, closeTo(350, 1e-6));
    });

    test('decodes anchors-first output identically', () {
      final data = anchorsFirst([
        [100, 100, 50, 50, 0.9],
        [400, 400, 100, 100, 0.5],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: anchorsFirstShape(5),
        letterbox: identity,
        config: config(),
      );

      expect(detections, hasLength(2));
      expect(detections.first.bounds.left, closeTo(75, 1e-6));
      expect(detections.last.bounds.right, closeTo(450, 1e-6));
    });

    test('handles normalized coordinates', () {
      final data = featuresFirst([
        [0.5, 0.5, 0.25, 0.25, 0.9],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: identity,
        config: config(),
      );

      expect(detections, hasLength(1));
      expect(detections.single.bounds.left, closeTo(240, 1e-6));
      expect(detections.single.bounds.right, closeTo(400, 1e-6));
    });

    test('applies the confidence threshold', () {
      final data = featuresFirst([
        [100, 100, 50, 50, 0.9],
        [400, 400, 100, 100, 0.2],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: identity,
        config: config(confidence: 0.5),
      );

      expect(detections, hasLength(1));
      expect(detections.single.confidence, closeTo(0.9, 1e-6));
    });

    test('multiplies objectness for v5-style outputs', () {
      // 4 box + 1 objectness + 1 class
      final data = featuresFirst([
        [100, 100, 50, 50, 0.9, 0.9], // 0.81 → kept
        [400, 400, 50, 50, 0.9, 0.1], // 0.09 → dropped
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(6),
        letterbox: identity,
        config: config(objectness: true),
      );

      expect(detections, hasLength(1));
      expect(detections.single.confidence, closeTo(0.81, 1e-6));
    });

    test('decodes end-to-end output', () {
      final data = <num>[
        10, 20, 100, 120, 0.95, 0,
        200, 200, 300, 300, 0.40, 0,
        ...List<num>.filled((kAnchors - 2) * 6, 0),
      ];

      final detections = decodeYoloOutput(
        output: data,
        shape: [1, kAnchors, 6],
        letterbox: identity,
        config: config(endToEnd: true, confidence: 0.35),
      );

      expect(detections, hasLength(2));
      expect(detections.first.bounds.left, closeTo(10, 1e-6));
      expect(detections.first.bounds.bottom, closeTo(120, 1e-6));
    });

    test('maps coordinates back through the letterbox', () {
      final lb = computeLetterbox(
        imageWidth: 2000,
        imageHeight: 1000,
        inputWidth: 640,
        inputHeight: 640,
      );

      final data = featuresFirst([
        [320, 320, 64, 64, 0.9],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: lb,
        config: config(),
      );

      expect(detections, hasLength(1));
      // Input box x: 288..352 → image x: 900..1100
      expect(detections.single.bounds.left, closeTo(900, 1e-6));
      expect(detections.single.bounds.right, closeTo(1100, 1e-6));
      // Input box y: 288..352 → image y: 400..600 (pad 160)
      expect(detections.single.bounds.top, closeTo(400, 1e-6));
      expect(detections.single.bounds.bottom, closeTo(600, 1e-6));
    });

    test('filters by target class', () {
      final data = featuresFirst([
        [100, 100, 50, 50, 0.9],
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: identity,
        config: config(targetClasses: {'balloon'}),
      );

      expect(detections, isEmpty);
    });

    test('clamps boxes to the image', () {
      final data = featuresFirst([
        [-25, -25, 100, 100, 0.9], // partially outside the top-left corner
      ]);

      final detections = decodeYoloOutput(
        output: data,
        shape: featuresFirstShape(5),
        letterbox: identity,
        config: config(),
      );

      expect(detections, hasLength(1));
      expect(detections.single.bounds.left, 0);
      expect(detections.single.bounds.top, 0);
      expect(detections.single.bounds.right, closeTo(25, 1e-6));
      expect(detections.single.bounds.bottom, closeTo(25, 1e-6));
    });
  });
}
