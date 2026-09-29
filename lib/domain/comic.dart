import 'comic_page.dart';

/// A comic, i.e. an ordered collection of [ComicPage]s.
class Comic {
  const Comic({
    required this.id,
    required this.title,
    required this.pages,
    this.sourcePath,
  });

  final String id;
  final String title;
  final List<ComicPage> pages;

  /// Where the comic was opened from, when it comes from a file.
  final String? sourcePath;

  bool get isEmpty => pages.isEmpty;

  int get pageCount => pages.length;

  Comic copyWith({
    String? id,
    String? title,
    List<ComicPage>? pages,
    String? sourcePath,
  }) {
    return Comic(
      id: id ?? this.id,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  @override
  String toString() => 'Comic(id=$id, title=$title, pages=${pages.length})';
}
