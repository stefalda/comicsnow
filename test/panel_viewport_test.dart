import 'dart:math' as math;

import 'package:comicsnow/reader/panel_viewport.dart';
import 'package:comicsnow/reader/reader_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_image.dart';

/// The camera round-trip (matrix → camera → matrix) introduces tiny
/// floating-point noise, so matrices are compared entry by entry.
void expectMatrixCloseTo(
  Matrix4 actual,
  Matrix4 expected, {
  double tolerance = 1e-6,
}) {
  for (var i = 0; i < 16; i++) {
    expect(
      actual.storage[i],
      closeTo(expected.storage[i], tolerance),
      reason: 'matrix entry $i',
    );
  }
}

void main() {
  const viewportSize = Size(400, 800);
  const imageSize = Size(1000, 1500);
  const padding = 0.9;
  const maxScale = 4.0;

  // Whole page: fills the viewport, so the camera stays at 1x.
  const bigPanel = Rect.fromLTWH(0, 0, 1000, 1500);
  // Small panel: zoomed in, but below the cap.
  const smallPanel = Rect.fromLTWH(0, 0, 250, 200);

  Matrix4 targetFor(Rect panel) => panelTransformation(
    viewportSize: viewportSize,
    imageSize: imageSize,
    panel: panel,
    padding: padding,
    maxScale: maxScale,
  );

  late TransformationController controller;
  late StubImageProvider image;

  setUp(() async {
    controller = TransformationController();
    image = await createStubImageProvider();
  });

  tearDown(() {
    controller.dispose();
    image.image.dispose();
  });

  /// The viewport under test must be exactly [viewportSize]; the default test
  /// surface is 800x600.
  Future<void> useViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(viewportSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget app(
    Rect panel, {
    required PanelTransition transition,
    bool reduceMotion = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PanelViewport(
          image: image,
          imageSize: imageSize,
          panel: panel,
          controller: controller,
          padding: padding,
          maxScale: maxScale,
          frameInset: 0,
          transition: transition,
          animationDuration: const Duration(milliseconds: 100),
        ),
      ),
    );
  }

  testWidgets('no transition jumps straight to the panel', (tester) async {
    await useViewport(tester);

    await tester.pumpWidget(app(bigPanel, transition: PanelTransition.none));
    await tester.pump();

    await tester.pumpWidget(app(smallPanel, transition: PanelTransition.none));
    await tester.pump();

    expectMatrixCloseTo(controller.value, targetFor(smallPanel));
  });

  testWidgets('zoom transition finishes on the target panel', (tester) async {
    await useViewport(tester);

    await tester.pumpWidget(app(bigPanel, transition: PanelTransition.zoom));
    await tester.pump();

    await tester.pumpWidget(app(smallPanel, transition: PanelTransition.zoom));
    await tester.pump();

    // Just started: still on the previous camera.
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(targetFor(bigPanel).getMaxScaleOnAxis(), 1e-6),
    );

    await tester.pumpAndSettle();

    expectMatrixCloseTo(controller.value, targetFor(smallPanel));
  });

  testWidgets('zoom transition interpolates the scale geometrically', (
    tester,
  ) async {
    await useViewport(tester);

    await tester.pumpWidget(app(bigPanel, transition: PanelTransition.zoom));
    await tester.pump();

    await tester.pumpWidget(app(smallPanel, transition: PanelTransition.zoom));
    await tester.pump();

    // Half-way (easeInOutCubic crosses 0.5 at t = 0.5).
    await tester.pump(const Duration(milliseconds: 50));

    final from = targetFor(bigPanel).getMaxScaleOnAxis();
    final to = targetFor(smallPanel).getMaxScaleOnAxis();
    final mid = controller.value.getMaxScaleOnAxis();

    final geometric = math.sqrt(from * to);
    final arithmetic = (from + to) / 2;

    expect(mid, greaterThan(from));
    expect(mid, lessThan(to));
    // Log interpolation keeps the mid scale near the geometric mean; an
    // arithmetic interpolation of the matrix would overshoot towards the
    // arithmetic mean (a much faster, more aggressive zoom).
    expect(
      (mid - geometric).abs(),
      lessThan((mid - arithmetic).abs()),
    );

    await tester.pumpAndSettle();
  });

  testWidgets('fade transition jumps at the midpoint without a zoom', (
    tester,
  ) async {
    await useViewport(tester);

    await tester.pumpWidget(app(bigPanel, transition: PanelTransition.fade));
    await tester.pump();

    await tester.pumpWidget(app(smallPanel, transition: PanelTransition.fade));
    await tester.pump();

    // Before the midpoint the old camera is still in place.
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(targetFor(bigPanel).getMaxScaleOnAxis(), 1e-6),
    );

    // After the midpoint the jump already happened.
    await tester.pump(const Duration(milliseconds: 20));
    expectMatrixCloseTo(controller.value, targetFor(smallPanel));

    await tester.pumpAndSettle();
  });

  testWidgets('reduce motion disables the animation', (tester) async {
    await useViewport(tester);

    await tester.pumpWidget(
      app(bigPanel, transition: PanelTransition.zoom, reduceMotion: true),
    );
    await tester.pump();

    await tester.pumpWidget(
      app(smallPanel, transition: PanelTransition.zoom, reduceMotion: true),
    );
    await tester.pump();

    expectMatrixCloseTo(controller.value, targetFor(smallPanel));
  });
}
