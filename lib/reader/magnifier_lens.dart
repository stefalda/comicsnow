import 'package:flutter/material.dart';

/// Where the loupe goes and what it must magnify.
typedef MagnifierPlacement = ({Rect lens, Offset focalPointOffset});

/// Computes the lens rectangle and the [RawMagnifier.focalPointOffset] that
/// keep the point under the finger exactly at the centre of the lens.
///
/// [RawMagnifier] shows, at its centre, the content at
/// `focalPointOffset + centre`. So the offset is not a constant: as soon as the
/// lens is nudged to stay on screen (or flipped below the finger), the offset
/// must follow, otherwise the lens would magnify the wrong spot — which is what
/// made the edges of the page un-magnifiable.
MagnifierPlacement magnifierPlacement({
  required Offset focalPoint,
  required Size viewportSize,
  double size = 280,
  double? lift,
}) {
  // The lens floats clear of the finger: half its diameter plus a small gap.
  // Derived from the size so a bigger lens is not covered by the finger.
  final effectiveLift = lift ?? size / 2 + defaultGap;

  final maxLeft = (viewportSize.width - size).clamp(0.0, double.infinity);
  final maxTop = (viewportSize.height - size).clamp(0.0, double.infinity);

  // Above the finger by preference, below it when there is no room up there.
  var top = focalPoint.dy - effectiveLift - size / 2;
  if (top < 0) {
    top = focalPoint.dy + effectiveLift - size / 2;
  }

  final left = (focalPoint.dx - size / 2).clamp(0.0, maxLeft);
  top = top.clamp(0.0, maxTop);

  final lens = Rect.fromLTWH(left, top, size, size);
  return (lens: lens, focalPointOffset: focalPoint - lens.center);
}

/// Gap kept between the lens and the finger.
const double defaultGap = 16;

/// A loupe that follows the finger, used while long-pressing a page or a panel.
///
/// It wraps [RawMagnifier], which samples whatever is painted *behind* it in
/// the same layer tree: placing this widget after the page inside a [Stack] is
/// all it takes to magnify the artwork and the panel frames together.
class MagnifierLens extends StatelessWidget {
  const MagnifierLens({
    super.key,
    required this.focalPoint,
    required this.viewportSize,
    this.size = 280,
    this.magnification = 2.5,
    this.lift,
  });

  /// Point being magnified, in the coordinate space of the enclosing [Stack].
  final Offset focalPoint;

  /// Size of the enclosing viewport, used to keep the lens on screen.
  final Size viewportSize;

  /// Diameter of the lens.
  final double size;

  /// How much the content is enlarged.
  final double magnification;

  /// How far the lens floats away from the finger. Defaults to half the lens
  /// plus [defaultGap], so the finger never covers what you are reading.
  final double? lift;

  @override
  Widget build(BuildContext context) {
    final placement = magnifierPlacement(
      focalPoint: focalPoint,
      viewportSize: viewportSize,
      size: size,
      lift: lift,
    );

    return Positioned.fromRect(
      rect: placement.lens,
      child: IgnorePointer(
        child: RawMagnifier(
          decoration: MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.9),
                width: 3,
              ),
            ),
            shadows: const [
              BoxShadow(color: Colors.black54, blurRadius: 22),
            ],
          ),
          // Essential, not cosmetic: with the default `Clip.none` the shadow is
          // painted *over* the magnified content, which came out noticeably
          // darker than the page (measured: 107 instead of 158 on a grey page).
          // Clipping sends the shadow outside the lens, where it belongs.
          clipBehavior: Clip.antiAlias,
          size: Size.square(size),
          magnificationScale: magnification,
          focalPointOffset: placement.focalPointOffset,
        ),
      ),
    );
  }
}
