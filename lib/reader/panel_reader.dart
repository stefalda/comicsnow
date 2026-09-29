import '../domain/comic_page.dart';
import '../domain/comic_panel.dart';

/// How the reader walks through a comic.
enum ReaderMode {
  /// The whole page, one page at a time.
  page,

  /// One panel at a time, crossing page boundaries.
  panel,

  /// Shows the whole page whenever the page changes, then enters panel
  /// navigation for that page as soon as the reader advances.
  pageAndPanels,
}

/// Pure, Flutter-free controller that walks a comic panel by panel.
///
/// It does not know anything about widgets, gestures or persistence. The list
/// of pages is read through [readPages] so that the controller sees panels as
/// soon as the analysis queue fills them in.
class PanelReader {
  PanelReader({
    required this.readPages,
    ReaderMode mode = ReaderMode.panel,
  }) : _mode = mode {
    _overview = mode == ReaderMode.pageAndPanels;
  }

  final List<ComicPage> Function() readPages;

  ReaderMode _mode;
  late bool _overview;
  int _pageIndex = 0;
  int _panelIndex = 0;

  ReaderMode get mode => _mode;

  /// Changing mode re-initialises the sub-state: entering [ReaderMode.pageAndPanels]
  /// always starts from the page overview.
  set mode(ReaderMode value) {
    if (_mode == value) return;
    _mode = value;
    _overview = value == ReaderMode.pageAndPanels;
    if (_overview) {
      _panelIndex = 0;
    }
  }

  /// `true` while the whole page is shown in [ReaderMode.pageAndPanels].
  bool get overview => _mode == ReaderMode.pageAndPanels && _overview;

  /// Whether the current view is the whole page rather than a single panel.
  bool get showsWholePage => _mode == ReaderMode.page || overview;

  List<ComicPage> get pages => readPages();

  int get pageIndex => _pageIndex;

  int get panelIndex => _panelIndex;

  ComicPage? get page {
    final all = pages;
    if (all.isEmpty) return null;
    return all[_pageIndex.clamp(0, all.length - 1)];
  }

  List<ComicPanel> get panels => page?.panels ?? const [];

  ComicPanel? get currentPanel {
    final current = panels;
    if (_panelIndex < 0 || _panelIndex >= current.length) {
      return null;
    }
    return current[_panelIndex];
  }

  bool get hasNext {
    final all = pages;
    if (all.isEmpty) return false;

    switch (_mode) {
      case ReaderMode.page:
        return _pageIndex < all.length - 1;
      case ReaderMode.panel:
        return _panelIndex < panels.length - 1 || _pageIndex < all.length - 1;
      case ReaderMode.pageAndPanels:
        if (_overview) {
          // Nothing to do until the page has been analysed.
          if (panels.isEmpty) return false;
          // A single-panel page is already shown in full by the overview, so
          // advancing goes straight to the next page instead of showing the
          // same image twice.
          if (panels.length == 1) return _pageIndex < all.length - 1;
          return true;
        }
        return _panelIndex < panels.length - 1 || _pageIndex < all.length - 1;
    }
  }

  bool get hasPrevious {
    switch (_mode) {
      case ReaderMode.page:
        return _pageIndex > 0;
      case ReaderMode.panel:
        return _panelIndex > 0 || _pageIndex > 0;
      case ReaderMode.pageAndPanels:
        if (_overview) return _pageIndex > 0;
        return _panelIndex > 0 || _pageIndex > 0;
    }
  }

  /// Advances one step according to [mode], crossing page boundaries.
  ComicPanel? next() {
    if (!hasNext) return null;

    switch (_mode) {
      case ReaderMode.page:
        _pageIndex++;
      case ReaderMode.panel:
        _stepForward();
      case ReaderMode.pageAndPanels:
        if (_overview) {
          if (panels.length == 1) {
            // Skip the panel step: the overview already showed this page.
            _pageIndex++;
            _overview = true;
          } else {
            _overview = false;
            _panelIndex = 0;
          }
        } else {
          _stepForward();
        }
    }

    return currentPanel;
  }

  /// Steps back one step according to [mode], crossing page boundaries.
  ComicPanel? previous() {
    if (!hasPrevious) return null;

    switch (_mode) {
      case ReaderMode.page:
        _pageIndex--;
      case ReaderMode.panel:
        _stepBackward();
      case ReaderMode.pageAndPanels:
        if (_overview) {
          // A page change always shows the whole page, also when going back.
          _pageIndex--;
          _overview = true;
        } else if (_panelIndex > 0) {
          _panelIndex--;
        } else {
          _pageIndex--;
          _overview = true;
        }
    }

    return currentPanel;
  }

  void _stepForward() {
    if (_panelIndex < panels.length - 1) {
      _panelIndex++;
      return;
    }

    final all = pages;
    if (_pageIndex < all.length - 1) {
      _pageIndex++;
      _panelIndex = 0;
      if (_mode == ReaderMode.pageAndPanels) {
        // Entering a new page shows it whole first.
        _overview = true;
      }
    }
  }

  void _stepBackward() {
    if (_panelIndex > 0) {
      _panelIndex--;
      return;
    }

    if (_pageIndex > 0) {
      _pageIndex--;
      final previousPanels = panels;
      _panelIndex = previousPanels.isEmpty ? 0 : previousPanels.length - 1;
    }
  }

  /// Jumps to the first panel of [index].
  ///
  /// In [ReaderMode.pageAndPanels] this shows the page overview, because a page
  /// change always starts from the whole page.
  void goToPage(int index) {
    final all = pages;
    if (all.isEmpty) {
      _pageIndex = 0;
      _panelIndex = 0;
      _overview = _mode == ReaderMode.pageAndPanels;
      return;
    }

    _pageIndex = index.clamp(0, all.length - 1);
    _panelIndex = 0;
    if (_mode == ReaderMode.pageAndPanels) {
      _overview = true;
    }
  }

  /// Jumps to a specific panel of the current page, leaving the overview.
  void goToPanel(int index) {
    _panelIndex = index.clamp(0, panels.isEmpty ? 0 : panels.length - 1);
    _overview = false;
  }

  /// Re-clamps indices after the page list changed (panels added/removed).
  void notifyPagesChanged() {
    final all = pages;
    if (all.isEmpty) {
      _pageIndex = 0;
      _panelIndex = 0;
      return;
    }

    _pageIndex = _pageIndex.clamp(0, all.length - 1);

    final count = panels.length;
    if (count == 0) {
      _panelIndex = 0;
    } else {
      _panelIndex = _panelIndex.clamp(0, count - 1);
    }
  }

  @override
  String toString() =>
      'PanelReader(mode=$_mode, page=$_pageIndex/$_panelIndex, '
      'overview=$_overview, pages=${pages.length})';
}
