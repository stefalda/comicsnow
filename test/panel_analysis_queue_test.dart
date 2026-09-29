import 'dart:typed_data';
import 'dart:ui';

import 'package:comicsnow/detection/panel_analysis_queue.dart';
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

class RecordingDetector implements PanelDetector {
  RecordingDetector({this.throwOnEveryCall = false});

  bool throwOnEveryCall;
  int detectCalls = 0;

  @override
  String get modelVersion => 'test-v1';

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
    if (throwOnEveryCall) {
      throw StateError('boom');
    }
    return [
      PanelDetection(
        bounds: const Rect.fromLTWH(0, 0, 10, 10),
        confidence: 0.9,
        modelVersion: modelVersion,
      ),
    ];
  }

  @override
  Future<void> dispose() async {}
}

class RecordingImageSource implements PageImageSource {
  final reads = <String>[];

  @override
  Future<Uint8List> readBytes(ComicPage page) async {
    reads.add(page.id);
    return Uint8List(1);
  }
}

ComicPage page(int index) => ComicPage(
  id: 'page-$index',
  index: index,
  imagePath: '/tmp/page$index.png',
  width: 100,
  height: 100,
);

void main() {
  late ComicDatabase database;
  late RecordingDetector detector;
  late RecordingImageSource imageSource;
  late PanelAnalysisService service;

  setUp(() {
    database = ComicDatabase.withExecutor(NativeDatabase.memory());
    detector = RecordingDetector();
    imageSource = RecordingImageSource();
    service = PanelAnalysisService(
      detector: detector,
      cache: PanelCache(database),
      imageSource: imageSource,
      ordering: const PanelOrdering(),
    );
  });

  tearDown(() => database.close());

  test('processes pages by descending priority', () async {
    final queue = PanelAnalysisQueue(analyzer: service);
    addTearDown(queue.dispose);

    final done = queue.results.take(3).toList();

    queue.request(page(2), priority: 10);
    queue.request(page(0), priority: 100);
    queue.request(page(1), priority: 50);

    final analyses = await done;

    expect(imageSource.reads, ['page-0', 'page-1', 'page-2']);
    expect(analyses.map((a) => a.pageId), containsAll(['page-0', 'page-1', 'page-2']));
  });

  test('never analyses the same page twice', () async {
    final queue = PanelAnalysisQueue(analyzer: service);
    addTearDown(queue.dispose);

    final done = queue.results.take(1).first;

    queue.request(page(0));
    queue.request(page(0));
    queue.request(page(0));
    await done;

    // Give any (incorrect) extra scheduling a chance to run.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(detector.detectCalls, 1);
    expect(imageSource.reads, ['page-0']);
  });

  test('emits failures without stopping the queue', () async {
    detector.throwOnEveryCall = true;

    final queue = PanelAnalysisQueue(analyzer: service);
    addTearDown(queue.dispose);

    final failure = queue.failures.first;
    queue.request(page(0));

    final emitted = await failure;
    expect(emitted.pageId, 'page-0');
    expect(emitted.error, isA<StateError>());
  });

  test('refresh re-runs detection', () async {
    final queue = PanelAnalysisQueue(analyzer: service);
    addTearDown(queue.dispose);

    final first = queue.results.first;
    queue.request(page(0));
    await first;

    final refreshed = queue.results.first;
    queue.refresh(page(0));
    await refreshed;

    expect(detector.detectCalls, 2);
  });
}
