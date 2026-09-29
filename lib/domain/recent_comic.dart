/// A comic the user opened at least once.
///
/// The pages of a recently opened comic are already extracted on disk, so it
/// can be reopened without the original archive — as long as the extraction was
/// not cleaned up (see [ComicArchiveReader.reopen]).
class RecentComic {
  const RecentComic({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.lastOpenedAt,
    this.coverPath,
    this.archivePath,
  });

  /// Content-based identifier of the comic (see `ComicArchiveReader`).
  final String id;

  final String title;

  final int pageCount;

  final DateTime lastOpenedAt;

  /// Path of a small cover image stored by the app, when available.
  final String? coverPath;

  /// Where the archive can be read again to rebuild the extracted pages.
  final String? archivePath;

  /// Reading progress in `0..1` given the last page reached.
  double progressFor(int? lastPage) {
    if (pageCount <= 0 || lastPage == null) return 0;
    return ((lastPage + 1) / pageCount).clamp(0.0, 1.0);
  }

  @override
  String toString() => 'RecentComic($id, $title, $pageCount pagine)';
}
