import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rar/rar.dart';

import '../domain/comic.dart';
import '../domain/comic_page.dart';
import 'app_storage.dart';
import 'natural_order.dart';

/// Raised when an archive cannot be read.
class ArchiveExtractionException implements Exception {
  ArchiveExtractionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'ArchiveExtractionException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Reports extraction progress: [done] pages out of [total].
typedef ExtractionProgress = void Function(int done, int total);

/// Extracts a RAR archive to a directory.
///
/// Abstracted so the archive reader can be tested without the native plugin.
abstract interface class ArchiveExtractor {
  Future<void> extractTo({
    required String archivePath,
    required String destinationPath,
  });
}

/// [ArchiveExtractor] backed by the `rar` plugin (UnrarKit on Apple platforms,
/// JUnRar on Android).
class RarArchiveExtractor implements ArchiveExtractor {
  const RarArchiveExtractor();

  @override
  Future<void> extractTo({
    required String archivePath,
    required String destinationPath,
  }) async {
    final Map<String, dynamic> result;
    try {
      result = await Rar.extractRarFile(
        rarFilePath: archivePath,
        destinationPath: destinationPath,
      );
    } catch (error) {
      throw ArchiveExtractionException('RAR extraction failed', error);
    }

    if (result['success'] != true) {
      throw ArchiveExtractionException(
        result['message']?.toString() ?? 'RAR extraction failed',
      );
    }
  }
}

enum ArchiveFormat { zip, rar }

/// Reads CBZ/CBR (and plain ZIP/RAR) comics.
///
/// Pages are extracted to a temporary directory and referenced by
/// [ComicPage.imagePath]; the archives are never held in memory in full.
///
/// Performance notes (measured on a 223 MB / 150 page CBZ):
///
/// * reading the archive index: ~40 ms;
/// * decompressing every page: ~0.7 s;
/// * decoding every page **fully** just to read its size: ~42 s (!);
/// * reading only the image header ([_probeSize]): ~2.3 s.
///
/// So the dimension probe is the only expensive step, and the extraction
/// itself is cheap enough that lazy extraction is not worth the complexity.
/// A manifest written next to the extracted pages makes reopening the same
/// archive instant.
class ComicArchiveReader {
  ComicArchiveReader({
    this.rarExtractor = const RarArchiveExtractor(),
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? documentsDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final ArchiveExtractor rarExtractor;

  /// Where archives are extracted. Injectable so tests do not need
  /// `path_provider`.
  final Future<Directory> Function() _temporaryDirectory;

  /// Where the app keeps its own copy of the picked archives. Injectable so
  /// tests do not need `path_provider`.
  final Future<Directory> Function() _documentsDirectory;

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  static const _manifestName = '.manifest.json';

  /// How many pages are processed between two event loop yields. Keeps the UI
  /// responsive (progress indicator, taps) during a long extraction.
  static const _yieldEvery = 8;

  /// Extracts [file] and returns the resulting [Comic].
  ///
  /// [onProgress] is called while pages are prepared, so the UI can show real
  /// progress instead of a mute wait.
  Future<Comic> read(
    File file, {
    String? title,
    ExtractionProgress? onProgress,
  }) async {
    final signature = await _signatureOf(file);
    // The identifier must not depend on the *path*: the file picker copies the
    // picked archive into a fresh temporary directory on every open, so a
    // path-based id would change every time (losing the saved reading position
    // and re-extracting from scratch). Name + content signature is stable.
    final comicId = _identifierFor(file.path, signature);
    final comicTitle = title ?? p.basenameWithoutExtension(file.path);

    // Keep a copy the library can read again later (moving the picker's cache
    // copy, when that is what we got, costs no extra space).
    final archive = File(await _persistArchive(file, comicId));

    final tempRoot = await _temporaryDirectory();
    final comicsRoot = Directory(p.join(tempRoot.path, 'comicsnow'));
    final comicDirectory = Directory(p.join(comicsRoot.path, comicId));

    unawaited(_cleanUpStaleExtractions(comicsRoot, keep: comicDirectory));

    // Reuse a previous extraction of the same archive: reopening is instant.
    var manifest = await _readManifest(
      comicDirectory,
      requireSignature: signature,
    );

    manifest ??= await _extract(
      archive,
      comicDirectory,
      signature: signature,
      title: comicTitle,
      onProgress: onProgress,
    );

    return _comicFrom(
      comicId,
      comicTitle,
      manifest,
      sourcePath: archive.path,
    );
  }

  /// Reopens a comic from the library, without asking for the file again.
  ///
  /// 1. If the pages are still extracted, they are used directly.
  /// 2. Otherwise the extraction is rebuilt from the stored copy of the archive
  ///    ([archivePath]) — which is what the OS clearing the temporary directory
  ///    requires.
  /// 3. Returns `null` only when neither is available.
  Future<Comic?> reopen(
    String comicId, {
    String? title,
    String? archivePath,
    ExtractionProgress? onProgress,
  }) async {
    final comicDirectory = await _comicDirectory(comicId);
    final manifest = await _readManifest(comicDirectory);
    if (manifest != null) {
      return _comicFrom(
        comicId,
        title ?? manifest.title,
        manifest,
        sourcePath: archivePath,
      );
    }

    if (archivePath == null) return null;
    final archive = File(archivePath);
    if (!await archive.exists()) return null;

    // The extracted pages are gone (the OS cleared the temporary directory), so
    // rebuild them from the stored archive instead of asking for the file.
    debugPrint('ComicsNow: rebuilding $comicId from the stored archive');

    final signature = await _signatureOf(archive);
    final rebuilt = await _extract(
      archive,
      comicDirectory,
      signature: signature,
      title: title ?? p.basenameWithoutExtension(archive.path),
      onProgress: onProgress,
    );

    return _comicFrom(
      comicId,
      title ?? rebuilt.title,
      rebuilt,
      sourcePath: archive.path,
    );
  }

  /// Removes everything the app keeps for [comicId]: the extracted pages and,
  /// when it is our own copy, the stored archive.
  ///
  /// A file the user picked in place (desktop) is never touched.
  Future<void> removeComic(String comicId, {String? archivePath}) async {
    await deleteExtraction(comicId);

    if (archivePath == null) return;
    try {
      final archives = await _archivesDirectory();
      if (!p.isWithin(archives.path, archivePath)) return;

      final file = File(archivePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort.
    }
  }

  /// Frees the extracted pages of [comicId].
  Future<void> deleteExtraction(String comicId) async {
    try {
      final comicDirectory = await _comicDirectory(comicId);
      if (await comicDirectory.exists()) {
        await comicDirectory.delete(recursive: true);
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<Directory> _comicDirectory(String comicId) async {
    final tempRoot = await _temporaryDirectory();
    return Directory(p.join(tempRoot.path, 'comicsnow', comicId));
  }

  Future<Directory> _archivesDirectory() async {
    final documents = await _documentsDirectory();
    return Directory(p.join(documents.path, 'comicsnow', 'archives'));
  }

  /// Makes sure the archive will still be readable in a future session.
  ///
  /// The file picker hands out a copy in the app's temporary directory on
  /// mobile, which the OS can clear: that copy is moved next to the library
  /// data. A path the user chose themselves (desktop) is left where it is.
  Future<String> _persistArchive(File source, String comicId) async {
    final tempRoot = await _temporaryDirectory();

    // Compare *resolved* paths: on macOS the temporary directory comes from one
    // API as `/var/...` and from another as `/private/var/...` — the same place
    // through a symlink, but a plain prefix check says otherwise. A file in the
    // app's own inbox is ours as well, wherever the platform put it.
    final rootPath = await _resolvedPath(tempRoot.path) ?? tempRoot.path;
    final sourcePath = await _resolvedPath(source.path) ?? source.path;
    final inOwnInbox =
        p.equals(p.basename(p.dirname(sourcePath)), kOpenWithInboxName);

    if (!inOwnInbox && !p.isWithin(rootPath, sourcePath)) {
      debugPrint('ComicsNow: archivio lasciato dov\'è: $sourcePath');
      return source.path;
    }

    final archives = await _archivesDirectory();
    final target = File(
      p.join(archives.path, '$comicId${p.extension(source.path)}'),
    );
    if (p.equals(target.path, source.path)) return target.path;

    try {
      await archives.create(recursive: true);
      try {
        await source.rename(target.path);
      } on FileSystemException {
        // Different volume: copy and drop the temporary file.
        await source.copy(target.path);
        try {
          await source.delete();
        } catch (_) {
          // The OS clears the cache eventually anyway.
        }
      }
      debugPrint('ComicsNow: archivio conservato in ${target.path}');
      return target.path;
    } catch (error) {
      // Keeping the archive is best effort: without it the comic can still be
      // reopened while the extraction survives.
      debugPrint(
        'ComicsNow: archivio non conservato (${source.path} -> ${target.path}): '
        '$error',
      );
      return source.path;
    } finally {
      // The picker creates a fresh timestamped directory per pick: drop it when
      // it is empty, so the cache does not fill with empty folders.
      try {
        final parent = source.parent;
        final parentPath = await _resolvedPath(parent.path) ?? parent.path;
        final parentIsOurs =
            p.equals(p.basename(parentPath), kOpenWithInboxName) ||
            p.isWithin(rootPath, parentPath);
        if (parentIsOurs && await parent.list().isEmpty) {
          await parent.delete();
        }
      } catch (_) {
        // Best effort.
      }
    }
  }

  /// [path] with symlinks resolved, or `null` when it does not exist.
  static Future<String?> _resolvedPath(String path) async {
    try {
      return await File(path).resolveSymbolicLinks();
    } on FileSystemException {
      return null;
    }
  }

  static Comic _comicFrom(
    String comicId,
    String title,
    _Manifest manifest, {
    String? sourcePath,
  }) {
    return Comic(
      id: comicId,
      title: title,
      pages: [
        for (var index = 0; index < manifest.pages.length; index++)
          ComicPage(
            id: '$comicId#$index',
            index: index,
            imagePath: manifest.pages[index].path,
            width: manifest.pages[index].width,
            height: manifest.pages[index].height,
          ),
      ],
      sourcePath: sourcePath,
    );
  }

  Future<_Manifest> _extract(
    File file,
    Directory comicDirectory, {
    required String signature,
    required String title,
    ExtractionProgress? onProgress,
  }) async {
    if (await comicDirectory.exists()) {
      await comicDirectory.delete(recursive: true);
    }
    await comicDirectory.create(recursive: true);

    final format = await _detectFormat(file);

    final pages = switch (format) {
      ArchiveFormat.zip => await _readZip(file, comicDirectory, onProgress),
      ArchiveFormat.rar => await _readRar(file, comicDirectory, onProgress),
    };

    await _writeManifest(comicDirectory, signature, title, pages);
    return _Manifest(title: title, pages: pages);
  }

  // ---------------------------------------------------------------------------
  // Format detection
  // ---------------------------------------------------------------------------

  /// Detects ZIP vs RAR from the file signature, falling back to the extension.
  ///
  /// Mislabelled archives are common (a `.cbr` that is really a ZIP, or vice
  /// versa), so the magic bytes win.
  Future<ArchiveFormat> _detectFormat(File file) async {
    try {
      final handle = await file.open();
      try {
        final header = await handle.read(8);
        if (header.length >= 4 && header[0] == 0x50 && header[1] == 0x4B) {
          return ArchiveFormat.zip;
        }
        if (header.length >= 7 &&
            header[0] == 0x52 && // R
            header[1] == 0x61 && // a
            header[2] == 0x72 && // r
            header[3] == 0x21) {
          return ArchiveFormat.rar;
        }
      } finally {
        await handle.close();
      }
    } catch (_) {
      // Fall through to the extension.
    }

    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.cbr' || extension == '.rar') {
      return ArchiveFormat.rar;
    }
    return ArchiveFormat.zip;
  }

  // ---------------------------------------------------------------------------
  // ZIP
  // ---------------------------------------------------------------------------

  Future<List<_ExtractedPage>> _readZip(
    File file,
    Directory destination,
    ExtractionProgress? onProgress,
  ) async {
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input);

      final entries =
          archive.files
              .where((entry) => entry.isFile && _isImage(entry.name))
              .toList()
            ..sort((a, b) => naturalCompare(a.name, b.name));

      final pages = <_ExtractedPage>[];
      onProgress?.call(0, entries.length);

      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        final bytes = entry.readBytes();
        if (bytes == null || bytes.isEmpty) continue;

        final size = _probeSize(bytes);
        if (size == null) continue;

        final fileName =
            '${index.toString().padLeft(4, '0')}_${p.basename(entry.name)}';
        final pagePath = p.join(destination.path, fileName);
        await File(pagePath).writeAsBytes(bytes, flush: false);

        pages.add(
          _ExtractedPage(path: pagePath, width: size.$1, height: size.$2),
        );

        onProgress?.call(index + 1, entries.length);
        await _breathe(index);
      }

      return pages;
    } finally {
      input.close();
    }
  }

  // ---------------------------------------------------------------------------
  // RAR
  // ---------------------------------------------------------------------------

  Future<List<_ExtractedPage>> _readRar(
    File file,
    Directory destination,
    ExtractionProgress? onProgress,
  ) async {
    // The plugin only extracts whole archives, so RAR is always eager.
    await rarExtractor.extractTo(
      archivePath: file.path,
      destinationPath: destination.path,
    );

    final images = _collectImages(destination);
    final pages = <_ExtractedPage>[];
    onProgress?.call(0, images.length);

    for (var index = 0; index < images.length; index++) {
      final bytes = await images[index].readAsBytes();
      final size = _probeSize(bytes);
      if (size != null) {
        pages.add(
          _ExtractedPage(
            path: images[index].path,
            width: size.$1,
            height: size.$2,
          ),
        );
      }

      onProgress?.call(index + 1, images.length);
      await _breathe(index);
    }

    return pages;
  }

  /// Every image file under [directory], ordered naturally by relative path so
  /// that `page2` comes before `page10` also inside sub-folders.
  static List<File> _collectImages(Directory directory) {
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => _isImage(file.path))
        .toList();

    files.sort(
      (a, b) => naturalCompare(
        p.relative(a.path, from: directory.path),
        p.relative(b.path, from: directory.path),
      ),
    );

    return files;
  }

  // ---------------------------------------------------------------------------
  // Dimensions
  // ---------------------------------------------------------------------------

  /// Reads the image size from its header, without decoding the pixels.
  ///
  /// Fallback to a full decode only if the header cannot be parsed.
  static (int, int)? _probeSize(List<int> bytes) {
    try {
      final decoder = image.findDecoderForData(bytes);
      if (decoder != null) {
        final info = decoder.startDecode(
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        );
        if (info != null && info.width > 0 && info.height > 0) {
          return (info.width, info.height);
        }
      }
    } catch (_) {
      // Fall through to the full decode.
    }

    final decoded = image.decodeImage(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    );
    if (decoded == null) return null;
    return (decoded.width, decoded.height);
  }

  /// Gives the event loop a chance to run, so progress is painted and taps are
  /// handled while a long archive is processed.
  static Future<void> _breathe(int index) async {
    if (index % _yieldEvery != 0) return;
    await Future<void>.delayed(Duration.zero);
  }

  // ---------------------------------------------------------------------------
  // Manifest: instant reopening
  // ---------------------------------------------------------------------------

  /// Identifies the archive content, independent of where it was copied to.
  ///
  /// Size plus a hash of the head and tail: the first bytes carry the local
  /// file header and the last ones the ZIP central directory / RAR end block,
  /// so a changed archive almost always changes the signature. Reading 128 KB
  /// is negligible even for a 300 MB file.
  static Future<String> _signatureOf(File file) async {
    const sample = 64 * 1024;

    final stat = await file.stat();
    final handle = await file.open();
    try {
      final head = await handle.read(sample);
      var tailHash = 0;
      if (stat.size > sample * 2) {
        await handle.setPosition(stat.size - sample);
        tailHash = _fnv1a(await handle.read(sample));
      }
      return '${stat.size}:${_fnv1a(head)}:$tailHash';
    } finally {
      await handle.close();
    }
  }

  /// Removes extraction directories from previous sessions.
  ///
  /// They are temporary by nature: the pages can always be extracted again, and
  /// the OS may clear the directory anyway.
  static Future<void> _cleanUpStaleExtractions(
    Directory comicsRoot, {
    required Directory keep,
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      if (!await comicsRoot.exists()) return;
      final deadline = DateTime.now().subtract(maxAge);

      await for (final entity in comicsRoot.list()) {
        if (entity is! Directory || entity.path == keep.path) continue;
        final modified = (await entity.stat()).modified;
        if (modified.isAfter(deadline)) continue;
        await entity.delete(recursive: true);
      }
    } catch (_) {
      // Best effort.
    }
  }

  static int _fnv1a(List<int> bytes) {
    var hash = 2166136261;
    for (final byte in bytes) {
      hash = (hash ^ byte) * 16777619 & 0x7fffffff;
    }
    return hash;
  }

  /// Returns the pages of a previous extraction, or `null` when there is
  /// nothing reusable.
  ///
  /// When [requireSignature] is given the manifest is only accepted if it was
  /// written for that exact archive content.
  static Future<_Manifest?> _readManifest(
    Directory comicDirectory, {
    String? requireSignature,
  }) async {
    final manifest = File(p.join(comicDirectory.path, _manifestName));
    if (!await manifest.exists()) return null;

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map) return null;
      if (requireSignature != null &&
          decoded['signature'] != requireSignature) {
        return null;
      }

      final raw = decoded['pages'];
      if (raw is! List) return null;

      final pages = <_ExtractedPage>[];
      for (final entry in raw) {
        if (entry is! List || entry.length < 3) return null;
        final path = p.join(comicDirectory.path, entry[0] as String);
        // The OS may clear the temporary directory between sessions, and the
        // user can remove an extraction from the library.
        if (!await File(path).exists()) return null;
        pages.add(
          _ExtractedPage(
            path: path,
            width: entry[1] as int,
            height: entry[2] as int,
          ),
        );
      }

      if (pages.isEmpty) return null;
      return _Manifest(
        title: decoded['title'] as String? ?? '',
        pages: pages,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeManifest(
    Directory comicDirectory,
    String signature,
    String title,
    List<_ExtractedPage> pages,
  ) async {
    final manifest = File(p.join(comicDirectory.path, _manifestName));
    try {
      await manifest.writeAsString(
        jsonEncode({
          'signature': signature,
          'title': title,
          'pages': [
            for (final page in pages)
              [
                p.relative(page.path, from: comicDirectory.path),
                page.width,
                page.height,
              ],
          ],
        }),
      );
    } catch (_) {
      // A missing manifest only costs a slower next open.
    }
  }

  static bool _isImage(String name) {
    final extension = p.extension(name).toLowerCase();
    return _imageExtensions.contains(extension);
  }

  static String _identifierFor(String path, String signature) {
    final base = p.basenameWithoutExtension(path);
    final safeBase = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final hash = _fnv1a(utf8.encode('$safeBase:$signature'));
    return '${safeBase}_${hash.toRadixString(16)}';
  }
}

class _ExtractedPage {
  const _ExtractedPage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// Contents of `.manifest.json`: everything needed to rebuild a [Comic]
/// without touching the archive again.
class _Manifest {
  const _Manifest({required this.title, required this.pages});

  final String title;
  final List<_ExtractedPage> pages;
}
