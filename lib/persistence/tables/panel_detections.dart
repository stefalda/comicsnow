import 'package:drift/drift.dart';

/// Cached panel detections.
///
/// The cache key is `(pageId, modelVersion)`: switching model version must not
/// silently reuse detections produced by an older model.
@DataClassName('PanelDetectionRow')
class PanelDetections extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get pageId => text()();

  TextColumn get modelVersion => text()();

  IntColumn get panelOrder => integer()();

  RealColumn get left => real()();

  RealColumn get top => real()();

  RealColumn get width => real()();

  RealColumn get height => real()();

  RealColumn get confidence => real()();

  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {pageId, modelVersion, panelOrder},
  ];
}
