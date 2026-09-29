import 'dart:io';
import 'dart:ui';

import 'package:comicsnow/detection/gutter_panel_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Diagnostic harness.
///
/// Put page images in `samples/` and include the expected number of panels in
/// the file name, e.g. `page-004 - 9 panels.jpg`, then run:
///
/// ```bash
/// flutter test test/detection_samples_test.dart
/// ```
///
/// It prints a comparison table and writes annotated images (detected boxes
/// drawn on the page) to `build/detection/`.
void main() {
  test('analyse sample pages', () async {
    final directory = Directory('samples');
    if (!directory.existsSync()) {
      markTestSkipped('no samples/ directory');
      return;
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => _isImage(file.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      markTestSkipped('no images in samples/');
      return;
    }

    final outputDirectory = Directory('build/detection')
      ..createSync(recursive: true);

    final configs = <String, GutterPanelDetector>{
      'auto w720': GutterPanelDetector(),
      'auto w1064': GutterPanelDetector(analysisWidth: 1064),
      'dark w720': GutterPanelDetector(
        polarity: PanelPolarity.darkInk,
      ),
      'bright w720': GutterPanelDetector(
        polarity: PanelPolarity.brightInk,
      ),
    };

    final report = StringBuffer();

    for (final file in files) {
      final name = p.basenameWithoutExtension(file.path);
      final expected = _expectedPanels(name);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        report.writeln('$name: DECODE FAILED');
        continue;
      }

      report.writeln(
        '\n$name  (expected: $expected, ${decoded.width}x${decoded.height})',
      );

      for (final entry in configs.entries) {
        final detections = await entry.value.detect(
          imageBytes: bytes,
          imageWidth: decoded.width,
          imageHeight: decoded.height,
        );
        final flag = expected == null
            ? ''
            : detections.length == expected
                ? 'OK'
                : 'MISMATCH';
        report.writeln(
          '  ${entry.key.padRight(14)} -> '
          '${detections.length} panels  $flag',
        );

        if (entry.key == 'auto w720') {
          _writeAnnotated(
            decoded: decoded,
            boxes: detections.map((d) => d.bounds).toList(),
            path: p.join(outputDirectory.path, '$name.annotated.png'),
          );
        }
      }
    }

    report.writeln('\nAnnotated images: ${outputDirectory.path}');
    debugPrint(report.toString());

    // The harness is a measurement tool, not a gate: keep it green so it can
    // be run at any time while tuning.
    expect(files, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

int? _expectedPanels(String name) {
  final match = RegExp(r'(\d+)\s*panels?', caseSensitive: false).firstMatch(name);
  return match == null ? null : int.tryParse(match.group(1)!);
}

bool _isImage(String path) {
  final extension = p.extension(path).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}.contains(extension);
}

void _writeAnnotated({
  required img.Image decoded,
  required List<Rect> boxes,
  required String path,
}) {
  final annotated = decoded.clone();
  for (final box in boxes) {
    img.drawRect(
      annotated,
      x1: box.left.round(),
      y1: box.top.round(),
      x2: box.right.round(),
      y2: box.bottom.round(),
      color: img.ColorRgb8(255, 0, 0),
      thickness: 6,
    );
  }

  final preview = img.copyResize(annotated, width: 900);
  File(path).writeAsBytesSync(img.encodePng(preview));
}
