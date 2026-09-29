import 'package:comicsnow/app_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Verifies that `AppServices` actually picks the ONNX detector from the
/// bundled asset. Without this check a manifest-path mismatch would silently
/// leave the app on the heuristic detector.
///
/// ```bash
/// flutter test integration_test/detector_selection_test.dart -d macos
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selects the ONNX detector when the model is bundled', (
    tester,
  ) async {
    final services = await AppServices.create();
    addTearDown(services.dispose);

    debugPrint('ComicsNow detector: ${services.detectorDescription}');

    expect(services.detector.modelVersion, kOnnxModelVersion);
    expect(services.detectorDescription, contains('ONNX'));
  });
}
