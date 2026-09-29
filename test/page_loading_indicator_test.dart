import 'package:comicsnow/reader/page_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders the indicator with its label', (tester) async {
    await tester.pumpWidget(app(const PageLoadingIndicator(label: 'Pagina 12')));
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Pagina 12'), findsOneWidget);
  });

  testWidgets('renders without a label', (tester) async {
    await tester.pumpWidget(app(const PageLoadingIndicator()));
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('respects reduce motion (no endless animation)', (tester) async {
    await tester.pumpWidget(
      app(const PageLoadingIndicator(label: 'Pagina 3'), reduceMotion: true),
    );

    // Would time out if the indicator kept animating forever.
    await tester.pumpAndSettle();

    expect(find.text('Pagina 3'), findsOneWidget);
  });
}
