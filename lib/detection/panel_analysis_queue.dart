import 'dart:async';

import '../domain/comic_page.dart';
import '../domain/comic_panel.dart';
import 'panel_analysis_service.dart';

/// Emitted by [PanelAnalysisQueue] when a page has been analysed.
class PageAnalysis {
  const PageAnalysis({required this.pageId, required this.panels});

  final String pageId;
  final List<ComicPanel> panels;
}

/// Emitted by [PanelAnalysisQueue] when analysing a page failed.
class PageAnalysisFailure {
  const PageAnalysisFailure({
    required this.pageId,
    required this.error,
    required this.stackTrace,
  });

  final String pageId;
  final Object error;
  final StackTrace stackTrace;
}

/// A small priority queue that analyses pages ahead of time.
///
/// The reader enqueues the current page with the highest priority and the next
/// couple of pages with decreasing priorities, so that turning a page is
/// usually instant:
///
/// ```text
/// page 10 → priority 100
/// page 11 → priority  80
/// page 12 → priority  60
/// page 13 → priority  40
/// ```
class PanelAnalysisQueue {
  PanelAnalysisQueue({
    required this.analyzer,
    this.maxConcurrent = 1,
    this.onError,
  });

  final PanelAnalysisService analyzer;
  final int maxConcurrent;

  /// Invoked when analysis of a page fails. Receives the page id and error.
  final void Function(String pageId, Object error, StackTrace stackTrace)?
  onError;

  final _controller = StreamController<PageAnalysis>.broadcast();
  final _errorController = StreamController<PageAnalysisFailure>.broadcast();

  /// In-memory results, so a completed page is never analysed twice in a
  /// session even if it is evicted from the database.
  final _completed = <String, List<ComicPanel>>{};

  /// Pages that should bypass the cache on their next run.
  final _forceRefresh = <String>{};

  /// Pending pages, kept sorted by descending priority.
  final _pending = <ComicPage>[];
  final _priority = <String, int>{};
  final _running = <String>{};

  int _active = 0;
  bool _disposed = false;
  bool _drainScheduled = false;

  /// Broadcast stream of finished analyses.
  Stream<PageAnalysis> get results => _controller.stream;

  /// Broadcast stream of failed analyses.
  Stream<PageAnalysisFailure> get failures => _errorController.stream;

  /// A synchronous snapshot of results known so far.
  List<ComicPanel>? panelsFor(String pageId) => _completed[pageId];

  /// Enqueues [page]. Higher [priority] values run first.
  void request(ComicPage page, {int priority = 0}) {
    if (_disposed) return;

    final id = page.id;

    final known = _completed[id];
    if (known != null) {
      _emit(id, known);
      return;
    }

    if (_running.contains(id)) {
      return;
    }

    final previous = _priority[id];
    if (previous != null) {
      if (previous >= priority) return;
      _pending.removeWhere((candidate) => candidate.id == id);
    }

    _priority[id] = priority;
    _pending.add(page);
    _pending.sort(
      (a, b) => (_priority[b.id] ?? 0).compareTo(_priority[a.id] ?? 0),
    );

    _scheduleDrain();
  }

  /// Drops any cached result for [page] and re-runs detection.
  void refresh(ComicPage page) {
    if (_disposed) return;
    _completed.remove(page.id);
    _priority.remove(page.id);
    _pending.removeWhere((candidate) => candidate.id == page.id);
    _forceRefresh.add(page.id);
    request(page, priority: 1000);
  }

  /// Defers draining to a microtask so a synchronous burst of [request]s is
  /// sorted by priority before any page starts.
  void _scheduleDrain() {
    if (_drainScheduled || _disposed) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      _drain();
    });
  }

  void _drain() {
    while (!_disposed && _active < maxConcurrent && _pending.isNotEmpty) {
      final page = _pending.removeAt(0);
      final id = page.id;
      _priority.remove(id);
      _running.add(id);
      _active++;

      final forced = _forceRefresh.remove(id);
      final run = forced ? analyzer.reanalyze(page) : analyzer.analyze(page);

      run
          .then((panels) {
            if (_disposed) return;
            _completed[id] = panels;
            _emit(id, panels);
          })
          .catchError((Object error, StackTrace stackTrace) {
            onError?.call(id, error, stackTrace);
            _emitFailure(id, error, stackTrace);
          })
          .whenComplete(() {
            _running.remove(id);
            _active--;
            _scheduleDrain();
          });
    }
  }

  void _emit(String pageId, List<ComicPanel> panels) {
    if (_disposed || _controller.isClosed) return;
    _controller.add(PageAnalysis(pageId: pageId, panels: panels));
  }

  void _emitFailure(String pageId, Object error, StackTrace stackTrace) {
    if (_disposed || _errorController.isClosed) return;
    _errorController.add(
      PageAnalysisFailure(
        pageId: pageId,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    _priority.clear();
    _forceRefresh.clear();
    await _controller.close();
    await _errorController.close();
  }
}
