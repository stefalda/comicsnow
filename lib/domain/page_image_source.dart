import 'dart:typed_data';

import 'comic_page.dart';

/// Loads the raw bytes of a page image.
///
/// This small interface lives in the domain layer so that services such as the
/// analysis pipeline can read page bytes without depending on `dart:io` or on
/// Flutter's image widgets.
abstract interface class PageImageSource {
  Future<Uint8List> readBytes(ComicPage page);
}
