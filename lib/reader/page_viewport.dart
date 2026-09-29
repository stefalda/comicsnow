import 'package:flutter/material.dart';

import '../domain/comic_panel.dart';
import 'image_readiness.dart';
import 'page_loading_indicator.dart';
import 'panel_viewport.dart';

/// Shows a whole page, with the detected panels drawn on top.
///
/// Used by "page mode" and as the manual-correction surface: tapping a panel
/// selects it, tapping empty space selects nothing.
class PageViewport extends StatefulWidget {
  const PageViewport({
    super.key,
    required this.image,
    required this.imageSize,
    this.controller,
    this.panels = const [],
    this.activeIndex,
    this.onPanelTap,
    this.showOrderBadges = true,
    this.loadingLabel,
  });

  final ImageProvider image;
  final Size imageSize;

  /// Optional external controller, so the parent can inspect/pan the view.
  /// When omitted the widget owns one.
  final TransformationController? controller;

  final List<ComicPanel> panels;
  final int? activeIndex;
  final ValueChanged<int>? onPanelTap;
  final bool showOrderBadges;

  /// Shown under the loading indicator, e.g. `Pagina 12`.
  final String? loadingLabel;

  @override
  State<PageViewport> createState() => _PageViewportState();
}

class _PageViewportState extends State<PageViewport>
    with ImageReadinessMixin<PageViewport> {
  late final TransformationController _internal = TransformationController();

  TransformationController get _controller => widget.controller ?? _internal;

  @override
  ImageProvider get readinessImage => widget.image;

  @override
  void didUpdateWidget(PageViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _controller.value = Matrix4.identity();
      resetImageReadiness();
    }
  }

  @override
  void dispose() {
    _internal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The panel frames are painted only once the page itself has decoded:
    // showing them first makes the layout appear over an empty page.
    if (!imageReady) {
      return Center(
        child: PageLoadingIndicator(label: widget.loadingLabel),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 6,
          child: SizedBox(
            width: viewportSize.width,
            height: viewportSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: widget.image,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
                for (var index = 0; index < widget.panels.length; index++)
                  _buildPanel(
                    viewportSize: viewportSize,
                    index: index,
                    panel: widget.panels[index],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel({
    required Size viewportSize,
    required int index,
    required ComicPanel panel,
  }) {
    final rect = panelRectInViewport(
      viewport: viewportSize,
      image: widget.imageSize,
      panel: panel.bounds,
    );

    final isActive = widget.activeIndex == index;

    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPanelTap == null
            ? null
            : () => widget.onPanelTap!(index),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white24,
              width: isActive ? 3 : 1.5,
            ),
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: widget.showOrderBadges
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _OrderBadge(
                      order: panel.order + 1,
                      isActive: isActive,
                      manual: panel.isManual,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({
    required this.order,
    required this.isActive,
    required this.manual,
  });

  final int order;
  final bool isActive;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? scheme.primary : Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$order',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (manual) ...[
            const SizedBox(width: 3),
            const Icon(Icons.edit, size: 10, color: Colors.white),
          ],
        ],
      ),
    );
  }
}
