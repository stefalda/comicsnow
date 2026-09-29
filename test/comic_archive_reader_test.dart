import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:comicsnow/comic/comic_archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

Uint8List png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

Uint8List zipOf(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

List<int> rarHeader() => [
  ...utf8.encode('Rar!'),
  0x1A,
  0x07,
  0x01,
  0x00,
];

/// Writes the given files into the destination, pretending to be a RAR
/// extraction. Records whether it was used.
class FakeRarExtractor implements ArchiveExtractor {
  FakeRarExtractor(this.entries);

  final Map<String, List<int>> entries;
  int calls = 0;

  @override
  Future<void> extractTo({
    required String archivePath,
    required String destinationPath,
  }) async {
    calls++;
    for (final entry in entries.entries) {
      final file = File(p.join(destinationPath, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
    }
  }
}

void main() {
  /// Scratch area: it plays the role of both the user's folder (where the test
  /// writes archives) and the app's documents directory.
  late Directory work;

  /// The app's temporary directory, separate from [_work] so archives created
  /// in `work/` are treated like files the user picked in place.
  late Directory temp;

  setUp(() {
    work = Directory.systemTemp.createTempSync('comicsnow_test');
    temp = Directory(p.join(work.path, 'temp'))..createSync();
  });

  tearDown(() {
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  ComicArchiveReader reader({ArchiveExtractor? rar}) => ComicArchiveReader(
    rarExtractor: rar ?? FakeRarExtractor(const {}),
    temporaryDirectory: () async => temp,
    documentsDirectory: () async => work,
  );

  group('CBZ (ZIP)', () {
    test('reads every image in natural order and skips other files', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(
          zipOf({
            'page10.png': png(4, 6),
            'notes.txt': const [1, 2, 3],
            'page2.png': png(4, 6),
            'page1.png': png(4, 6),
          }),
        );

      final comic = await reader().read(file);

      expect(comic.pages, hasLength(3));
      expect(comic.pages.map((page) => page.index), [0, 1, 2]);
      expect(comic.pages.first.width, 4);
      expect(comic.pages.first.height, 6);
      expect(comic.pages.first.imagePath, contains('page1'));
      expect(comic.pages[1].imagePath, contains('page2'));
      expect(comic.pages.last.imagePath, contains('page10'));
      expect(
        comic.pages.every((page) => File(page.imagePath).existsSync()),
        isTrue,
      );
    });

    test('builds stable page ids', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(2, 2)}));

      final comic = await reader().read(file);

      expect(comic.pages.single.id, '${comic.id}#0');
      expect(comic.title, 'comic');
    });

    test('reports progress while preparing pages', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(
          zipOf({
            'a.png': png(2, 2),
            'b.png': png(2, 2),
            'c.png': png(2, 2),
          }),
        );

      final calls = <(int, int)>[];
      await reader().read(file, onProgress: (done, total) => calls.add((done, total)));

      expect(calls, isNotEmpty);
      expect(calls.first.$1, 0);
      expect(calls.every((c) => c.$2 == 3), isTrue);
      expect(calls.last.$1, 3);
      // Monotonic.
      for (var i = 1; i < calls.length; i++) {
        expect(calls[i].$1, greaterThanOrEqualTo(calls[i - 1].$1));
      }
    });

    test('reopening the same archive reuses the extraction', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(4, 6), 'b.png': png(4, 6)}));

      final first = await reader().read(file);
      final firstPage = File(first.pages.first.imagePath);

      // Marker: if the page is extracted again, this content is lost.
      firstPage.writeAsBytesSync(const [1, 2, 3, 4]);

      final second = await reader().read(file);

      expect(second.pages, hasLength(2));
      expect(second.pages.first.imagePath, first.pages.first.imagePath);
      expect(second.pages.first.width, 4);
      expect(second.pages.first.height, 6);
      expect(
        firstPage.readAsBytesSync(),
        const [1, 2, 3, 4],
        reason: 'the pages were extracted again instead of reusing the cache',
      );
    });

    test('a changed archive is not served from the stale extraction', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(4, 6)}));

      final first = await reader().read(file);
      // Marker: it must not leak into the pages of the new archive.
      File(first.pages.first.imagePath).writeAsBytesSync(const [1, 2, 3]);

      file.writeAsBytesSync(zipOf({'a.png': png(4, 6), 'b.png': png(4, 6)}));
      final second = await reader().read(file);

      expect(second.pages, hasLength(2));
      expect(second.pages.first.imagePath, isNot(first.pages.first.imagePath));
      expect(
        File(second.pages.first.imagePath).readAsBytesSync().length,
        greaterThan(3),
        reason: 'the changed archive must be extracted fresh',
      );
    });

    test('the same content in another path reuses the extraction', () async {
      // Exactly what the file picker does: the archive is copied to a new
      // temporary directory on every open, keeping the original file name.
      final bytes = zipOf({'a.png': png(4, 6), 'b.png': png(4, 6)});

      final firstDir = Directory(p.join(work.path, 'cache', '1'))
        ..createSync(recursive: true);
      final secondDir = Directory(p.join(work.path, 'cache', '2'))
        ..createSync(recursive: true);

      final first = File(p.join(firstDir.path, 'comic.cbz'))
        ..writeAsBytesSync(bytes);
      final firstComic = await reader().read(first);

      final second = File(p.join(secondDir.path, 'comic.cbz'))
        ..writeAsBytesSync(bytes);
      final secondComic = await reader().read(second);

      expect(secondComic.pages, hasLength(2));
      expect(
        secondComic.pages.first.imagePath,
        firstComic.pages.first.imagePath,
        reason: 'a copy of the same archive must reuse the extraction',
      );
    });
  });

  group('CBR (RAR)', () {
    test('extracts, walks sub-folders and orders naturally', () async {
      final extractor = FakeRarExtractor({
        'ch1/page10.png': png(3, 5),
        'ch1/page2.png': png(3, 5),
        'ch1/page1.png': png(3, 5),
        'readme.txt': const [0],
      });

      final file = File(p.join(work.path, 'comic.cbr'))
        ..writeAsBytesSync(rarHeader());

      final comic = await reader(rar: extractor).read(file);

      expect(extractor.calls, 1);
      expect(comic.pages, hasLength(3));
      expect(comic.pages.first.imagePath, contains('page1'));
      expect(comic.pages[1].imagePath, contains('page2'));
      expect(comic.pages.last.imagePath, contains('page10'));
      expect(comic.pages.first.width, 3);
      expect(comic.pages.first.height, 5);
    });
  });

  group('reopening from the library', () {
    test('rebuilds the comic from the manifest', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(4, 6), 'b.png': png(4, 6)}));

      final readerInstance = reader();
      final first = await readerInstance.read(file);

      final reopened = await readerInstance.reopen(first.id);

      expect(reopened, isNotNull);
      expect(reopened!.id, first.id);
      expect(reopened.title, first.title);
      expect(reopened.pages, hasLength(2));
      expect(reopened.pages.first.imagePath, first.pages.first.imagePath);
      expect(reopened.pages.first.width, 4);
      expect(reopened.pages.first.height, 6);
    });

    test('returns null after the extraction is removed', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(4, 6)}));

      final readerInstance = reader();
      final comic = await readerInstance.read(file);

      await readerInstance.deleteExtraction(comic.id);

      expect(await readerInstance.reopen(comic.id), isNull);
      expect(File(comic.pages.first.imagePath).existsSync(), isFalse);
    });
  });

  group('stored archive (library source)', () {
    /// Mimics what the file picker hands over on mobile: a copy inside the
    /// app's temporary directory.
    File pickerCopy(String name, List<int> bytes) {
      final directory = Directory(p.join(temp.path, 'file_picker', '123'))
        ..createSync(recursive: true);
      return File(p.join(directory.path, name))..writeAsBytesSync(bytes);
    }

    test('moves the picker copy out of the temporary directory', () async {
      final source = pickerCopy('comic.cbz', zipOf({'a.png': png(4, 6)}));

      final comic = await reader().read(source);

      // The original temporary copy is gone, the stored one exists.
      expect(source.existsSync(), isFalse);
      final stored = File(comic.sourcePath!);
      expect(stored.existsSync(), isTrue);
      expect(p.isWithin(temp.path, stored.path), isFalse);
      expect(p.extension(stored.path), '.cbz');
      expect(
        stored.parent.path,
        p.join(work.path, 'comicsnow', 'archives'),
      );
    });

    test('rebuilds the extraction from the stored archive', () async {
      final source = pickerCopy('comic.cbz', zipOf({'a.png': png(4, 6)}));
      final instance = reader();
      final comic = await instance.read(source);

      // Simulate the OS clearing the temporary directory.
      await instance.deleteExtraction(comic.id);

      // Without knowing where the archive is, the comic cannot be rebuilt.
      expect(await instance.reopen(comic.id), isNull);

      final reopened = await instance.reopen(
        comic.id,
        title: comic.title,
        archivePath: comic.sourcePath,
      );

      expect(reopened, isNotNull);
      expect(reopened!.pages, hasLength(1));
      expect(reopened.pages.first.width, 4);
      expect(File(reopened.pages.first.imagePath).existsSync(), isTrue);
    });

    test('removing a comic deletes the stored archive', () async {
      final source = pickerCopy('comic.cbz', zipOf({'a.png': png(4, 6)}));
      final instance = reader();
      final comic = await instance.read(source);

      await instance.removeComic(comic.id, archivePath: comic.sourcePath);

      expect(File(comic.sourcePath!).existsSync(), isFalse);
      expect(File(comic.pages.first.imagePath).existsSync(), isFalse);
    });

    test('removing a comic never deletes a file the user chose', () async {
      final file = File(p.join(work.path, 'comic.cbz'))
        ..writeAsBytesSync(zipOf({'a.png': png(4, 6)}));

      final instance = reader();
      final comic = await instance.read(file);

      await instance.removeComic(comic.id, archivePath: comic.sourcePath);

      expect(file.existsSync(), isTrue);
    });
  });

  group('format detection', () {
    test('a RAR renamed .cbz is still read as RAR', () async {
      final extractor = FakeRarExtractor({'p1.png': png(2, 2)});

      final file = File(p.join(work.path, 'mislabeled.cbz'))
        ..writeAsBytesSync(rarHeader());

      final comic = await reader(rar: extractor).read(file);

      expect(extractor.calls, 1);
      expect(comic.pages, hasLength(1));
    });

    test('a ZIP renamed .cbr is read as ZIP', () async {
      final extractor = FakeRarExtractor(const {});

      final file = File(p.join(work.path, 'mislabeled.cbr'))
        ..writeAsBytesSync(zipOf({'p1.png': png(2, 2)}));

      final comic = await reader(rar: extractor).read(file);

      expect(extractor.calls, 0, reason: 'ZIP detection should win');
      expect(comic.pages, hasLength(1));
    });
  });
}
