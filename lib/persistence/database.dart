import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/panel_detections.dart';
import 'tables/recent_comics.dart';

part 'database.g.dart';

@DriftDatabase(tables: [PanelDetections, RecentComics])
class ComicDatabase extends _$ComicDatabase {
  /// Opens the on-device database.
  ComicDatabase() : super(_openConnection());

  /// Used by tests to inject an in-memory executor.
  ComicDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 added the library of recently opened comics.
      if (from < 2) {
        await m.createTable(recentComics);
      }
      // v3 remembers where each comic can be read again from.
      if (from < 3 && from >= 2) {
        await m.addColumn(recentComics, recentComics.archivePath);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'comic_reader');
}
