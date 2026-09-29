import 'dart:ui';

import '../domain/comic_panel.dart';

/// Direction in which panels are read.
enum ReadingDirection {
  /// Western comics, most webtoons.
  leftToRight,

  /// Japanese manga, and many manhwa/manhua.
  rightToLeft,
}

/// Sorts panels into a reading order.
///
/// This is a *geometric* problem and it is kept apart from detection on
/// purpose. The initial implementation is a row-based sort: panels are grouped
/// roughly by vertical position, then ordered left/right inside each row.
///
/// It can later be replaced by something smarter (gutter analysis, panel
/// containment, balloons, tilted panels...) without touching the reader or the
/// detector.
class PanelOrdering {
  const PanelOrdering({this.direction = ReadingDirection.leftToRight});

  final ReadingDirection direction;

  /// Returns a new list with [ComicPanel.order] assigned.
  ///
  /// The input list is not modified.
  List<ComicPanel> order(List<ComicPanel> panels) {
    if (panels.length < 2) {
      return [
        for (var i = 0; i < panels.length; i++) panels[i].copyWith(order: i),
      ];
    }

    final sorted = [...panels]..sort(_compare);

    return [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(order: i),
    ];
  }

  int _compare(ComicPanel a, ComicPanel b) {
    final ay = a.bounds.center.dy;
    final by = b.bounds.center.dy;

    // Two panels belong to the same "row" when their centers are close enough
    // vertically, relative to their height.
    final rowTolerance = (a.bounds.height + b.bounds.height) * 0.25;

    if ((ay - by).abs() > rowTolerance) {
      return ay.compareTo(by);
    }

    final ax = a.bounds.center.dx;
    final bx = b.bounds.center.dx;

    return switch (direction) {
      ReadingDirection.leftToRight => ax.compareTo(bx),
      ReadingDirection.rightToLeft => bx.compareTo(ax),
    };
  }

  /// Convenience helper: keeps the largest panel when two detections overlap
  /// almost completely. Cheap de-duplication for models that emit duplicates
  /// despite NMS.
  static List<ComicPanel> deduplicate(
    List<ComicPanel> panels, {
    double iouThreshold = 0.85,
  }) {
    final kept = <ComicPanel>[];

    for (final candidate in panels) {
      var duplicate = false;
      for (final existing in kept) {
        if (_iou(candidate.bounds, existing.bounds) >= iouThreshold) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) {
        kept.add(candidate);
      }
    }

    return kept;
  }

  static double _iou(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.isEmpty) {
      return 0;
    }
    final intersectionArea = intersection.width * intersection.height;
    final unionArea =
        a.width * a.height + b.width * b.height - intersectionArea;
    if (unionArea <= 0) {
      return 0;
    }
    return intersectionArea / unionArea;
  }
}
