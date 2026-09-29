import '../domain/comic.dart';
import '../domain/comic_page.dart';
import '../domain/comic_panel.dart';

/// In-memory store for the currently open comic.
///
/// Panels are filled in asynchronously by the analysis queue, so the repository
/// is mutable while the underlying [Comic] / [ComicPage] objects stay
/// immutable.
class PageRepository {
  PageRepository(this._comic);

  Comic _comic;

  Comic get comic => _comic;

  List<ComicPage> get pages => _comic.pages;

  int get length => _comic.pages.length;

  bool get isEmpty => _comic.pages.isEmpty;

  ComicPage? pageAt(int index) {
    if (index < 0 || index >= _comic.pages.length) {
      return null;
    }
    return _comic.pages[index];
  }

  ComicPage? pageById(String pageId) {
    for (final page in _comic.pages) {
      if (page.id == pageId) return page;
    }
    return null;
  }

  /// Replaces the panels of a page.
  void updatePanels(String pageId, List<ComicPanel> panels) {
    final index = _comic.pages.indexWhere((page) => page.id == pageId);
    if (index < 0) return;

    final updated = [..._comic.pages];
    updated[index] = updated[index].copyWith(panels: panels);
    _comic = _comic.copyWith(pages: updated);
  }

  /// Adds or edits a single panel and re-numbers the page.
  ///
  /// Only the touched panel is flagged as manual; the others keep their flags.
  void upsertPanel(String pageId, ComicPanel panel) {
    final page = pageById(pageId);
    if (page == null) return;

    final panels = [...page.panels];
    if (panel.id != null) {
      final index = panels.indexWhere((candidate) => candidate.id == panel.id);
      if (index >= 0) {
        panels[index] = panel.copyWith(isManual: true);
      } else {
        panels.add(panel.copyWith(isManual: true));
      }
    } else {
      panels.add(panel.copyWith(isManual: true));
    }

    updatePanels(pageId, [
      for (var i = 0; i < panels.length; i++) panels[i].copyWith(order: i),
    ]);
  }

  /// Removes a panel by id and re-numbers the page.
  void removePanel(String pageId, String panelId) {
    final page = pageById(pageId);
    if (page == null) return;

    final panels = page.panels.where((panel) => panel.id != panelId).toList();

    updatePanels(pageId, [
      for (var i = 0; i < panels.length; i++) panels[i].copyWith(order: i),
    ]);
  }
}
