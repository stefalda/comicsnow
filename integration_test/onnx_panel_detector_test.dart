import 'dart:typed_data';

import 'package:comicsnow/detection/onnx_panel_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

/// End-to-end smoke test for the native ONNX Runtime path on desktop.
///
/// It uses a tiny synthetic model (`assets/models/smoke_test_panel_detector.onnx`)
/// whose output is a fixed YOLO-style tensor with two boxes:
///
/// * `cx=320, cy=320, w=128, h=128, score=0.90` → image rect `256,256,384,384`
/// * `cx=100, cy=100, w=64,  h=64,  score=0.40` → image rect `68,68,132,132`
///
/// The page is 640x640, so the letterbox is the identity and the coordinates
/// must come back unchanged.
///
/// Run on a device:
///
/// ```bash
/// flutter test integration_test/onnx_panel_detector_test.dart -d macos
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads a real ONNX model and decodes its detections', (
    tester,
  ) async {
    final detector = OnnxPanelDetector(
      modelPath: 'assets/models/smoke_test_panel_detector.onnx',
      modelVersion: 'smoke-test',
      confidenceThreshold: 0.35,
    );
    addTearDown(detector.dispose);

    final page = img.Image(width: 640, height: 640);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodePng(page));

    final detections = await detector.detect(
      imageBytes: bytes,
      imageWidth: 640,
      imageHeight: 640,
    );

    expect(detector.isInitialized, isTrue);
    expect(detections, hasLength(2));

    final first = detections.first;
    expect(first.confidence, closeTo(0.90, 1e-3));
    expect(first.bounds.left, closeTo(256, 1.0));
    expect(first.bounds.top, closeTo(256, 1.0));
    expect(first.bounds.right, closeTo(384, 1.0));
    expect(first.bounds.bottom, closeTo(384, 1.0));
    expect(first.className, 'panel');

    final second = detections.last;
    expect(second.confidence, closeTo(0.40, 1e-3));
    expect(second.bounds.left, closeTo(68, 1.0));
    expect(second.bounds.right, closeTo(132, 1.0));
  });
}
