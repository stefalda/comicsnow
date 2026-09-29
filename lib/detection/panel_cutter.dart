import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A binary "ink mask" of a page.
///
/// `1` marks content (a pixel that is part of a drawing/border/text), `0` marks
/// gutter/background. The mask is deliberately tiny compared to the page: the
/// cutter only needs a low-resolution map of where the ink is.
class ContentMask {
  ContentMask({
    required this.width,
    required this.height,
    required this.data,
  }) : assert(data.length == width * height, 'mask size mismatch');

  final int width;
  final int height;

  /// Row-major, `width * height` entries, each `0` or `1`.
  final Uint8List data;

  bool isContent(int x, int y) => data[y * width + x] != 0;

  @override
  String toString() => 'ContentMask(${width}x$height)';
}

/// Segments a page into panels with a recursive XY-cut.
///
/// The idea: panels are separated by gutters, and a gutter is a full run of
/// empty (background) rows or columns. The cutter alternates between horizontal
/// and vertical cuts, always splitting at the widest gutter, until a region
/// contains no full gutter — that region is a panel.
///
/// It is a heuristic, but it needs no model, runs everywhere in pure Dart, and
/// degrades gracefully: when it cannot separate anything it returns the whole
/// page as a single panel.
class PanelCutter {
  const PanelCutter({
    this.minGutter = 3,
    this.minAreaFraction = 0.004,
    this.minEdge = 8,
    this.maxPanels = 60,
    this.emptyLineTolerance = 2,
  });

  /// Minimum thickness (in mask pixels) for a run of empty rows/columns to be
  /// considered a real gutter.
  final int minGutter;

  /// Regions smaller than this fraction of the page are discarded.
  final double minAreaFraction;

  /// Regions thinner than this (in mask pixels) are never split further.
  final int minEdge;

  /// Safety cap on the number of returned panels.
  final int maxPanels;

  /// A row/column counts as "empty" when it contains at most this many ink
  /// pixels. Kept as an absolute pixel count — a fraction of the span would
  /// swallow thin panel borders on downscaled pages.
  final int emptyLineTolerance;

  /// Returns panel rectangles in mask coordinates, largest first.
  List<Rect> cut(ContentMask mask) {
    if (mask.width < 2 || mask.height < 2) {
      return const [];
    }

    final pageArea = mask.width * mask.height;
    final minArea = math.max(16, (pageArea * minAreaFraction).round());

    final panels = <Rect>[];
    final stack = <_Region>[_Region(0, 0, mask.width, mask.height)];

    while (stack.isNotEmpty) {
      final region = _shrink(mask, stack.removeLast());
      if (region == null) continue;

      if (region.area < minArea ||
          region.width < minEdge ||
          region.height < minEdge) {
        if (region.area >= minArea) {
          panels.add(region.toRect());
        }
        continue;
      }

      final horizontal = _widestGap(mask, region, isHorizontal: true);
      final vertical = _widestGap(mask, region, isHorizontal: false);

      // A gap is only usable when it strictly separates two non-empty sides.
      final canSplitHorizontally = horizontal != null &&
          horizontal.start > region.top &&
          horizontal.end < region.bottom;
      final canSplitVertically =
          vertical != null && vertical.start > region.left && vertical.end < region.right;

      if (canSplitHorizontally &&
          (!canSplitVertically || horizontal.length >= vertical.length)) {
        stack.add(
          _Region(region.left, horizontal.end, region.right, region.bottom),
        );
        stack.add(
          _Region(region.left, region.top, region.right, horizontal.start),
        );
        continue;
      }

      if (canSplitVertically) {
        stack.add(
          _Region(vertical.end, region.top, region.right, region.bottom),
        );
        stack.add(
          _Region(region.left, region.top, vertical.start, region.bottom),
        );
        continue;
      }

      panels.add(region.toRect());
    }

    panels.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));

    if (panels.length > maxPanels) {
      return panels.sublist(0, maxPanels);
    }
    return panels;
  }

  /// Shrinks a region to the bounding box of its content, or `null` if empty.
  _Region? _shrink(ContentMask mask, _Region region) {
    var left = region.right;
    var top = region.bottom;
    var right = region.left;
    var bottom = region.top;

    for (var y = region.top; y < region.bottom; y++) {
      final rowOffset = y * mask.width;
      for (var x = region.left; x < region.right; x++) {
        if (mask.data[rowOffset + x] == 0) continue;
        if (x < left) left = x;
        if (x >= right) right = x + 1;
        if (y < top) top = y;
        if (y >= bottom) bottom = y + 1;
      }
    }

    if (right <= left || bottom <= top) return null;

    // Pad by one pixel so the content pixel itself stays inside the region.
    return _Region(
      math.max(region.left, left),
      math.max(region.top, top),
      math.min(region.right, right),
      math.min(region.bottom, bottom),
    );
  }

  _Gap? _widestGap(
    ContentMask mask,
    _Region region, {
    required bool isHorizontal,
  }) {
    final start = isHorizontal ? region.top : region.left;
    final end = isHorizontal ? region.bottom : region.right;

    _Gap? best;
    int? runStart;

    void closeRun(int runEnd) {
      final opened = runStart;
      if (opened == null) return;
      final length = runEnd - opened;
      if (length >= minGutter && (best == null || length > best!.length)) {
        best = _Gap(opened, runEnd);
      }
      runStart = null;
    }

    for (var index = start; index < end; index++) {
      var content = 0;

      if (isHorizontal) {
        final rowOffset = index * mask.width;
        for (var x = region.left; x < region.right; x++) {
          if (mask.data[rowOffset + x] != 0) content++;
        }
      } else {
        for (var y = region.top; y < region.bottom; y++) {
          if (mask.data[y * mask.width + index] != 0) content++;
        }
      }

      if (content <= emptyLineTolerance) {
        runStart ??= index;
      } else {
        closeRun(index);
      }
    }
    closeRun(end);

    return best;
  }
}

class _Region {
  const _Region(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
  int get area => width * height;

  Rect toRect() => Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        right.toDouble(),
        bottom.toDouble(),
      );

  @override
  String toString() => '_Region($left,$top,$right,$bottom)';
}

class _Gap {
  const _Gap(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start;
}
