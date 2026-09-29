import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../domain/panel_detection.dart';
import '../domain/panel_detector.dart';
import 'otsu_threshold.dart';
import 'panel_cutter.dart';

/// Which pixels represent "ink" (drawn content) as opposed to gutter.
enum PanelPolarity {
  /// Decide from the page margin, see [GutterPanelDetector].
  auto,

  /// Dark ink on a light background (classic comic pages, white gutters).
  darkInk,

  /// Light content on a dark background (modern pages with black gutters).
  brightInk,
}

/// Detects panels with classical computer vision — no ML model, no plugin.
///
/// This is the detector used on iOS and as a fallback everywhere else.
///
/// Two things make it work on real pages:
///
/// * the ink/gutter threshold is chosen per page with Otsu's method, so
///   scanned paper with grey gutters is handled instead of a hard-coded white;
/// * the polarity is [PanelPolarity.auto]: the outer margin of the page is
///   inspected to tell a light-background page (classic comics, white gutters)
///   from a dark-background one (modern painted pages, black gutters).
class GutterPanelDetector implements PanelDetector {
  GutterPanelDetector({
    this.analysisWidth = 720,
    this.polarity = PanelPolarity.auto,
    this.manualThreshold,
    this.marginFraction = 0.008,
    this.minGutterFraction = 0.004,
    this.minAreaFraction = 0.004,
    this.emptyLineTolerance = 2,
  });

  /// The page is downscaled to this width before analysis. Large enough to
  /// keep thin gutters visible, small enough to stay fast.
  final int analysisWidth;

  final PanelPolarity polarity;

  /// Overrides the Otsu threshold.
  final int? manualThreshold;

  /// Fraction of the shortest side trimmed from every border before analysis,
  /// to ignore scanner edges and page frames.
  final double marginFraction;

  /// Minimum gutter thickness, as a fraction of the page's shortest side.
  final double minGutterFraction;

  /// Regions smaller than this fraction of the page are discarded.
  final double minAreaFraction;

  /// Fraction of ink pixels allowed in a row/column for it to count as gutter.
  final int emptyLineTolerance;

  @override
  String get modelVersion => 'gutter-xycut-v3';

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<PanelDetection>> detect({
    required Uint8List imageBytes,
    required int imageWidth,
    required int imageHeight,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return const [];
    }

    final sample = decoded.width > analysisWidth
        ? img.copyResize(
            decoded,
            width: analysisWidth,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final analysis = _analyse(sample);
    final rects = _segment(analysis);
    if (rects.isEmpty) {
      return const [];
    }

    final scaleX = imageWidth / analysis.width;
    final scaleY = imageHeight / analysis.height;

    final detections = <PanelDetection>[];
    for (final rect in rects) {
      final bounds = Rect.fromLTRB(
        (rect.left * scaleX).clamp(0, imageWidth.toDouble()).toDouble(),
        (rect.top * scaleY).clamp(0, imageHeight.toDouble()).toDouble(),
        (rect.right * scaleX).clamp(0, imageWidth.toDouble()).toDouble(),
        (rect.bottom * scaleY).clamp(0, imageHeight.toDouble()).toDouble(),
      );
      if (bounds.width < 2 || bounds.height < 2) continue;

      detections.add(
        PanelDetection(
          bounds: bounds,
          confidence: 1,
          modelVersion: modelVersion,
          className: 'panel',
        ),
      );
    }

    return detections;
  }

  // ---------------------------------------------------------------------------
  // Analysis
  // ---------------------------------------------------------------------------

  _Analysis _analyse(img.Image sample) {
    final width = sample.width;
    final height = sample.height;
    final luminance = Uint8List(width * height);
    final histogram = List<int>.filled(256, 0);

    for (var y = 0; y < height; y++) {
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        final pixel = sample.getPixel(x, y);
        final value = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
        luminance[rowOffset + x] = value;
        histogram[value]++;
      }
    }

    final threshold = manualThreshold ?? otsuThreshold(histogram);

    return _Analysis(
      width: width,
      height: height,
      luminance: luminance,
      threshold: threshold,
      margin: (math.min(width, height) * marginFraction).round(),
      backgroundIsBright: _backgroundIsBright(
        luminance,
        width,
        height,
        threshold,
      ),
    );
  }

  /// Decides whether the page background is light or dark, by looking at the
  /// outer border of the page (the margin around the panels).
  bool _backgroundIsBright(
    Uint8List luminance,
    int width,
    int height,
    int threshold,
  ) {
    final band = math.max(2, (math.min(width, height) * 0.02).round());

    var sum = 0;
    var count = 0;

    for (var y = 0; y < height; y++) {
      final onHorizontalBand = y < band || y >= height - band;
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        if (onHorizontalBand || x < band || x >= width - band) {
          sum += luminance[rowOffset + x];
          count++;
        }
      }
    }

    if (count == 0) return true;
    return sum / count > threshold;
  }

  /// Runs the cutter in the configured polarity.
  List<Rect> _segment(_Analysis analysis) {
    final brightInk = switch (polarity) {
      PanelPolarity.auto => !analysis.backgroundIsBright,
      PanelPolarity.darkInk => false,
      PanelPolarity.brightInk => true,
    };

    return _cut(analysis, brightInk: brightInk);
  }

  List<Rect> _cut(_Analysis analysis, {required bool brightInk}) {
    final mask = _buildMask(analysis, brightInk: brightInk);
    return PanelCutter(
      minGutter: math.max(
        2,
        (math.min(mask.width, mask.height) * minGutterFraction).round(),
      ),
      minAreaFraction: minAreaFraction,
      emptyLineTolerance: emptyLineTolerance,
    ).cut(mask);
  }

  ContentMask _buildMask(_Analysis analysis, {required bool brightInk}) {
    final width = analysis.width;
    final height = analysis.height;
    final data = Uint8List(width * height);
    final margin = analysis.margin;
    final rightEdge = width - margin;
    final bottomEdge = height - margin;

    for (var y = margin; y < bottomEdge; y++) {
      final rowOffset = y * width;
      for (var x = margin; x < rightEdge; x++) {
        final value = analysis.luminance[rowOffset + x];
        final isInk = brightInk
            ? value > analysis.threshold
            : value <= analysis.threshold;
        if (isInk) {
          data[rowOffset + x] = 1;
        }
      }
    }

    return ContentMask(width: width, height: height, data: data);
  }
}

class _Analysis {
  const _Analysis({
    required this.width,
    required this.height,
    required this.luminance,
    required this.threshold,
    required this.margin,
    required this.backgroundIsBright,
  });

  final int width;
  final int height;
  final Uint8List luminance;
  final int threshold;
  final int margin;
  final bool backgroundIsBright;
}
