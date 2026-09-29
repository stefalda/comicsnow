import 'dart:ui';

import 'comic_panel.dart';

/// A single page of a comic.
///
/// The page points at an image on disk instead of holding the full bitmap in
/// memory: a CBZ with hundreds of pages must not be loaded all at once.
class ComicPage {
  const ComicPage({
    required this.id,
    required this.index,
    required this.imagePath,
    required this.width,
    required this.height,
    this.panels = const [],
  });

  /// Stable identifier, unique inside a comic.
  final String id;

  /// Zero-based position inside the comic.
  final int index;

  /// Absolute path to the extracted page image.
  final String imagePath;

  /// Width of the page image, in pixels.
  final int width;

  /// Height of the page image, in pixels.
  final int height;

  /// Panels, already ordered for reading. Empty until analysis ran.
  final List<ComicPanel> panels;

  Size get size => Size(width.toDouble(), height.toDouble());

  bool get hasPanels => panels.isNotEmpty;

  ComicPage copyWith({
    String? id,
    int? index,
    String? imagePath,
    int? width,
    int? height,
    List<ComicPanel>? panels,
  }) {
    return ComicPage(
      id: id ?? this.id,
      index: index ?? this.index,
      imagePath: imagePath ?? this.imagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      panels: panels ?? this.panels,
    );
  }

  @override
  String toString() =>
      'ComicPage(id=$id, index=$index, ${width}x$height, '
      'panels=${panels.length})';
}
