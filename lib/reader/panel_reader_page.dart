import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../comic/image_loader.dart';
import '../comic/page_repository.dart';
import '../detection/panel_analysis_queue.dart';
import '../detection/panel_ordering.dart';
import '../domain/comic_page.dart';
import '../domain/comic_panel.dart';
import 'magnifier_lens.dart';
import 'page_loading_indicator.dart';
import 'page_viewport.dart';
import 'panel_reader.dart';
import 'panel_viewport.dart';
import 'reader_preferences.dart';

extension ReaderModeUi on ReaderMode {
  String get label => switch (this) {
    ReaderMode.page => 'Pagina',
    ReaderMode.panel => 'Vignette',
    ReaderMode.pageAndPanels => 'Pagina + vignette',
  };

  IconData get icon => switch (this) {
    ReaderMode.page => Icons.grid_view,
    ReaderMode.panel => Icons.crop_free,
    ReaderMode.pageAndPanels => Icons.auto_stories,
  };
}

/// The main reader screen.
///
/// It wires the pure [PanelReader] controller to the two viewports and drives
/// the [PanelAnalysisQueue] so that the next pages are analysed ahead of time.
class PanelReaderPage extends StatefulWidget {
  const PanelReaderPage({
    super.key,
    required this.repository,
    required this.queue,
    required this.imageLoader,
    this.direction = ReadingDirection.leftToRight,
    this.initialPageIndex = 0,
    this.initialMode = ReaderMode.pageAndPanels,
    this.initialPreferences = ReaderPreferences.defaults,
    this.onModeChanged,
    this.onPageChanged,
    this.onPreferencesChanged,
  });

  final PageRepository repository;
  final PanelAnalysisQueue queue;
  final ImageLoader imageLoader;
  final ReadingDirection direction;
  final int initialPageIndex;
  final ReaderMode initialMode;

  /// Called when the reader switches mode, so it can be persisted.
  final ValueChanged<ReaderMode>? onModeChanged;

  /// Called when the current page changes, so the position can be persisted.
  final ValueChanged<int>? onPageChanged;

  /// Animation / comfort options.
  final ReaderPreferences initialPreferences;

  /// Called when the comfort options change, so they can be persisted.
  final ValueChanged<ReaderPreferences>? onPreferencesChanged;

  @override
  State<PanelReaderPage> createState() => _PanelReaderPageState();
}

class _PanelReaderPageState extends State<PanelReaderPage> {
  static const _prefetchDepth = 2;

  late final PanelReader _reader;
  final _panelController = TransformationController();
  final _pageController = TransformationController();
  final _failedPages = <String>{};

  /// Pages whose image has already been pushed into Flutter's image cache.
  final _precachedPages = <String>{};

  StreamSubscription<PageAnalysis>? _resultSubscription;
  StreamSubscription<PageAnalysisFailure>? _failureSubscription;

  Offset? _pointerDown;
  bool _trackingSwipe = false;

  /// Page currently selected on the scrubber, while the user is dragging.
  int? _scrubPage;

  /// Last page reported through [PanelReaderPage.onPageChanged].
  int _reportedPage = -1;

  /// Whether the page scrubber is shown. It is hidden by default and opened on
  /// request, so it does not take space while reading.
  bool _showScrubber = false;

  /// Point magnified by the loupe, in body coordinates; `null` when idle.
  Offset? _magnifierFocal;

  /// Set while a long press is being used for the loupe, so that lifting the
  /// finger is not mistaken for a swipe.
  bool _magnifierUsed = false;

  /// Animation / comfort options currently in use.
  late ReaderPreferences _preferences = widget.initialPreferences;

  @override
  void initState() {
    super.initState();
    _reader = PanelReader(
      readPages: () => widget.repository.pages,
      mode: widget.initialMode,
    )..goToPage(widget.initialPageIndex);

    _resultSubscription = widget.queue.results.listen(_onAnalysis);
    _failureSubscription = widget.queue.failures.listen(_onFailure);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCurrentPage();
      _reportPosition();
    });
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _failureSubscription?.cancel();
    _panelController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Analysis orchestration
  // ---------------------------------------------------------------------------

  void _onAnalysis(PageAnalysis analysis) {
    final page = widget.repository.pageById(analysis.pageId);
    if (page == null) return;

    final panels = analysis.panels.isEmpty
        ? [ComicPanel.fullPage(page.size)]
        : analysis.panels;

    widget.repository.updatePanels(analysis.pageId, panels);
    _failedPages.remove(analysis.pageId);

    if (!mounted) return;
    setState(_reader.notifyPagesChanged);
  }

  void _onFailure(PageAnalysisFailure failure) {
    final page = widget.repository.pageById(failure.pageId);
    if (page == null) return;

    _failedPages.add(failure.pageId);
    widget.repository.updatePanels(failure.pageId, [
      ComicPanel.fullPage(page.size),
    ]);

    if (!mounted) return;
    setState(_reader.notifyPagesChanged);
  }

  /// Makes sure the current page has panels, then warms up the next ones.
  void _ensureCurrentPage() {
    final page = _reader.page;
    if (page == null) return;

    _precacheCurrentImage(page);

    if (page.panels.isEmpty) {
      if (_failedPages.contains(page.id)) {
        widget.repository.updatePanels(page.id, [
          ComicPanel.fullPage(page.size),
        ]);
        setState(_reader.notifyPagesChanged);
      } else {
        widget.queue.request(page, priority: 100);
      }
    }

    _prefetch(_reader.pageIndex);
  }

  /// Decodes the current page image ahead of time.
  ///
  /// The viewports hide the page until its first frame is ready, so starting
  /// the decode as soon as the page is known keeps that wait short.
  void _precacheCurrentImage(ComicPage page) {
    if (!_precachedPages.add(page.id)) return;
    unawaited(precacheImage(widget.imageLoader.provider(page), context));
  }

  void _prefetch(int fromIndex) {
    final pages = widget.repository.pages;
    for (var offset = 1; offset <= _prefetchDepth; offset++) {
      final index = fromIndex + offset;
      if (index >= pages.length) break;
      widget.queue.request(pages[index], priority: 100 - offset * 20);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _advanceForward() {
    if (!_reader.hasNext) return;
    _reader.next();
    setState(() {});
    _ensureCurrentPage();
    _reportPosition();
  }

  void _advanceBackward() {
    if (!_reader.hasPrevious) return;
    _reader.previous();
    setState(() {});
    _ensureCurrentPage();
    _reportPosition();
  }

  /// Persists the current page when it changed, without spamming writes.
  void _reportPosition() {
    final index = _reader.pageIndex;
    if (index == _reportedPage) return;
    _reportedPage = index;
    widget.onPageChanged?.call(index);
  }

  void _commitScrub(int index) {
    setState(() {
      _reader.goToPage(index);
      _scrubPage = null;
    });
    _ensureCurrentPage();
    _reportPosition();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
    _magnifierUsed = false;
    // Only navigate by swipe when the view is not zoomed in; otherwise the
    // gesture is a pan and belongs to InteractiveViewer.
    final controller = _reader.showsWholePage
        ? _pageController
        : _panelController;
    _trackingSwipe = controller.value.getMaxScaleOnAxis() <= 1.02;
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _pointerDown;
    final tracking = _trackingSwipe;
    final usedMagnifier = _magnifierUsed;
    _pointerDown = null;
    _trackingSwipe = false;
    _magnifierUsed = false;

    // A long press that opened the loupe is not a navigation gesture.
    if (!tracking || start == null || usedMagnifier) return;

    final delta = event.position - start;
    if (delta.dx.abs() < 48 || delta.dx.abs() < delta.dy.abs()) return;

    final swipedForward = widget.direction == ReadingDirection.leftToRight
        ? delta.dx < 0
        : delta.dx > 0;

    if (swipedForward) {
      _advanceForward();
    } else {
      _advanceBackward();
    }
  }

  /// Long press on the page opens a loupe that follows the finger.
  void _startMagnifier(Offset focalPoint) {
    _magnifierUsed = true;
    setState(() => _magnifierFocal = focalPoint);
  }

  void _moveMagnifier(Offset focalPoint) {
    if (_magnifierFocal == null) return;
    setState(() => _magnifierFocal = focalPoint);
  }

  void _stopMagnifier() {
    if (_magnifierFocal == null) return;
    setState(() => _magnifierFocal = null);
  }

  void _onTapUp(TapUpDetails details, double width) {
    final x = details.localPosition.dx;
    if (x > width * 0.62) {
      _advanceForward();
    } else if (x < width * 0.38) {
      _advanceBackward();
    }
  }

  void _setMode(ReaderMode mode) {
    if (_reader.mode == mode) return;
    setState(() => _reader.mode = mode);
    widget.onModeChanged?.call(mode);
    _ensureCurrentPage();
  }

  void _reanalyzeCurrentPage() {
    final page = _reader.page;
    if (page == null) return;
    _failedPages.remove(page.id);
    widget.queue.refresh(page);
    setState(() {});
  }

  Future<void> _openPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      showDragHandle: true,
      builder: (context) => _PreferencesSheet(
        initial: _preferences,
        onPreview: (preferences) =>
            setState(() => _preferences = preferences),
      ),
    );
    // Persist whatever ended up applied.
    widget.onPreferencesChanged?.call(_preferences);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Keyboard navigation, so on desktop the arrow keys behave like the on-screen
  /// chevrons.
  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowRight): _advanceForward,
    const SingleActivator(LogicalKeyboardKey.arrowDown): _advanceForward,
    const SingleActivator(LogicalKeyboardKey.pageDown): _advanceForward,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): _advanceBackward,
    const SingleActivator(LogicalKeyboardKey.arrowUp): _advanceBackward,
    const SingleActivator(LogicalKeyboardKey.pageUp): _advanceBackward,
  };

  void _toggleScrubber() {
    setState(() {
      _showScrubber = !_showScrubber;
      if (!_showScrubber) _scrubPage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.repository.pages;
    final page = _reader.page;

    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              widget.repository.comic.title,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Comfort di lettura',
                onPressed: _openPreferences,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: 'Rileva di nuovo',
                onPressed: page == null ? null : _reanalyzeCurrentPage,
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<ReaderMode>(
                tooltip: 'Modalità: ${_reader.mode.label}',
                initialValue: _reader.mode,
                onSelected: _setMode,
                icon: Icon(_reader.mode.icon),
                itemBuilder: (context) => [
                  for (final mode in ReaderMode.values)
                    PopupMenuItem<ReaderMode>(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(mode.icon, size: 18),
                          const SizedBox(width: 12),
                          Text(mode.label),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: pages.isEmpty
              ? const _CenteredMessage('Nessuna pagina trovata')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            onPointerDown: _onPointerDown,
                            onPointerUp: _onPointerUp,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (details) =>
                                  _onTapUp(details, constraints.maxWidth),
                              onLongPressStart: (details) =>
                                  _startMagnifier(details.localPosition),
                              onLongPressMoveUpdate: (details) =>
                                  _moveMagnifier(details.localPosition),
                              onLongPressEnd: (details) => _stopMagnifier(),
                              onLongPressCancel: _stopMagnifier,
                              child: _buildViewport(),
                            ),
                          ),
                        ),
                        // The loupe follows the finger: it magnifies the page
                        // (and the panel frames) painted below it in this Stack.
                        if (_magnifierFocal != null)
                          MagnifierLens(
                            focalPoint: _magnifierFocal!,
                            viewportSize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          ),
                        // The preview floats above the page instead of
                        // resizing it.
                        if (_scrubPage != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 16,
                            child: IgnorePointer(
                              child: Center(
                                child: _buildScrubPreview(
                                  _scrubPage!,
                                  constraints,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
          bottomNavigationBar:
              pages.isEmpty || page == null ? null : _buildBottomBar(),
        ),
      ),
    );
  }

  Widget _buildViewport() {
    final currentPage = _reader.page;
    if (currentPage == null) {
      return const _CenteredMessage('Nessuna pagina');
    }

    final image = widget.imageLoader.provider(currentPage);

    if (!_reader.showsWholePage) {
      final panel = _reader.currentPanel;
      if (panel == null) {
        final failed = _failedPages.contains(currentPage.id);
        return _LoadingPanels(failed: failed, onRetry: _reanalyzeCurrentPage);
      }

      return PanelViewport(
        image: image,
        imageSize: currentPage.size,
        panel: panel.bounds,
        controller: _panelController,
        transition: _preferences.transition,
        animationDuration: _preferences.animationDuration,
        maxScale: _preferences.maxZoom,
        loadingLabel: 'Pagina ${_reader.pageIndex + 1}',
      );
    }

    // With a single panel the whole page already *is* the panel, so tapping it
    // must not enter panel view: taps fall through to page navigation.
    final canSelectPanel = currentPage.panels.length > 1;

    return PageViewport(
      image: image,
      imageSize: currentPage.size,
      controller: _pageController,
      panels: currentPage.panels,
      activeIndex: _reader.panelIndex,
      loadingLabel: 'Pagina ${_reader.pageIndex + 1}',
      onPanelTap: !canSelectPanel
          ? null
          : (index) {
              setState(() {
                _reader.goToPanel(index);
                // In plain page mode there is no panel navigation to fall back
                // to, so tapping a panel switches mode. In "page + panels" the
                // tap just leaves the overview, staying in the same mode.
                if (_reader.mode == ReaderMode.page) {
                  _reader.mode = ReaderMode.panel;
                }
              });
            },
    );
  }

  Widget _buildBottomBar() {
    final pages = widget.repository.pages;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrubber) _buildPageSlider(pages.length),
          _buildStatusRow(pages.length),
        ],
      ),
    );
  }

  /// A large thumbnail of the page under the scrubber, floating above the page
  /// so the underlying layout does not move.
  Widget _buildScrubPreview(int index, BoxConstraints constraints) {
    final pages = widget.repository.pages;
    final page = pages[index];

    final height = math.min(constraints.maxHeight * 0.62, 720.0);
    final width = math.min(constraints.maxWidth * 0.82, height * 0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 24),
            ],
          ),
          child: SizedBox(
            height: height,
            width: width,
            child: Image(
              // Bigger preview → bigger decode than the old thumbnail.
              image: ResizeImage(
                widget.imageLoader.provider(page),
                width: 720,
              ),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Pagina ${index + 1}/${pages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageSlider(int pageCount) {
    final current = (_scrubPage ?? _reader.pageIndex).clamp(0, pageCount - 1);
    final enabled = pageCount > 1;

    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.white70,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          overlayColor: Colors.white24,
          valueIndicatorColor: Colors.white,
          valueIndicatorTextStyle: const TextStyle(color: Colors.black),
        ),
        child: Slider(
          min: 0,
          max: (pageCount - 1).toDouble(),
          divisions: enabled ? pageCount - 1 : null,
          value: current.toDouble(),
          label: 'Pagina ${current + 1}',
          onChanged: enabled
              ? (value) => setState(() => _scrubPage = value.round())
              : null,
          onChangeEnd: enabled
              ? (value) => _commitScrub(value.round())
              : null,
        ),
      ),
    );
  }

  Widget _buildStatusRow(int pageCount) {
    final panelCount = _reader.panels.length;
    final panelIndex = panelCount == 0 ? 0 : _reader.panelIndex + 1;

    final String position;
    if (_reader.showsWholePage) {
      position = _reader.overview && panelCount > 1
          ? 'Pagina intera · avanza per le vignette'
          : 'Pagina intera';
    } else if (panelCount == 0) {
      position = 'Analisi…';
    } else {
      position = 'Vignetta $panelIndex/$panelCount';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            'Pagina ${_reader.pageIndex + 1}/$pageCount',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              position,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: _showScrubber
                ? 'Nascondi lo scorrimento pagine'
                : 'Scorri le pagine',
            onPressed: pageCount > 1 ? _toggleScrubber : null,
            icon: Icon(
              _showScrubber ? Icons.unfold_less : Icons.unfold_more,
            ),
            color: _showScrubber ? Colors.white : Colors.white70,
            disabledColor: Colors.white24,
          ),
          IconButton(
            onPressed: _reader.hasPrevious ? _advanceBackward : null,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          IconButton(
            onPressed: _reader.hasNext ? _advanceForward : null,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _LoadingPanels extends StatelessWidget {
  const _LoadingPanels({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failed)
            const Icon(Icons.error_outline, color: Colors.white54, size: 40)
          else
            const PageLoadingIndicator(size: 72),
          const SizedBox(height: 16),
          Text(
            failed
                ? 'Rilevamento non disponibile'
                : 'Rilevamento delle vignette…',
            style: const TextStyle(color: Colors.white70),
          ),
          if (failed) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet with the animation / comfort options.
///
/// Applies changes live through [onPreview] so the reader behind it shows the
/// effect immediately; the caller persists the final value when the sheet
/// closes.
class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial, required this.onPreview});

  final ReaderPreferences initial;
  final ValueChanged<ReaderPreferences> onPreview;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late ReaderPreferences _draft = widget.initial;

  void _update(ReaderPreferences next) {
    setState(() => _draft = next);
    widget.onPreview(next);
  }

  static String _label(PanelTransition transition) => switch (transition) {
    PanelTransition.zoom => 'Zoom',
    PanelTransition.fade => 'Dissolvenza',
    PanelTransition.none => 'Nessuna',
  };

  @override
  Widget build(BuildContext context) {
    final durationMs = _draft.animationDuration.inMilliseconds
        .clamp(80, 400)
        .toDouble();
    final maxZoom = _draft.maxZoom.clamp(2.0, 6.0).toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comfort di lettura',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Transizione tra vignette'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in PanelTransition.values)
                  ChoiceChip(
                    label: Text(_label(option)),
                    selected: _draft.transition == option,
                    onSelected: (_) =>
                        _update(_draft.copyWith(transition: option)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Velocità animazione · ${durationMs.round()} ms'),
            Slider(
              min: 80,
              max: 400,
              divisions: 16,
              value: durationMs,
              label: '${durationMs.round()} ms',
              onChanged: (value) => _update(
                _draft.copyWith(
                  animationDuration: Duration(milliseconds: value.round()),
                ),
              ),
            ),
            Text('Zoom massimo · ${maxZoom.toStringAsFixed(1)}×'),
            Slider(
              min: 2,
              max: 6,
              divisions: 8,
              value: maxZoom,
              label: '${maxZoom.toStringAsFixed(1)}×',
              onChanged: (value) =>
                  _update(_draft.copyWith(maxZoom: value)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Suggerimento: tieni premuto su una pagina per ingrandirla con la '
              'lente e sposta il dito per esplorarla.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'Con "Riduci movimento" attivo nel sistema, l\'animazione è '
              'disattivata a prescindere.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
