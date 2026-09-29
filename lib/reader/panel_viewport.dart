import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_path.dart';
import 'image_readiness.dart';
import 'page_loading_indicator.dart';
import 'reader_preferences.dart';

/// Where an image drawn with [BoxFit.contain] actually lands inside [viewport].
Rect containedImageRect(Size viewport, Size image) {
  if (viewport.isEmpty || image.isEmpty) {
    return Offset.zero & viewport;
  }

  final fitted = applyBoxFit(BoxFit.contain, image, viewport);
  final destination = fitted.destination;
  final left = (viewport.width - destination.width) / 2;
  final top = (viewport.height - destination.height) / 2;

  return Rect.fromLTWH(left, top, destination.width, destination.height);
}

/// Maps a [panel] expressed in original image pixels to the coordinate space
/// of a `BoxFit.contain` image laid out inside [viewport].
Rect panelRectInViewport({
  required Size viewport,
  required Size image,
  required Rect panel,
}) {
  final destination = containedImageRect(viewport, image);
  if (destination.isEmpty || image.width <= 0 || image.height <= 0) {
    return Rect.zero;
  }

  final scale = destination.width / image.width;

  return Rect.fromLTWH(
    destination.left + panel.left * scale,
    destination.top + panel.top * scale,
    panel.width * scale,
    panel.height * scale,
  );
}

/// Builds the [Matrix4] that zooms a `BoxFit.contain` page image onto [panel].
///
/// The transformation maps child coordinates (the `InteractiveViewer` child,
/// which is viewport-sized) to viewport coordinates.
Matrix4 panelTransformation({
  required Size viewportSize,
  required Size imageSize,
  required Rect panel,
  double padding = 0.94,
  double minScale = 1,
  double maxScale = 3.5,
}) {
  final panelInViewport = panelRectInViewport(
    viewport: viewportSize,
    image: imageSize,
    panel: panel,
  );

  if (panelInViewport.width <= 0 || panelInViewport.height <= 0) {
    return Matrix4.identity();
  }

  final rawScale = math.min(
        viewportSize.width / panelInViewport.width,
        viewportSize.height / panelInViewport.height,
      ) *
      padding;

  final scale = rawScale.clamp(minScale, maxScale);

  final viewportCenter = Offset(
    viewportSize.width / 2,
    viewportSize.height / 2,
  );
  final panelCenter = panelInViewport.center;

  final translation = viewportCenter -
      Offset(panelCenter.dx * scale, panelCenter.dy * scale);

  return Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    ..scaleByDouble(scale, scale, scale, 1);
}

/// Shows a page image zoomed on a single panel.
///
/// Uses [InteractiveViewer] because the transformation must be driven
/// programmatically (panel to panel) while still allowing manual pan/zoom.
///
/// Comfort notes (motion sickness):
///
/// * the camera path is interpolated by [CameraView] (logarithmic zoom, linear
///   focal point) instead of blending raw matrices, so the zoom rate is
///   perceptually constant and the aim point does not drift;
/// * the content animates inside a **static frame** ([frameInset]): the screen
///   edges never move, which cuts the peripheral optic flow that triggers
///   nausea;
/// * [PanelTransition.fade] and [PanelTransition.none] avoid motion entirely;
/// * the system "reduce motion" setting is honoured.
class PanelViewport extends StatefulWidget {
  const PanelViewport({
    super.key,
    required this.image,
    required this.imageSize,
    required this.panel,
    this.controller,
    this.padding = 0.94,
    this.minScale = 1,
    this.maxScale = 3.5,
    this.transition = PanelTransition.zoom,
    this.animationDuration = const Duration(milliseconds: 200),
    this.frameInset = 10,
    this.loadingLabel,
  });

  final ImageProvider image;
  final Size imageSize;
  final Rect panel;

  /// Optional external controller. When omitted the widget owns one.
  final TransformationController? controller;

  final double padding;
  final double minScale;
  final double maxScale;

  /// How to move from the previous panel to this one.
  final PanelTransition transition;

  final Duration animationDuration;

  /// Static border kept around the animating content.
  final double frameInset;

  /// Shown under the loading indicator, e.g. `Pagina 12`.
  final String? loadingLabel;

  @override
  State<PanelViewport> createState() => _PanelViewportState();
}

class _PanelViewportState extends State<PanelViewport>
    with SingleTickerProviderStateMixin, ImageReadinessMixin<PanelViewport> {
  late final TransformationController _internal = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );

  CameraView? _from;
  CameraView? _to;
  Matrix4? _target;
  Size _viewport = Size.zero;
  bool _reduceMotion = false;
  bool _fadeJumped = false;

  TransformationController get _controller => widget.controller ?? _internal;

  @override
  void initState() {
    super.initState();
    _animation.addListener(_onTick);
  }

  @override
  ImageProvider get readinessImage => widget.image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(PanelViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      resetImageReadiness();
    }
    if (widget.panel != oldWidget.panel ||
        widget.imageSize != oldWidget.imageSize ||
        widget.maxScale != oldWidget.maxScale) {
      _target = null;
    }
    if (widget.transition != oldWidget.transition) {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _internal.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera plumbing
  // ---------------------------------------------------------------------------

  /// Centre of the inner viewport (the area the camera works in).
  Offset get _viewportCenter =>
      Offset(_viewport.width / 2, _viewport.height / 2);

  /// Reads the camera implied by [matrix] inside the current viewport.
  CameraView _viewOf(Matrix4 matrix) {
    final scale = matrix.getMaxScaleOnAxis();
    final safeScale = scale.isFinite && scale > 0 ? scale : 1.0;
    final center = _viewportCenter;
    // Matrix4 is column-major: 12 and 13 are the translation.
    return CameraView(
      focalX: (center.dx - matrix.storage[12]) / safeScale,
      focalY: (center.dy - matrix.storage[13]) / safeScale,
      scale: safeScale,
    );
  }

  /// Builds the matrix that places [view] at the current viewport centre.
  Matrix4 _matrixFor(CameraView view) {
    final center = _viewportCenter;
    return Matrix4.identity()
      ..translateByDouble(
        center.dx - view.scale * view.focalX,
        center.dy - view.scale * view.focalY,
        0,
        1,
      )
      ..scaleByDouble(view.scale, view.scale, view.scale, 1);
  }

  void _onTick() {
    switch (widget.transition) {
      case PanelTransition.zoom:
        final from = _from;
        final to = _to;
        if (from == null || to == null) return;
        final t = Curves.easeInOutCubic.transform(_animation.value);
        _controller.value = _matrixFor(CameraView.lerp(from, to, t));
      case PanelTransition.fade:
        // Jump to the destination while the screen is covered.
        if (!_fadeJumped && _animation.value >= 0.5) {
          _fadeJumped = true;
          final to = _to;
          if (to != null) _controller.value = _matrixFor(to);
        }
      case PanelTransition.none:
        break;
    }
  }

  void _startTransition(Matrix4 target) {
    _from = _viewOf(_controller.value);
    _to = _viewOf(target);
    _fadeJumped = false;

    final animate =
        !_reduceMotion && widget.transition != PanelTransition.none;
    if (!animate) {
      _animation.stop();
      _controller.value = target;
      return;
    }

    _animation
      ..duration = widget.animationDuration
      ..forward(from: 0);
  }

  /// Opacity of the neutral overlay used by [PanelTransition.fade]:
  /// `0 → 1` over the first half, `1 → 0` over the second.
  double get _fadeOpacity {
    if (widget.transition != PanelTransition.fade) return 0;
    final value = _animation.value;
    return (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the page before animating the camera on it.
    if (!imageReady) {
      return ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.all(widget.frameInset),
          child: Center(
            child: PageLoadingIndicator(label: widget.loadingLabel),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = widget.frameInset;
        final viewport = Size(
          math.max(1, constraints.maxWidth - inset * 2),
          math.max(1, constraints.maxHeight - inset * 2),
        );
        _viewport = viewport;

        final target = panelTransformation(
          viewportSize: viewport,
          imageSize: widget.imageSize,
          panel: widget.panel,
          padding: widget.padding,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
        );

        if (_target != target) {
          _target = target;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _startTransition(target);
          });
        }

        final content = ClipRect(
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            panEnabled: true,
            scaleEnabled: true,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: Image(
                image: widget.image,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        );

        return ColoredBox(
          // The visible border around the animating content: a static frame of
          // reference that does not move while the page does.
          color: Colors.black,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: AnimatedBuilder(
              animation: _animation,
              child: content,
              builder: (context, child) {
                final opacity = _fadeOpacity;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    if (opacity > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: opacity),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
