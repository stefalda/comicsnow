import 'package:drift/drift.dart';

import '../domain/recent_comic.dart';
import 'database.dart';

/// Persistence boundary for the library of recently opened comics.
///
/// Nothing outside this file knows Drift exists.
class RecentComicsStore {
  RecentComicsStore(this.database);

  final ComicDatabase database;

  /// Recent comics, most recently opened first.
  Future<List<RecentComic>> list({int limit = 60}) async {
    final query = database.select(database.recentComics)
      ..orderBy([
        (table) => OrderingTerm.desc(table.lastOpenedAt),
        // Drift stores DateTime with second resolution: the id keeps the order
        // deterministic when two comics are opened in the same second.
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(limit);

    final rows = await query.get();
    return [
      for (final row in rows)
        RecentComic(
          id: row.id,
          title: row.title,
          pageCount: row.pageCount,
          lastOpenedAt: row.lastOpenedAt,
          coverPath: row.coverPath,
          archivePath: row.archivePath,
        ),
    ];
  }

  Future<RecentComic?> find(String id) async {
    final query = database.select(database.recentComics)
      ..where((table) => table.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return RecentComic(
      id: row.id,
      title: row.title,
      pageCount: row.pageCount,
      lastOpenedAt: row.lastOpenedAt,
      coverPath: row.coverPath,
      archivePath: row.archivePath,
    );
  }

  /// Records that [id] was opened.
  ///
  /// Missing values keep whatever was stored before (a cover is generated once
  /// and must not be dropped by a later open that has none yet).
  Future<void> touch({
    required String id,
    required String title,
    required int pageCount,
    String? coverPath,
    String? archivePath,
    DateTime? openedAt,
  }) async {
    final existing = await find(id);

    await database
        .into(database.recentComics)
        .insertOnConflictUpdate(
          RecentComicsCompanion.insert(
            id: id,
            title: title,
            pageCount: pageCount > 0 ? pageCount : (existing?.pageCount ?? 0),
            lastOpenedAt: openedAt ?? DateTime.now(),
            coverPath: Value(coverPath ?? existing?.coverPath),
            archivePath: Value(archivePath ?? existing?.archivePath),
          ),
        );
  }

  /// Removes a comic from the library.
  Future<void> remove(String id) async {
    await (database.delete(
      database.recentComics,
    )..where((table) => table.id.equals(id))).go();
  }
}
