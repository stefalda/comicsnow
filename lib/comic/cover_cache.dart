import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores a small cover image per comic, used by the library grid.
///
/// Covers live in the app's documents directory, not next to the extracted
/// pages: the extraction directory is temporary and the OS may clear it, while
/// the cover should survive.
class CoverCache {
  CoverCache({Future<Directory> Function()? directory})
    : _baseDirectory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Covers are never wider than this; the grid shows them small.
  static const maxWidth = 400;

  /// Renders a cover for [comicId] from [pagePath] and returns its path, or
  /// `null` if the page cannot be read.
  Future<String?> store({
    required String comicId,
    required String pagePath,
  }) async {
    try {
      final bytes = await File(pagePath).readAsBytes();
      final decoded = image.decodeImage(bytes);
      if (decoded == null) return null;

      final cover = decoded.width > maxWidth
          ? image.copyResize(
              decoded,
              width: maxWidth,
              interpolation: image.Interpolation.average,
            )
          : decoded;

      final file = await _fileFor(comicId);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(image.encodeJpg(cover, quality: 82), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String comicId) async {
    try {
      final file = await _fileFor(comicId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<File> _fileFor(String comicId) async {
    final base = await _baseDirectory();
    return File(p.join(base.path, 'comicsnow', 'covers', '$comicId.jpg'));
  }
}
