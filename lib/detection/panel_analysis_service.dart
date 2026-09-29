import '../domain/comic_page.dart';
import '../domain/comic_panel.dart';
import '../domain/page_image_source.dart';
import '../domain/panel_detector.dart';
import '../persistence/panel_cache.dart';
import 'panel_ordering.dart';

/// Turns a [ComicPage] into an ordered list of [ComicPanel]s, using the cache
/// when possible.
///
/// Pipeline:
///
/// ```text
/// page ──▶ cache lookup ──HIT──▶ panels
///                │
///               MISS
///                ▼
///          PanelDetector
///                ▼
///         PanelDetection[]
///                ▼
///          PanelOrdering
///                ▼
///           ComicPanel[]
///                ▼
///              cache
/// ```
class PanelAnalysisService {
  PanelAnalysisService({
    required this.detector,
    required this.cache,
    required this.imageSource,
    required this.ordering,
    this.deduplicate = true,
  });

  final PanelDetector detector;
  final PanelCache cache;
  final PageImageSource imageSource;
  final PanelOrdering ordering;

  /// Removes near-identical overlapping detections before ordering.
  final bool deduplicate;

  String get modelVersion => detector.modelVersion;

  /// Analyzes [page], using the cache when available.
  Future<List<ComicPanel>> analyze(ComicPage page) async {
    final cached = await cache.get(
      pageId: page.id,
      modelVersion: modelVersion,
    );
    if (cached != null) {
      return cached;
    }

    final bytes = await imageSource.readBytes(page);

    final detections = await detector.detect(
      imageBytes: bytes,
      imageWidth: page.width,
      imageHeight: page.height,
    );

    var panels = [
      for (final detection in detections)
        ComicPanel(
          bounds: detection.bounds,
          confidence: detection.confidence,
          order: 0,
        ),
    ];

    if (deduplicate) {
      panels = PanelOrdering.deduplicate(panels);
    }

    final ordered = ordering.order(panels);

    // Nothing detected: leave the cache empty so a later run (with a better
    // model) can try again instead of persisting an empty result.
    if (ordered.isNotEmpty) {
      await cache.save(
        pageId: page.id,
        modelVersion: modelVersion,
        panels: ordered,
      );
    }

    return ordered;
  }

  /// Forces re-detection and overwrites the cache.
  Future<List<ComicPanel>> reanalyze(ComicPage page) async {
    await cache.delete(pageId: page.id, modelVersion: modelVersion);
    return analyze(page);
  }
}
