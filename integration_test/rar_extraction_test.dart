import 'dart:io';

import 'package:comicsnow/comic/comic_archive_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Exercises the real RAR native plugin inside the app bundle.
///
/// The bundled fixture (`test/fixtures/sample.rar`) only contains text files,
/// so it yields no pages, but extraction itself must succeed through the
/// native UnrarKit path.
///
/// ```bash
/// flutter test integration_test/rar_extraction_test.dart -d macos \
///   --dart-define=RAR_FIXTURE=$PWD/test/fixtures/sample.rar
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('extracts a real RAR archive with the native plugin', (
    tester,
  ) async {
    const fixture = String.fromEnvironment('RAR_FIXTURE');
    if (fixture.isEmpty) {
      markTestSkipped('pass --dart-define=RAR_FIXTURE=/absolute/path.rar');
      return;
    }

    final work = await Directory.systemTemp.createTemp('comicsnow_rar');
    addTearDown(() {
      if (work.existsSync()) work.deleteSync(recursive: true);
    });

    final reader = ComicArchiveReader(temporaryDirectory: () async => work);
    final comic = await reader.read(File(fixture));

    final extracted = Directory(work.path)
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path.split(Platform.pathSeparator).last)
        .toList();

    debugPrint('RAR extracted files: $extracted');

    expect(extracted, contains('test.txt'));
    expect(extracted, contains('file2.txt'));
    // Text-only archive: no pages, but extraction must not throw.
    expect(comic.pages, isEmpty);
  });
}
