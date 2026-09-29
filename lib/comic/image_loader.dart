import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/comic_page.dart';
import '../domain/page_image_source.dart';

/// Loads page images from disk, with a small in-memory byte cache.
///
/// [readBytes] is used by the analysis pipeline (which needs raw bytes), while
/// [provider] is used by the UI and lets Flutter's own `ImageCache` handle the
/// decoded bitmaps.
class ImageLoader implements PageImageSource {
  ImageLoader({this.maxCachedPages = 6});

  /// Number of decoded *raw byte buffers* kept around. Keep this small: a page
  /// can be tens of megabytes.
  final int maxCachedPages;

  final _bytes = <String, Uint8List>{};
  final _order = <String>[];

  @override
  Future<Uint8List> readBytes(ComicPage page) async {
    final cached = _bytes[page.id];
    if (cached != null) {
      _touch(page.id);
      return cached;
    }

    final bytes = await File(page.imagePath).readAsBytes();
    _store(page.id, bytes);
    return bytes;
  }

  /// An [ImageProvider] for the page image.
  ImageProvider provider(ComicPage page) => FileImage(File(page.imagePath));

  /// Drops a page from the byte cache.
  void evict(String pageId) {
    _bytes.remove(pageId);
    _order.remove(pageId);
  }

  /// Clears the whole byte cache.
  void clear() {
    _bytes.clear();
    _order.clear();
  }

  void _store(String pageId, Uint8List bytes) {
    _bytes[pageId] = bytes;
    _touch(pageId);

    while (_order.length > maxCachedPages) {
      final evicted = _order.removeAt(0);
      _bytes.remove(evicted);
    }
  }

  void _touch(String pageId) {
    _order.remove(pageId);
    _order.add(pageId);
  }
}
