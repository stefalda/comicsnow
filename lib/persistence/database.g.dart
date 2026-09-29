// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PanelDetectionsTable extends PanelDetections
    with TableInfo<$PanelDetectionsTable, PanelDetectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PanelDetectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _panelOrderMeta = const VerificationMeta(
    'panelOrder',
  );
  @override
  late final GeneratedColumn<int> panelOrder = GeneratedColumn<int>(
    'panel_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftMeta = const VerificationMeta('left');
  @override
  late final GeneratedColumn<double> left = GeneratedColumn<double>(
    'left',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topMeta = const VerificationMeta('top');
  @override
  late final GeneratedColumn<double> top = GeneratedColumn<double>(
    'top',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<bool> isManual = GeneratedColumn<bool>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pageId,
    modelVersion,
    panelOrder,
    left,
    top,
    width,
    height,
    confidence,
    isManual,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'panel_detections';
  @override
  VerificationContext validateIntegrity(
    Insertable<PanelDetectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIdMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('panel_order')) {
      context.handle(
        _panelOrderMeta,
        panelOrder.isAcceptableOrUnknown(data['panel_order']!, _panelOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_panelOrderMeta);
    }
    if (data.containsKey('left')) {
      context.handle(
        _leftMeta,
        left.isAcceptableOrUnknown(data['left']!, _leftMeta),
      );
    } else if (isInserting) {
      context.missing(_leftMeta);
    }
    if (data.containsKey('top')) {
      context.handle(
        _topMeta,
        top.isAcceptableOrUnknown(data['top']!, _topMeta),
      );
    } else if (isInserting) {
      context.missing(_topMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {pageId, modelVersion, panelOrder},
  ];
  @override
  PanelDetectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PanelDetectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      panelOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}panel_order'],
      )!,
      left: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}left'],
      )!,
      top: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual'],
      )!,
    );
  }

  @override
  $PanelDetectionsTable createAlias(String alias) {
    return $PanelDetectionsTable(attachedDatabase, alias);
  }
}

class PanelDetectionRow extends DataClass
    implements Insertable<PanelDetectionRow> {
  final int id;
  final String pageId;
  final String modelVersion;
  final int panelOrder;
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
  final bool isManual;
  const PanelDetectionRow({
    required this.id,
    required this.pageId,
    required this.modelVersion,
    required this.panelOrder,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    required this.isManual,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['page_id'] = Variable<String>(pageId);
    map['model_version'] = Variable<String>(modelVersion);
    map['panel_order'] = Variable<int>(panelOrder);
    map['left'] = Variable<double>(left);
    map['top'] = Variable<double>(top);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['confidence'] = Variable<double>(confidence);
    map['is_manual'] = Variable<bool>(isManual);
    return map;
  }

  PanelDetectionsCompanion toCompanion(bool nullToAbsent) {
    return PanelDetectionsCompanion(
      id: Value(id),
      pageId: Value(pageId),
      modelVersion: Value(modelVersion),
      panelOrder: Value(panelOrder),
      left: Value(left),
      top: Value(top),
      width: Value(width),
      height: Value(height),
      confidence: Value(confidence),
      isManual: Value(isManual),
    );
  }

  factory PanelDetectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PanelDetectionRow(
      id: serializer.fromJson<int>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      panelOrder: serializer.fromJson<int>(json['panelOrder']),
      left: serializer.fromJson<double>(json['left']),
      top: serializer.fromJson<double>(json['top']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      confidence: serializer.fromJson<double>(json['confidence']),
      isManual: serializer.fromJson<bool>(json['isManual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pageId': serializer.toJson<String>(pageId),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'panelOrder': serializer.toJson<int>(panelOrder),
      'left': serializer.toJson<double>(left),
      'top': serializer.toJson<double>(top),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'confidence': serializer.toJson<double>(confidence),
      'isManual': serializer.toJson<bool>(isManual),
    };
  }

  PanelDetectionRow copyWith({
    int? id,
    String? pageId,
    String? modelVersion,
    int? panelOrder,
    double? left,
    double? top,
    double? width,
    double? height,
    double? confidence,
    bool? isManual,
  }) => PanelDetectionRow(
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    modelVersion: modelVersion ?? this.modelVersion,
    panelOrder: panelOrder ?? this.panelOrder,
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
    confidence: confidence ?? this.confidence,
    isManual: isManual ?? this.isManual,
  );
  PanelDetectionRow copyWithCompanion(PanelDetectionsCompanion data) {
    return PanelDetectionRow(
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      panelOrder: data.panelOrder.present
          ? data.panelOrder.value
          : this.panelOrder,
      left: data.left.present ? data.left.value : this.left,
      top: data.top.present ? data.top.value : this.top,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PanelDetectionRow(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('panelOrder: $panelOrder, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('confidence: $confidence, ')
          ..write('isManual: $isManual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pageId,
    modelVersion,
    panelOrder,
    left,
    top,
    width,
    height,
    confidence,
    isManual,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PanelDetectionRow &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.modelVersion == this.modelVersion &&
          other.panelOrder == this.panelOrder &&
          other.left == this.left &&
          other.top == this.top &&
          other.width == this.width &&
          other.height == this.height &&
          other.confidence == this.confidence &&
          other.isManual == this.isManual);
}

class PanelDetectionsCompanion extends UpdateCompanion<PanelDetectionRow> {
  final Value<int> id;
  final Value<String> pageId;
  final Value<String> modelVersion;
  final Value<int> panelOrder;
  final Value<double> left;
  final Value<double> top;
  final Value<double> width;
  final Value<double> height;
  final Value<double> confidence;
  final Value<bool> isManual;
  const PanelDetectionsCompanion({
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.panelOrder = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.confidence = const Value.absent(),
    this.isManual = const Value.absent(),
  });
  PanelDetectionsCompanion.insert({
    this.id = const Value.absent(),
    required String pageId,
    required String modelVersion,
    required int panelOrder,
    required double left,
    required double top,
    required double width,
    required double height,
    required double confidence,
    this.isManual = const Value.absent(),
  }) : pageId = Value(pageId),
       modelVersion = Value(modelVersion),
       panelOrder = Value(panelOrder),
       left = Value(left),
       top = Value(top),
       width = Value(width),
       height = Value(height),
       confidence = Value(confidence);
  static Insertable<PanelDetectionRow> custom({
    Expression<int>? id,
    Expression<String>? pageId,
    Expression<String>? modelVersion,
    Expression<int>? panelOrder,
    Expression<double>? left,
    Expression<double>? top,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? confidence,
    Expression<bool>? isManual,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (modelVersion != null) 'model_version': modelVersion,
      if (panelOrder != null) 'panel_order': panelOrder,
      if (left != null) 'left': left,
      if (top != null) 'top': top,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (confidence != null) 'confidence': confidence,
      if (isManual != null) 'is_manual': isManual,
    });
  }

  PanelDetectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? pageId,
    Value<String>? modelVersion,
    Value<int>? panelOrder,
    Value<double>? left,
    Value<double>? top,
    Value<double>? width,
    Value<double>? height,
    Value<double>? confidence,
    Value<bool>? isManual,
  }) {
    return PanelDetectionsCompanion(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      modelVersion: modelVersion ?? this.modelVersion,
      panelOrder: panelOrder ?? this.panelOrder,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      isManual: isManual ?? this.isManual,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (panelOrder.present) {
      map['panel_order'] = Variable<int>(panelOrder.value);
    }
    if (left.present) {
      map['left'] = Variable<double>(left.value);
    }
    if (top.present) {
      map['top'] = Variable<double>(top.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<bool>(isManual.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PanelDetectionsCompanion(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('panelOrder: $panelOrder, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('confidence: $confidence, ')
          ..write('isManual: $isManual')
          ..write(')'))
        .toString();
  }
}

class $RecentComicsTable extends RecentComics
    with TableInfo<$RecentComicsTable, RecentComicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentComicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivePathMeta = const VerificationMeta(
    'archivePath',
  );
  @override
  late final GeneratedColumn<String> archivePath = GeneratedColumn<String>(
    'archive_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    coverPath,
    pageCount,
    archivePath,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_comics';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentComicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('archive_path')) {
      context.handle(
        _archivePathMeta,
        archivePath.isAcceptableOrUnknown(
          data['archive_path']!,
          _archivePathMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentComicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentComicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      archivePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_path'],
      ),
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
    );
  }

  @override
  $RecentComicsTable createAlias(String alias) {
    return $RecentComicsTable(attachedDatabase, alias);
  }
}

class RecentComicRow extends DataClass implements Insertable<RecentComicRow> {
  /// Content-based comic id, so the entry survives the file being copied
  /// elsewhere (which is what the file picker does on mobile).
  final String id;
  final String title;
  final String? coverPath;
  final int pageCount;

  /// Where the archive can be read again to rebuild the extracted pages.
  ///
  /// On mobile it is the app's own copy of the picked file (the picker's cache
  /// copy is moved here, so it costs no extra space); on desktop it can be the
  /// user's original file. `null` for entries registered before this existed.
  final String? archivePath;
  final DateTime lastOpenedAt;
  const RecentComicRow({
    required this.id,
    required this.title,
    this.coverPath,
    required this.pageCount,
    this.archivePath,
    required this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['page_count'] = Variable<int>(pageCount);
    if (!nullToAbsent || archivePath != null) {
      map['archive_path'] = Variable<String>(archivePath);
    }
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    return map;
  }

  RecentComicsCompanion toCompanion(bool nullToAbsent) {
    return RecentComicsCompanion(
      id: Value(id),
      title: Value(title),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      pageCount: Value(pageCount),
      archivePath: archivePath == null && nullToAbsent
          ? const Value.absent()
          : Value(archivePath),
      lastOpenedAt: Value(lastOpenedAt),
    );
  }

  factory RecentComicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentComicRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      archivePath: serializer.fromJson<String?>(json['archivePath']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'coverPath': serializer.toJson<String?>(coverPath),
      'pageCount': serializer.toJson<int>(pageCount),
      'archivePath': serializer.toJson<String?>(archivePath),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
    };
  }

  RecentComicRow copyWith({
    String? id,
    String? title,
    Value<String?> coverPath = const Value.absent(),
    int? pageCount,
    Value<String?> archivePath = const Value.absent(),
    DateTime? lastOpenedAt,
  }) => RecentComicRow(
    id: id ?? this.id,
    title: title ?? this.title,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    pageCount: pageCount ?? this.pageCount,
    archivePath: archivePath.present ? archivePath.value : this.archivePath,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );
  RecentComicRow copyWithCompanion(RecentComicsCompanion data) {
    return RecentComicRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      archivePath: data.archivePath.present
          ? data.archivePath.value
          : this.archivePath,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentComicRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('coverPath: $coverPath, ')
          ..write('pageCount: $pageCount, ')
          ..write('archivePath: $archivePath, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, coverPath, pageCount, archivePath, lastOpenedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentComicRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.coverPath == this.coverPath &&
          other.pageCount == this.pageCount &&
          other.archivePath == this.archivePath &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class RecentComicsCompanion extends UpdateCompanion<RecentComicRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> coverPath;
  final Value<int> pageCount;
  final Value<String?> archivePath;
  final Value<DateTime> lastOpenedAt;
  final Value<int> rowid;
  const RecentComicsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.archivePath = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentComicsCompanion.insert({
    required String id,
    required String title,
    this.coverPath = const Value.absent(),
    required int pageCount,
    this.archivePath = const Value.absent(),
    required DateTime lastOpenedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       pageCount = Value(pageCount),
       lastOpenedAt = Value(lastOpenedAt);
  static Insertable<RecentComicRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? coverPath,
    Expression<int>? pageCount,
    Expression<String>? archivePath,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (coverPath != null) 'cover_path': coverPath,
      if (pageCount != null) 'page_count': pageCount,
      if (archivePath != null) 'archive_path': archivePath,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentComicsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? coverPath,
    Value<int>? pageCount,
    Value<String?>? archivePath,
    Value<DateTime>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return RecentComicsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      coverPath: coverPath ?? this.coverPath,
      pageCount: pageCount ?? this.pageCount,
      archivePath: archivePath ?? this.archivePath,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (archivePath.present) {
      map['archive_path'] = Variable<String>(archivePath.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentComicsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('coverPath: $coverPath, ')
          ..write('pageCount: $pageCount, ')
          ..write('archivePath: $archivePath, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ComicDatabase extends GeneratedDatabase {
  _$ComicDatabase(QueryExecutor e) : super(e);
  $ComicDatabaseManager get managers => $ComicDatabaseManager(this);
  late final $PanelDetectionsTable panelDetections = $PanelDetectionsTable(
    this,
  );
  late final $RecentComicsTable recentComics = $RecentComicsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    panelDetections,
    recentComics,
  ];
}

typedef $$PanelDetectionsTableCreateCompanionBuilder =
    PanelDetectionsCompanion Function({
      Value<int> id,
      required String pageId,
      required String modelVersion,
      required int panelOrder,
      required double left,
      required double top,
      required double width,
      required double height,
      required double confidence,
      Value<bool> isManual,
    });
typedef $$PanelDetectionsTableUpdateCompanionBuilder =
    PanelDetectionsCompanion Function({
      Value<int> id,
      Value<String> pageId,
      Value<String> modelVersion,
      Value<int> panelOrder,
      Value<double> left,
      Value<double> top,
      Value<double> width,
      Value<double> height,
      Value<double> confidence,
      Value<bool> isManual,
    });

class $$PanelDetectionsTableFilterComposer
    extends Composer<_$ComicDatabase, $PanelDetectionsTable> {
  $$PanelDetectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get panelOrder => $composableBuilder(
    column: $table.panelOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PanelDetectionsTableOrderingComposer
    extends Composer<_$ComicDatabase, $PanelDetectionsTable> {
  $$PanelDetectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageId => $composableBuilder(
    column: $table.pageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get panelOrder => $composableBuilder(
    column: $table.panelOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PanelDetectionsTableAnnotationComposer
    extends Composer<_$ComicDatabase, $PanelDetectionsTable> {
  $$PanelDetectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pageId =>
      $composableBuilder(column: $table.pageId, builder: (column) => column);

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get panelOrder => $composableBuilder(
    column: $table.panelOrder,
    builder: (column) => column,
  );

  GeneratedColumn<double> get left =>
      $composableBuilder(column: $table.left, builder: (column) => column);

  GeneratedColumn<double> get top =>
      $composableBuilder(column: $table.top, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);
}

class $$PanelDetectionsTableTableManager
    extends
        RootTableManager<
          _$ComicDatabase,
          $PanelDetectionsTable,
          PanelDetectionRow,
          $$PanelDetectionsTableFilterComposer,
          $$PanelDetectionsTableOrderingComposer,
          $$PanelDetectionsTableAnnotationComposer,
          $$PanelDetectionsTableCreateCompanionBuilder,
          $$PanelDetectionsTableUpdateCompanionBuilder,
          (
            PanelDetectionRow,
            BaseReferences<
              _$ComicDatabase,
              $PanelDetectionsTable,
              PanelDetectionRow
            >,
          ),
          PanelDetectionRow,
          PrefetchHooks Function()
        > {
  $$PanelDetectionsTableTableManager(
    _$ComicDatabase db,
    $PanelDetectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PanelDetectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PanelDetectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PanelDetectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<int> panelOrder = const Value.absent(),
                Value<double> left = const Value.absent(),
                Value<double> top = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
              }) => PanelDetectionsCompanion(
                id: id,
                pageId: pageId,
                modelVersion: modelVersion,
                panelOrder: panelOrder,
                left: left,
                top: top,
                width: width,
                height: height,
                confidence: confidence,
                isManual: isManual,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pageId,
                required String modelVersion,
                required int panelOrder,
                required double left,
                required double top,
                required double width,
                required double height,
                required double confidence,
                Value<bool> isManual = const Value.absent(),
              }) => PanelDetectionsCompanion.insert(
                id: id,
                pageId: pageId,
                modelVersion: modelVersion,
                panelOrder: panelOrder,
                left: left,
                top: top,
                width: width,
                height: height,
                confidence: confidence,
                isManual: isManual,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PanelDetectionsTable, PanelDetectionRow>(table),
                  BaseReferences<
                    _$ComicDatabase,
                    $PanelDetectionsTable,
                    PanelDetectionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PanelDetectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ComicDatabase,
      $PanelDetectionsTable,
      PanelDetectionRow,
      $$PanelDetectionsTableFilterComposer,
      $$PanelDetectionsTableOrderingComposer,
      $$PanelDetectionsTableAnnotationComposer,
      $$PanelDetectionsTableCreateCompanionBuilder,
      $$PanelDetectionsTableUpdateCompanionBuilder,
      (
        PanelDetectionRow,
        BaseReferences<
          _$ComicDatabase,
          $PanelDetectionsTable,
          PanelDetectionRow
        >,
      ),
      PanelDetectionRow,
      PrefetchHooks Function()
    >;
typedef $$RecentComicsTableCreateCompanionBuilder =
    RecentComicsCompanion Function({
      required String id,
      required String title,
      Value<String?> coverPath,
      required int pageCount,
      Value<String?> archivePath,
      required DateTime lastOpenedAt,
      Value<int> rowid,
    });
typedef $$RecentComicsTableUpdateCompanionBuilder =
    RecentComicsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> coverPath,
      Value<int> pageCount,
      Value<String?> archivePath,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });

class $$RecentComicsTableFilterComposer
    extends Composer<_$ComicDatabase, $RecentComicsTable> {
  $$RecentComicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivePath => $composableBuilder(
    column: $table.archivePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentComicsTableOrderingComposer
    extends Composer<_$ComicDatabase, $RecentComicsTable> {
  $$RecentComicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivePath => $composableBuilder(
    column: $table.archivePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentComicsTableAnnotationComposer
    extends Composer<_$ComicDatabase, $RecentComicsTable> {
  $$RecentComicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get archivePath => $composableBuilder(
    column: $table.archivePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$RecentComicsTableTableManager
    extends
        RootTableManager<
          _$ComicDatabase,
          $RecentComicsTable,
          RecentComicRow,
          $$RecentComicsTableFilterComposer,
          $$RecentComicsTableOrderingComposer,
          $$RecentComicsTableAnnotationComposer,
          $$RecentComicsTableCreateCompanionBuilder,
          $$RecentComicsTableUpdateCompanionBuilder,
          (
            RecentComicRow,
            BaseReferences<_$ComicDatabase, $RecentComicsTable, RecentComicRow>,
          ),
          RecentComicRow,
          PrefetchHooks Function()
        > {
  $$RecentComicsTableTableManager(_$ComicDatabase db, $RecentComicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentComicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentComicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentComicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String?> archivePath = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentComicsCompanion(
                id: id,
                title: title,
                coverPath: coverPath,
                pageCount: pageCount,
                archivePath: archivePath,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> coverPath = const Value.absent(),
                required int pageCount,
                Value<String?> archivePath = const Value.absent(),
                required DateTime lastOpenedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentComicsCompanion.insert(
                id: id,
                title: title,
                coverPath: coverPath,
                pageCount: pageCount,
                archivePath: archivePath,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentComicsTable, RecentComicRow>(table),
                  BaseReferences<
                    _$ComicDatabase,
                    $RecentComicsTable,
                    RecentComicRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentComicsTableProcessedTableManager =
    ProcessedTableManager<
      _$ComicDatabase,
      $RecentComicsTable,
      RecentComicRow,
      $$RecentComicsTableFilterComposer,
      $$RecentComicsTableOrderingComposer,
      $$RecentComicsTableAnnotationComposer,
      $$RecentComicsTableCreateCompanionBuilder,
      $$RecentComicsTableUpdateCompanionBuilder,
      (
        RecentComicRow,
        BaseReferences<_$ComicDatabase, $RecentComicsTable, RecentComicRow>,
      ),
      RecentComicRow,
      PrefetchHooks Function()
    >;

class $ComicDatabaseManager {
  final _$ComicDatabase _db;
  $ComicDatabaseManager(this._db);
  $$PanelDetectionsTableTableManager get panelDetections =>
      $$PanelDetectionsTableTableManager(_db, _db.panelDetections);
  $$RecentComicsTableTableManager get recentComics =>
      $$RecentComicsTableTableManager(_db, _db.recentComics);
}
