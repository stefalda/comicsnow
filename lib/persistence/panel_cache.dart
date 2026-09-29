import 'dart:ui';

import 'package:drift/drift.dart';

import '../domain/comic_panel.dart';
import 'database.dart';

/// Persistence boundary for panel detections.
///
/// Nothing outside this file knows Drift exists.
class PanelCache {
  PanelCache(this.database);

  final ComicDatabase database;

  /// Returns the cached panels for [pageId] + [modelVersion], or `null` when
  /// the page has never been analysed with this model version.
  Future<List<ComicPanel>?> get({
    required String pageId,
    required String modelVersion,
  }) async {
    final query = database.select(database.panelDetections)
      ..where(
        (table) =>
            table.pageId.equals(pageId) &
            table.modelVersion.equals(modelVersion),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.panelOrder)]);

    final rows = await query.get();
    if (rows.isEmpty) {
      return null;
    }

    return [
      for (final row in rows)
        ComicPanel(
          id: row.id.toString(),
          bounds: Rect.fromLTWH(row.left, row.top, row.width, row.height),
          confidence: row.confidence,
          order: row.panelOrder,
          isManual: row.isManual,
        ),
    ];
  }

  /// Replaces the cached panels for [pageId] + [modelVersion].
  Future<void> save({
    required String pageId,
    required String modelVersion,
    required List<ComicPanel> panels,
  }) async {
    await database.transaction(() async {
      await delete(pageId: pageId, modelVersion: modelVersion);

      await database.batch((batch) {
        batch.insertAll(
          database.panelDetections,
          [
            for (final panel in panels)
              PanelDetectionsCompanion.insert(
                pageId: pageId,
                modelVersion: modelVersion,
                panelOrder: panel.order,
                left: panel.bounds.left,
                top: panel.bounds.top,
                width: panel.bounds.width,
                height: panel.bounds.height,
                confidence: panel.confidence,
                isManual: Value(panel.isManual),
              ),
          ],
        );
      });
    });
  }

  /// Removes every cached detection for a page, regardless of model version.
  Future<void> delete({required String pageId, String? modelVersion}) {
    final statement = database.delete(database.panelDetections)
      ..where((table) => table.pageId.equals(pageId));

    if (modelVersion != null) {
      statement.where((table) => table.modelVersion.equals(modelVersion));
    }

    return statement.go();
  }
}
