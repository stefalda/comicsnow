import 'package:comicsnow/comic/image_loader.dart';
import 'package:comicsnow/comic/page_repository.dart';
import 'package:comicsnow/detection/panel_analysis_queue.dart';
import 'package:comicsnow/detection/panel_analysis_service.dart';
import 'package:comicsnow/detection/panel_ordering.dart';
import 'package:comicsnow/domain/comic.dart';
import 'package:comicsnow/domain/comic_page.dart';
import 'package:comicsnow/domain/comic_panel.dart';
import 'package:comicsnow/domain/page_image_source.dart';
import 'package:comicsnow/domain/panel_detection.dart';
import 'package:comicsnow/domain/panel_detector.dart';
import 'package:comicsnow/persistence/database.dart';
import 'package:comicsnow/persistence/panel_cache.dart';
import 'package:comicsnow/reader/page_viewport.dart';
import 'package:comicsnow/reader/panel_reader.dart';
import 'package:comicsnow/reader/panel_reader_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/stub_image.dart';

class _StubImageLoader extends ImageLoader {
  _StubImageLoader(this.image);

  final ImageProvider image;

  @override
  ImageProvider provider(ComicPage page) => image;
}

class _FixedDetector implements PanelDetector {
  @override
  String get modelVersion => 'test';

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
    return [
      PanelDetection(
        bounds: Rect.fromLTWH(0, 0, imageWidth / 2, imageHeight.toDouble()),
        confidence: 0.9,
        modelVersion: modelVersion,
      ),
    ];
  }
}

class _StubImageSource implements PageImageSource {
  _StubImageSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> readBytes(ComicPage page) async => bytes;
}

ComicPage _page(int index, List<ComicPanel> panels) => ComicPage(
  id: 'comic#$index',
  index: index,
  imagePath: '/tmp/page$index.png',
  width: 100,
  height: 200,
  panels: panels,
);

void main() {
  late ComicDatabase database;
  late PanelAnalysisQueue queue;
  late StubImageProvider image;

  setUp(() async {
    database = ComicDatabase.withExecutor(NativeDatabase.memory());
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 20, height: 30)),
    );
    queue = PanelAnalysisQueue(
      analyzer: PanelAnalysisService(
        detector: _FixedDetector(),
        cache: PanelCache(database),
        imageSource: _StubImageSource(png),
        ordering: const PanelOrdering(),
      ),
    );
    image = await createStubImageProvider();
  });

  tearDown(() async {
    image.image.dispose();
    await queue.dispose();
    await database.close();
  });

  PanelReaderPage buildPage({
    required int initialPageIndex,
    required ValueChanged<int> onPageChanged,
    ReaderMode mode = ReaderMode.page,
  }) {
    final panels = [
      const ComicPanel(
        bounds: Rect.fromLTWH(0, 0, 100, 200),
        confidence: 1,
        order: 0,
      ),
    ];
    final comic = Comic(
      id: 'comic',
      title: 'Test',
      pages: [for (var i = 0; i < 5; i++) _page(i, panels)],
    );

    return PanelReaderPage(
      repository: PageRepository(comic),
      queue: queue,
      imageLoader: _StubImageLoader(image),
      initialPageIndex: initialPageIndex,
      initialMode: mode,
      onPageChanged: onPageChanged,
    );
  }

  testWidgets('opens at the given page', (tester) async {
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(initialPageIndex: 2, onPageChanged: reported.add),
      ),
    );
    await tester.pump();

    expect(find.text('Pagina 3/5'), findsOneWidget);
    // The initial position is reported once, so it is persisted.
    expect(reported, [2]);
  });

  testWidgets('page arrows report the new page', (tester) async {
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(initialPageIndex: 0, onPageChanged: reported.add),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.text('Pagina 2/5'), findsOneWidget);
    expect(reported.last, 1);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(reported.last, 0);
  });

  testWidgets('scrubber is hidden until requested, then previews and commits', (
    tester,
  ) async {
    final reported = <int>[];
    final page = buildPage(initialPageIndex: 0, onPageChanged: reported.add);

    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();

    // Hidden by default: no slider in the tree.
    expect(find.byType(Slider), findsNothing);

    // Open it on request.
    await tester.tap(find.byIcon(Icons.unfold_more));
    await tester.pump();

    final scrubber = tester.widget<Slider>(find.byType(Slider));

    // Dragging shows a large preview of the target page above the page.
    scrubber.onChanged!(4);
    await tester.pump();
    expect(find.text('Pagina 5/5'), findsOneWidget);

    // Releasing commits the jump and reports it.
    scrubber.onChangeEnd!(4);
    await tester.pump();

    expect(reported.last, 4);
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(4, 0.001));
  });

  testWidgets('arrow keys navigate like the chevrons', (tester) async {
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(initialPageIndex: 0, onPageChanged: reported.add),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Pagina 2/5'), findsOneWidget);
    expect(reported.last, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Pagina 1/5'), findsOneWidget);
    expect(reported.last, 0);
  });

  testWidgets('long press opens the loupe and does not navigate', (
    tester,
  ) async {
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(initialPageIndex: 0, onPageChanged: reported.add),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageViewport)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(find.byType(RawMagnifier), findsOneWidget);

    // Moving the finger moves the loupe, it must not turn the page.
    await gesture.moveBy(const Offset(60, 40));
    await tester.pump();

    expect(find.byType(RawMagnifier), findsOneWidget);
    expect(find.text('Pagina 1/5'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.byType(RawMagnifier), findsNothing);
    // Only the initial position report: the long press must not navigate.
    expect(reported, [0]);
  });
}
