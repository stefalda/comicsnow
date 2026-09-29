import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading indicator used by the reader while a page is being decoded.
///
/// The stock [CircularProgressIndicator] is small and tinted with the theme
/// colour, which on the reader's black background reads as a barely visible
/// dot. This one is deliberately large, white and animated (a rotating arc that
/// breathes, plus a soft scale pulse).
///
/// It respects the system "reduce motion" setting: the animation is replaced by
/// a static arc.
class PageLoadingIndicator extends StatefulWidget {
  const PageLoadingIndicator({
    super.key,
    this.label,
    this.size = 84,
    this.color = Colors.white,
  });

  /// Optional text under the indicator, e.g. `Pagina 12`.
  final String? label;

  final double size;
  final Color color;

  @override
  State<PageLoadingIndicator> createState() => _PageLoadingIndicatorState();
}

class _PageLoadingIndicatorState extends State<PageLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;

    final indicator = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        // Breathing scale, so the indicator feels alive even when the arc
        // happens to be at the same angle.
        final scale = _reduceMotion
            ? 1.0
            : 1 + 0.045 * math.sin(2 * math.pi * progress);

        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _ArcPainter(
              progress: _reduceMotion ? 0 : progress,
              color: widget.color,
              trackColor: widget.color.withValues(alpha: 0.14),
            ),
          ),
        );
      },
    );

    if (label == null) return indicator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: widget.color.withValues(alpha: 0.75),
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const _strokeWidth = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - _strokeWidth / 2;
    if (radius <= 0) return;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    // The arc grows and shrinks while rotating, like the Material
    // indeterminate indicator but bigger and with round caps.
    final sweep = (0.25 + 0.15 * math.sin(2 * math.pi * progress)) * 2 * math.pi;
    final startAngle = 2 * math.pi * progress - math.pi / 2;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
