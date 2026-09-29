import 'dart:ui';

import 'package:comicsnow/domain/comic_page.dart';
import 'package:comicsnow/domain/comic_panel.dart';
import 'package:comicsnow/reader/panel_reader.dart';
import 'package:flutter_test/flutter_test.dart';

ComicPanel panelAt(double top, {int order = 0}) {
  return ComicPanel(
    bounds: Rect.fromLTWH(0, top, 100, 100),
    confidence: 1,
    order: order,
  );
}

ComicPage pageWith(int index, List<ComicPanel> panels) {
  return ComicPage(
    id: 'comic#$index',
    index: index,
    imagePath: '/tmp/page$index.png',
    width: 100,
    height: 100,
    panels: panels,
  );
}

void main() {
  group('PanelReader', () {
    test('walks panels within a page, then crosses to the next page', () {
      final pages = [
        pageWith(0, [panelAt(0), panelAt(200)]),
        pageWith(1, [panelAt(0)]),
      ];
      final reader = PanelReader(readPages: () => pages);

      expect(reader.pageIndex, 0);
      expect(reader.panelIndex, 0);
      expect(reader.hasNext, isTrue);

      reader.next();
      expect(reader.panelIndex, 1);

      reader.next();
      expect(reader.pageIndex, 1);
      expect(reader.panelIndex, 0);
      expect(reader.hasNext, isFalse);

      reader.previous();
      expect(reader.pageIndex, 0);
      expect(reader.panelIndex, 1);
    });

    test('goToPage resets the panel index', () {
      final pages = [
        pageWith(0, [panelAt(0), panelAt(200)]),
        pageWith(1, [panelAt(0)]),
      ];
      final reader = PanelReader(readPages: () => pages)..goToPage(1);

      expect(reader.pageIndex, 1);
      expect(reader.panelIndex, 0);
    });

    test('notifyPagesChanged clamps indices when panels disappear', () {
      final pages = [
        pageWith(0, [panelAt(0), panelAt(200)]),
      ];
      final reader = PanelReader(readPages: () => pages)..goToPanel(1);

      pages[0] = pageWith(0, []);
      reader.notifyPagesChanged();

      expect(reader.pageIndex, 0);
      expect(reader.panelIndex, 0);
      expect(reader.currentPanel, isNull);
    });

    test('handles an empty comic', () {
      final reader = PanelReader(readPages: () => const []);

      expect(reader.page, isNull);
      expect(reader.hasNext, isFalse);
      expect(reader.hasPrevious, isFalse);
      expect(reader.next(), isNull);
    });
  });

  group('PanelReader "page + panels" mode', () {
    List<ComicPage> twoPages() => [
      pageWith(0, [panelAt(0), panelAt(200), panelAt(400)]),
      pageWith(1, [panelAt(0), panelAt(200)]),
    ];

    PanelReader reader() => PanelReader(
      readPages: twoPages,
      mode: ReaderMode.pageAndPanels,
    );

    test('starts each page from the whole-page overview', () {
      final subject = reader();

      expect(subject.overview, isTrue);
      expect(subject.showsWholePage, isTrue);
      expect(subject.hasNext, isTrue);
      expect(subject.hasPrevious, isFalse);
    });

    test('advancing leaves the overview and walks the panels', () {
      final subject = reader();

      subject.next();
      expect(subject.overview, isFalse);
      expect(subject.showsWholePage, isFalse);
      expect(subject.panelIndex, 0);

      subject.next();
      expect(subject.panelIndex, 1);

      subject.next();
      expect(subject.panelIndex, 2);
    });

    test('reaching the end of a page shows the next page whole', () {
      final subject = reader();

      subject.next(); // enter panels
      subject.next(); // panel 1
      subject.next(); // panel 2
      subject.next(); // end of page 0 → page 1, overview

      expect(subject.pageIndex, 1);
      expect(subject.overview, isTrue);
      expect(subject.showsWholePage, isTrue);

      subject.next(); // enter page 1 panels
      expect(subject.overview, isFalse);
      expect(subject.panelIndex, 0);
    });

    test('going back to a previous page shows it whole', () {
      final subject = reader();

      subject.next(); // enter panels
      subject.next();
      subject.next();
      subject.next(); // page 1 overview
      subject.next(); // page 1 panel 0

      subject.previous();
      expect(subject.pageIndex, 0);
      expect(subject.overview, isTrue);
      expect(subject.showsWholePage, isTrue);
    });

    test('skips the panel step on single-panel pages', () {
      final pages = [
        pageWith(0, [panelAt(0)]), // one panel = the whole page
        pageWith(1, [panelAt(0), panelAt(200)]),
      ];
      final subject = PanelReader(
        readPages: () => pages,
        mode: ReaderMode.pageAndPanels,
      );

      expect(subject.overview, isTrue);
      expect(subject.hasNext, isTrue);

      // Advancing goes straight to the next page instead of showing the same
      // image twice as "panel 1/1".
      subject.next();

      expect(subject.pageIndex, 1);
      expect(subject.overview, isTrue);
    });

    test('a single-panel last page cannot advance', () {
      final pages = [
        pageWith(0, [panelAt(0), panelAt(200)]),
        pageWith(1, [panelAt(0)]),
      ];
      final subject = PanelReader(
        readPages: () => pages,
        mode: ReaderMode.pageAndPanels,
      );

      subject.next(); // enter page 0 panels
      subject.next(); // panel 2
      subject.next(); // page 1, shown whole (single panel)

      expect(subject.pageIndex, 1);
      expect(subject.overview, isTrue);
      expect(subject.hasNext, isFalse);
      expect(subject.next(), isNull);
    });

    test('cannot advance from the overview while the page is not analysed', () {
      final pages = [pageWith(0, const []), pageWith(1, [panelAt(0)])];
      final subject = PanelReader(
        readPages: () => pages,
        mode: ReaderMode.pageAndPanels,
      );

      expect(subject.hasNext, isFalse);
      expect(subject.next(), isNull);
    });

    test('selecting a panel leaves the overview without changing mode', () {
      final subject = reader();

      subject.goToPanel(2);

      expect(subject.mode, ReaderMode.pageAndPanels);
      expect(subject.overview, isFalse);
      expect(subject.panelIndex, 2);
    });

    test('switching mode resets the overview', () {
      final subject = PanelReader(
        readPages: twoPages,
        mode: ReaderMode.panel,
      );

      subject.mode = ReaderMode.pageAndPanels;
      expect(subject.overview, isTrue);

      subject.next();
      expect(subject.overview, isFalse);

      subject.mode = ReaderMode.panel;
      expect(subject.overview, isFalse);
    });

    test('going back to a page while in the overview stays on the overview', () {
      final subject = reader();

      subject.next(); // page 0 panels
      subject.next();
      subject.next();
      subject.next(); // page 1 overview
      subject.next(); // page 1 panel 0
      subject.previous(); // page 0 overview

      subject.previous(); // no previous page
      expect(subject.pageIndex, 0);
      expect(subject.overview, isTrue);
      expect(subject.hasPrevious, isFalse);
    });
  });

  group('PanelReader page mode', () {
    test('walks pages and ignores panels', () {
      final pages = [
        pageWith(0, [panelAt(0), panelAt(200)]),
        pageWith(1, [panelAt(0)]),
      ];
      final reader = PanelReader(
        readPages: () => pages,
        mode: ReaderMode.page,
      );

      expect(reader.showsWholePage, isTrue);
      expect(reader.hasNext, isTrue);

      reader.next();
      expect(reader.pageIndex, 1);
      expect(reader.hasNext, isFalse);

      reader.previous();
      expect(reader.pageIndex, 0);
      expect(reader.hasPrevious, isFalse);
    });
  });
}
