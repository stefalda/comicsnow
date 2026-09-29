import 'dart:io';

import 'package:comicsnow/detection/onnx_panel_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

/// Evaluates the *real* ONNX model on the local sample pages, sweeping a few
/// confidence thresholds so the best one can be picked from the printed table.
///
/// ```bash
/// flutter test integration_test/onnx_samples_test.dart -d macos \
///   --dart-define=SAMPLES_DIR=$PWD/samples
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('evaluate the ONNX model on the sample pages', (tester) async {
    const fromDefine = String.fromEnvironment('SAMPLES_DIR');
    final directory = Directory(fromDefine.isNotEmpty ? fromDefine : 'samples');

    if (!directory.existsSync()) {
      markTestSkipped(
        'samples directory not found: ${directory.path}. '
        'Pass --dart-define=SAMPLES_DIR=/absolute/path/to/samples',
      );
      return;
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => _isImage(file.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      markTestSkipped('no images in ${directory.path}');
      return;
    }

    const thresholds = [0.25, 0.35, 0.50];

    final detectors = <double, OnnxPanelDetector>{
      for (final threshold in thresholds)
        threshold: OnnxPanelDetector(
          modelPath: 'assets/models/panel_detector.onnx',
          modelVersion: 'samples-eval',
          confidenceThreshold: threshold,
        ),
    };
    addTearDown(() async {
      for (final detector in detectors.values) {
        await detector.dispose();
      }
    });

    try {
      for (final detector in detectors.values) {
        await detector.initialize();
      }
    } catch (error) {
      markTestSkipped('assets/models/panel_detector.onnx missing: $error');
      return;
    }

    final exact = <double, int>{for (final t in thresholds) t: 0};
    var withExpectation = 0;
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

      final counts = <double, int>{};
      for (final threshold in thresholds) {
        final detections = await detectors[threshold]!.detect(
          imageBytes: bytes,
          imageWidth: decoded.width,
          imageHeight: decoded.height,
        );
        counts[threshold] = detections.length;
        if (expected != null && expected == detections.length) {
          exact[threshold] = exact[threshold]! + 1;
        }
      }
      if (expected != null) withExpectation++;

      report.writeln(
        '$name\n'
        '  expected=$expected  '
        '${thresholds.map((t) => 'conf$t=${counts[t]}').join('  ')}',
      );
    }

    report.writeln(
      '\nExact matches (of $withExpectation): '
      '${thresholds.map((t) => 'conf$t=${exact[t]}').join('  ')}',
    );
    debugPrint(report.toString());

    expect(withExpectation, greaterThan(0), reason: 'no expected counts parsed');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

int? _expectedPanels(String name) {
  final match = RegExp(
    r'(\d+)\s*panels?',
    caseSensitive: false,
  ).firstMatch(name);
  return match == null ? null : int.tryParse(match.group(1)!);
}

bool _isImage(String path) {
  final extension = p.extension(path).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}.contains(extension);
}
