import 'package:drift/drift.dart';

/// Comics the user opened, shown in the library grid.
@DataClassName('RecentComicRow')
class RecentComics extends Table {
  /// Content-based comic id, so the entry survives the file being copied
  /// elsewhere (which is what the file picker does on mobile).
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get coverPath => text().nullable()();

  IntColumn get pageCount => integer()();

  /// Where the archive can be read again to rebuild the extracted pages.
  ///
  /// On mobile it is the app's own copy of the picked file (the picker's cache
  /// copy is moved here, so it costs no extra space); on desktop it can be the
  /// user's original file. `null` for entries registered before this existed.
  TextColumn get archivePath => text().nullable()();

  DateTimeColumn get lastOpenedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
