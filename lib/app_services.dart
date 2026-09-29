import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'comic/app_storage.dart';
import 'comic/cover_cache.dart';
import 'comic/image_loader.dart';
import 'detection/gutter_panel_detector.dart';
import 'detection/onnx_panel_detector.dart';
import 'detection/panel_analysis_queue.dart';
import 'detection/panel_analysis_service.dart';
import 'detection/panel_ordering.dart';
import 'domain/panel_detector.dart';
import 'persistence/database.dart';
import 'persistence/panel_cache.dart';
import 'persistence/recent_comics_store.dart';
import 'settings/reader_settings.dart';

/// Asset path of the optional ONNX panel-detection model.
///
/// ONNX Runtime runs on desktop and mobile, so this is the preferred path when
/// the file is present. Drop an exported `.onnx` here to enable it.
const String kOnnxModelPath = 'assets/models/panel_detector.onnx';

/// Cache key for the ONNX model. Bump it whenever the model changes.
///
/// Current model: Inkwell Panel Detector (cedarrapidsboy/inkwell-panel-models),
/// YOLOv8-n, input 640, single class `panel`. See AGENTS.md for alternatives.
const String kOnnxModelVersion = 'inkwell-yolov8n-640-v1';

/// Default reading direction: Italian and American comics are read
/// left-to-right, top-to-bottom.
const ReadingDirection kDefaultReadingDirection = ReadingDirection.leftToRight;

/// Hand-rolled composition root.
///
/// No Riverpod / DI container on purpose: the dependency graph is small and
/// explicit, which keeps the domain simple.
class AppServices {
  AppServices({
    required this.database,
    required this.imageLoader,
    required this.detector,
    required this.cache,
    required this.analysisService,
    required this.analysisQueue,
    required this.settings,
    required this.recentComics,
    required this.coverCache,
  });

  static Future<AppServices> create() async {
    final database = ComicDatabase();
    final imageLoader = ImageLoader();
    final detector = await _createDetector();
    final settings = ReaderSettings(await SharedPreferences.getInstance());

    debugPrint(
      'ComicsNow: detector = ${detector.runtimeType} '
      '(modelVersion: ${detector.modelVersion})',
    );

    final cache = PanelCache(database);
    final recentComics = RecentComicsStore(database);
    final coverCache = CoverCache(directory: appStorageDirectory);
    final analysisService = PanelAnalysisService(
      detector: detector,
      cache: cache,
      imageSource: imageLoader,
      ordering: const PanelOrdering(direction: kDefaultReadingDirection),
    );

    final analysisQueue = PanelAnalysisQueue(
      analyzer: analysisService,
      onError: (pageId, error, stackTrace) {
        debugPrint('Panel analysis failed for $pageId: $error');
      },
    );

    return AppServices(
      database: database,
      imageLoader: imageLoader,
      detector: detector,
      cache: cache,
      analysisService: analysisService,
      analysisQueue: analysisQueue,
      settings: settings,
      recentComics: recentComics,
      coverCache: coverCache,
    );
  }

  /// Picks the best detector available on the current platform.
  ///
  /// 1. ONNX model present → [OnnxPanelDetector] (desktop and mobile).
  /// 2. Otherwise → the model-free [GutterPanelDetector].
  static Future<PanelDetector> _createDetector() async {
    final onnxAvailable = await _assetExists(kOnnxModelPath);

    if (onnxAvailable) {
      return OnnxPanelDetector(
        modelPath: kOnnxModelPath,
        modelVersion: kOnnxModelVersion,
        // 0.35 measured best on the sample corpus (14/15 pages exact);
        // 0.25 over-detects, 0.50 does not improve. See AGENTS.md.
        confidenceThreshold: 0.35,
      );
    }

    return GutterPanelDetector();
  }

  static Future<bool> _assetExists(String assetPath) async {
    try {
      // Use the manifest instead of loading the asset: a model can be tens of
      // megabytes and we only need to know whether it is there.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(assetPath);
    } catch (_) {
      return false;
    }
  }

  final ComicDatabase database;
  final ImageLoader imageLoader;
  final PanelDetector detector;
  final PanelCache cache;
  final PanelAnalysisService analysisService;
  final PanelAnalysisQueue analysisQueue;
  final ReaderSettings settings;

  /// Library of recently opened comics, shown on the home screen.
  final RecentComicsStore recentComics;

  /// Generates and stores the cover images of the library.
  final CoverCache coverCache;

  ReadingDirection get readingDirection => analysisService.ordering.direction;

  /// Human readable description of the detector in use, shown in the UI.
  String get detectorDescription {
    final name = switch (detector) {
      OnnxPanelDetector() => 'ONNX (modello ML)',
      _ => 'algoritmo gutter (nessun modello)',
    };
    return '$name · ${detector.modelVersion}';
  }

  Future<void> dispose() async {
    await analysisQueue.dispose();
    await detector.dispose();
    await database.close();
  }
}
