import 'dart:typed_data';
import 'dart:ui';

import 'package:comicsnow/detection/panel_analysis_service.dart';
import 'package:comicsnow/detection/panel_ordering.dart';
import 'package:comicsnow/domain/comic_page.dart';
import 'package:comicsnow/domain/page_image_source.dart';
import 'package:comicsnow/domain/panel_detection.dart';
import 'package:comicsnow/domain/panel_detector.dart';
import 'package:comicsnow/persistence/database.dart';
import 'package:comicsnow/persistence/panel_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDetector implements PanelDetector {
  FakeDetector({this.version = 'test-v1'});

  String version;
  int detectCalls = 0;

  @override
  String get modelVersion => version;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PanelDetection>> detect({
    required Uint8List imageBytes,
    required int imageWidth,
    required int imageHeight,
  }) async {
    detectCalls++;
    return [
      PanelDetection(
        bounds: const Rect.fromLTWH(0, 200, 100, 100),
        confidence: 0.8,
        modelVersion: version,
      ),
      PanelDetection(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        confidence: 0.9,
        modelVersion: version,
      ),
    ];
  }

  @override
  Future<void> dispose() async {}
}

class FakeImageSource implements PageImageSource {
  int reads = 0;

  @override
  Future<Uint8List> readBytes(ComicPage page) async {
    reads++;
    return Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  late ComicDatabase database;
  late FakeDetector detector;
  late FakeImageSource imageSource;
  late PanelAnalysisService service;

  final page = const ComicPage(
    id: 'comic#0',
    index: 0,
    imagePath: '/tmp/page0.png',
    width: 100,
    height: 400,
  );

  setUp(() {
    database = ComicDatabase.withExecutor(NativeDatabase.memory());
    detector = FakeDetector();
    imageSource = FakeImageSource();
    service = PanelAnalysisService(
      detector: detector,
      cache: PanelCache(database),
      imageSource: imageSource,
      ordering: const PanelOrdering(),
    );
  });

  tearDown(() => database.close());

  test('detects, orders and caches', () async {
    final panels = await service.analyze(page);

    expect(panels, hasLength(2));
    expect(panels.first.bounds.top, 0);
    expect(panels.last.bounds.top, 200);
    expect(detector.detectCalls, 1);

    final cached = await PanelCache(database).get(
      pageId: page.id,
      modelVersion: detector.modelVersion,
    );
    expect(cached, hasLength(2));
  });

  test('second analysis is served from the cache', () async {
    await service.analyze(page);
    await service.analyze(page);

    expect(detector.detectCalls, 1);
    expect(imageSource.reads, 1);
  });

  test('reanalyze bypasses the cache', () async {
    await service.analyze(page);
    await service.reanalyze(page);

    expect(detector.detectCalls, 2);
  });

  test('a new model version invalidates the cache', () async {
    await service.analyze(page);

    detector.version = 'test-v2';
    await service.analyze(page);

    expect(detector.detectCalls, 2);
  });
}
