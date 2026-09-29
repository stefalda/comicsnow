import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../domain/panel_detection.dart';

/// Geometry of the letterbox transform used to fit a page into the model input.
class Letterbox {
  const Letterbox({
    required this.scaleX,
    required this.scaleY,
    required this.padX,
    required this.padY,
    required this.newWidth,
    required this.newHeight,
    required this.inputWidth,
    required this.inputHeight,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Horizontal/vertical scale actually applied to the original image.
  final double scaleX;
  final double scaleY;

  /// Left/top padding, in model-input pixels.
  final double padX;
  final double padY;

  final int newWidth;
  final int newHeight;
  final int inputWidth;
  final int inputHeight;
  final int imageWidth;
  final int imageHeight;

  /// Maps an x coordinate from model-input space back to the original image.
  double toImageX(double x) => (x - padX) / scaleX;

  /// Maps a y coordinate from model-input space back to the original image.
  double toImageY(double y) => (y - padY) / scaleY;

  @override
  String toString() =>
      'Letterbox(scale=$scaleX/$scaleY, pad=$padX/$padY, '
      'new=${newWidth}x$newHeight)';
}

/// Computes the letterbox that fits [imageWidth]x[imageHeight] into
/// [inputWidth]x[inputHeight] preserving aspect ratio.
Letterbox computeLetterbox({
  required int imageWidth,
  required int imageHeight,
  required int inputWidth,
  required int inputHeight,
  bool allowUpscale = false,
}) {
  assert(imageWidth > 0 && imageHeight > 0);
  assert(inputWidth > 0 && inputHeight > 0);

  final raw = math.min(inputWidth / imageWidth, inputHeight / imageHeight);
  final scale = allowUpscale ? raw : math.min(raw, 1.0);

  final newWidth = math.max(1, (imageWidth * scale).round());
  final newHeight = math.max(1, (imageHeight * scale).round());

  return Letterbox(
    scaleX: newWidth / imageWidth,
    scaleY: newHeight / imageHeight,
    padX: (inputWidth - newWidth) / 2,
    padY: (inputHeight - newHeight) / 2,
    newWidth: newWidth,
    newHeight: newHeight,
    inputWidth: inputWidth,
    inputHeight: inputHeight,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

/// Builds a `[1, 3, H, W]` float32 RGB tensor from [image].
///
/// Values are scaled to `0..1` (what Ultralytics exports expect) and the padding
/// area is filled with [padValue] (`114` by default, matching Ultralytics).
Float32List buildYoloInput({
  required img.Image image,
  required Letterbox letterbox,
  double padValue = 114,
}) {
  final resized = img.copyResize(
    image,
    width: letterbox.newWidth,
    height: letterbox.newHeight,
    interpolation: img.Interpolation.linear,
  );

  final width = letterbox.inputWidth;
  final height = letterbox.inputHeight;
  final area = width * height;
  final tensor = Float32List(area * 3);

  final pad = padValue / 255.0;
  for (var i = 0; i < tensor.length; i++) {
    tensor[i] = pad;
  }

  final offsetX = letterbox.padX.round();
  final offsetY = letterbox.padY.round();

  for (var y = 0; y < resized.height; y++) {
    final targetY = offsetY + y;
    if (targetY < 0 || targetY >= height) continue;
    for (var x = 0; x < resized.width; x++) {
      final targetX = offsetX + x;
      if (targetX < 0 || targetX >= width) continue;

      final pixel = resized.getPixel(x, y);
      final index = targetY * width + targetX;
      tensor[index] = pixel.r / 255.0;
      tensor[area + index] = pixel.g / 255.0;
      tensor[2 * area + index] = pixel.b / 255.0;
    }
  }

  return tensor;
}

/// How to interpret the model output tensor.
class YoloOutputConfig {
  const YoloOutputConfig({
    required this.modelVersion,
    this.confidenceThreshold = 0.35,
    this.iouThreshold = 0.7,
    this.maxDetections = 300,
    this.hasObjectness = false,
    this.isEndToEnd = false,
    this.boxesAreNormalized,
    this.classNames,
    this.targetClasses,
  });

  final String modelVersion;
  final double confidenceThreshold;
  final double iouThreshold;
  final int maxDetections;

  /// YOLOv5-style output (`[1, N, 5+nc]`, with an objectness channel).
  final bool hasObjectness;

  /// Export with NMS baked in: `[1, N, 6]` = `x1, y1, x2, y2, score, classId`.
  final bool isEndToEnd;

  /// Overrides the automatic detection of normalized box coordinates.
  final bool? boxesAreNormalized;

  /// Optional class names; when omitted, a single class is called `panel`.
  final List<String>? classNames;

  /// When non-null, only these class names are kept.
  final Set<String>? targetClasses;
}

/// Decodes a YOLO detection output into [PanelDetection]s in original image
/// coordinates.
///
/// Supports the common export layouts:
///
/// * `[1, 4+nc, anchors]` — YOLOv8/v11, features-first;
/// * `[1, anchors, 4+nc]` — anchors-first;
/// * `[1, N, 6]` — end-to-end export with NMS applied ([YoloOutputConfig.isEndToEnd]).
List<PanelDetection> decodeYoloOutput({
  required List<num> output,
  required List<int> shape,
  required Letterbox letterbox,
  required YoloOutputConfig config,
}) {
  if (output.isEmpty || shape.length < 2) {
    return const [];
  }

  final boxes = config.isEndToEnd
      ? _decodeEndToEnd(output, shape, config)
      : _decodeRaw(output, shape, config, letterbox);

  if (boxes.isEmpty) {
    return const [];
  }

  final kept = _nonMaxSuppression(boxes, config.iouThreshold);
  final limited = kept.length > config.maxDetections
      ? kept.sublist(0, config.maxDetections)
      : kept;

  final classNames = config.classNames;
  final targetClasses = config.targetClasses;

  final detections = <PanelDetection>[];
  for (final box in limited) {
    final className = _classNameFor(box.classId, classNames);
    if (targetClasses != null && !targetClasses.contains(className)) {
      continue;
    }

    final left = letterbox.toImageX(box.x1);
    final top = letterbox.toImageY(box.y1);
    final right = letterbox.toImageX(box.x2);
    final bottom = letterbox.toImageY(box.y2);

    final bounds = Rect.fromLTRB(
      left.clamp(0.0, letterbox.imageWidth.toDouble()),
      top.clamp(0.0, letterbox.imageHeight.toDouble()),
      right.clamp(0.0, letterbox.imageWidth.toDouble()),
      bottom.clamp(0.0, letterbox.imageHeight.toDouble()),
    );

    if (bounds.width < 2 || bounds.height < 2) continue;

    detections.add(
      PanelDetection(
        bounds: bounds,
        confidence: box.score,
        modelVersion: config.modelVersion,
        className: className,
      ),
    );
  }

  return detections;
}

List<_Box> _decodeRaw(
  List<num> output,
  List<int> shape,
  YoloOutputConfig config,
  Letterbox letterbox,
) {
  // The last two dimensions are (a, b). For every real detector the anchor
  // dimension is by far the larger one, so `features = min`, `anchors = max`.
  final a = shape[shape.length - 2];
  final b = shape[shape.length - 1];

  final features = math.min(a, b);
  final anchors = math.max(a, b);
  final featuresFirst = b > a;

  final objectnessChannels = config.hasObjectness ? 1 : 0;
  final classCount = features - 4 - objectnessChannels;
  if (classCount < 1 || anchors < 1) {
    return const [];
  }

  double valueAt(int anchor, int feature) => featuresFirst
      ? output[feature * anchors + anchor].toDouble()
      : output[anchor * features + feature].toDouble();

  final normalized = config.boxesAreNormalized ??
      _looksNormalized(anchors, valueAt);

  final inputWidth = letterbox.inputWidth;
  final inputHeight = letterbox.inputHeight;

  final boxes = <_Box>[];
  for (var anchor = 0; anchor < anchors; anchor++) {
    final cx = valueAt(anchor, 0);
    final cy = valueAt(anchor, 1);
    final w = valueAt(anchor, 2);
    final h = valueAt(anchor, 3);

    var best = 0.0;
    var bestClass = 0;
    for (var c = 0; c < classCount; c++) {
      final score = valueAt(anchor, 4 + objectnessChannels + c);
      if (score > best) {
        best = score;
        bestClass = c;
      }
    }

    if (config.hasObjectness) {
      best *= valueAt(anchor, 4);
    }

    if (best < config.confidenceThreshold) continue;

    final sx = normalized ? inputWidth.toDouble() : 1.0;
    final sy = normalized ? inputHeight.toDouble() : 1.0;

    boxes.add(
      _Box(
        x1: (cx - w / 2) * sx,
        y1: (cy - h / 2) * sy,
        x2: (cx + w / 2) * sx,
        y2: (cy + h / 2) * sy,
        score: best,
        classId: bestClass,
      ),
    );
  }

  return boxes;
}

List<_Box> _decodeEndToEnd(
  List<num> output,
  List<int> shape,
  YoloOutputConfig config,
) {
  final a = shape[shape.length - 2];
  final b = shape[shape.length - 1];

  // Accept both [1, N, 6] and [1, 6, N].
  final rowsFirst = b == 6 || a != 6;
  final rows = rowsFirst ? a : b;

  // End-to-end exports usually emit coordinates in input pixels; scale is not
  // known here, so leave them as-is unless the caller says otherwise.
  final boxes = <_Box>[];
  for (var i = 0; i < rows; i++) {
    final base = rowsFirst ? i * 6 : i;
    final stride = rowsFirst ? 1 : rows;
    double at(int k) => output[base + k * stride].toDouble();

    final score = at(4);
    if (score < config.confidenceThreshold) continue;

    boxes.add(
      _Box(
        x1: at(0),
        y1: at(1),
        x2: at(2),
        y2: at(3),
        score: score,
        classId: at(5).round(),
      ),
    );
  }

  return boxes;
}

bool _looksNormalized(
  int anchors,
  double Function(int anchor, int feature) valueAt,
) {
  // Box coordinates live in the first four features. If everything is <= 2 the
  // export is normalized, otherwise it is in input pixels.
  var maxCoordinate = 0.0;
  final step = math.max(1, anchors ~/ 500);
  for (var anchor = 0; anchor < anchors; anchor += step) {
    for (var f = 0; f < 4; f++) {
      final v = valueAt(anchor, f).abs();
      if (v > maxCoordinate) maxCoordinate = v;
    }
  }
  return maxCoordinate <= 2.0;
}

String _classNameFor(int classId, List<String>? classNames) {
  if (classNames != null && classId >= 0 && classId < classNames.length) {
    return classNames[classId];
  }
  if (classNames == null && classId == 0) {
    return 'panel';
  }
  return 'class_$classId';
}

List<_Box> _nonMaxSuppression(List<_Box> boxes, double iouThreshold) {
  final sorted = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final suppressed = List<bool>.filled(sorted.length, false);
  final kept = <_Box>[];

  for (var i = 0; i < sorted.length; i++) {
    if (suppressed[i]) continue;
    kept.add(sorted[i]);
    for (var j = i + 1; j < sorted.length; j++) {
      if (suppressed[j]) continue;
      if (sorted[i].classId != sorted[j].classId) continue;
      if (_iou(sorted[i], sorted[j]) >= iouThreshold) {
        suppressed[j] = true;
      }
    }
  }

  return kept;
}

double _iou(_Box a, _Box b) {
  final x1 = math.max(a.x1, b.x1);
  final y1 = math.max(a.y1, b.y1);
  final x2 = math.min(a.x2, b.x2);
  final y2 = math.min(a.y2, b.y2);

  final intersection = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
  if (intersection <= 0) return 0;

  final areaA = math.max(0.0, a.x2 - a.x1) * math.max(0.0, a.y2 - a.y1);
  final areaB = math.max(0.0, b.x2 - b.x1) * math.max(0.0, b.y2 - b.y1);
  final union = areaA + areaB - intersection;
  if (union <= 0) return 0;

  return intersection / union;
}

class _Box {
  const _Box({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classId,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
  final int classId;
}
