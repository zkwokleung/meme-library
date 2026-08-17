// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MemesTable extends Memes with TableInfo<$MemesTable, MemeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sha256,
    mimeType,
    width,
    height,
    sizeBytes,
    relativePath,
    thumbnailPath,
    sourceKind,
    sourceRef,
    title,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
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
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thumbnailPathMeta);
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MemesTable createAlias(String alias) {
    return $MemesTable(attachedDatabase, alias);
  }
}

class MemeRow extends DataClass implements Insertable<MemeRow> {
  final String id;
  final String sha256;
  final String mimeType;
  final int width;
  final int height;
  final int sizeBytes;
  final String relativePath;
  final String thumbnailPath;
  final String sourceKind;
  final String? sourceRef;
  final String? title;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  const MemeRow({
    required this.id,
    required this.sha256,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.relativePath,
    required this.thumbnailPath,
    required this.sourceKind,
    this.sourceRef,
    this.title,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sha256'] = Variable<String>(sha256);
    map['mime_type'] = Variable<String>(mimeType);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['relative_path'] = Variable<String>(relativePath);
    map['thumbnail_path'] = Variable<String>(thumbnailPath);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MemesCompanion toCompanion(bool nullToAbsent) {
    return MemesCompanion(
      id: Value(id),
      sha256: Value(sha256),
      mimeType: Value(mimeType),
      width: Value(width),
      height: Value(height),
      sizeBytes: Value(sizeBytes),
      relativePath: Value(relativePath),
      thumbnailPath: Value(thumbnailPath),
      sourceKind: Value(sourceKind),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemeRow(
      id: serializer.fromJson<String>(json['id']),
      sha256: serializer.fromJson<String>(json['sha256']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      thumbnailPath: serializer.fromJson<String>(json['thumbnailPath']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      title: serializer.fromJson<String?>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sha256': serializer.toJson<String>(sha256),
      'mimeType': serializer.toJson<String>(mimeType),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'relativePath': serializer.toJson<String>(relativePath),
      'thumbnailPath': serializer.toJson<String>(thumbnailPath),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'title': serializer.toJson<String?>(title),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MemeRow copyWith({
    String? id,
    String? sha256,
    String? mimeType,
    int? width,
    int? height,
    int? sizeBytes,
    String? relativePath,
    String? thumbnailPath,
    String? sourceKind,
    Value<String?> sourceRef = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => MemeRow(
    id: id ?? this.id,
    sha256: sha256 ?? this.sha256,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    relativePath: relativePath ?? this.relativePath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    title: title.present ? title.value : this.title,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MemeRow copyWithCompanion(MemesCompanion data) {
    return MemeRow(
      id: data.id.present ? data.id.value : this.id,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemeRow(')
          ..write('id: $id, ')
          ..write('sha256: $sha256, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('relativePath: $relativePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sha256,
    mimeType,
    width,
    height,
    sizeBytes,
    relativePath,
    thumbnailPath,
    sourceKind,
    sourceRef,
    title,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemeRow &&
          other.id == this.id &&
          other.sha256 == this.sha256 &&
          other.mimeType == this.mimeType &&
          other.width == this.width &&
          other.height == this.height &&
          other.sizeBytes == this.sizeBytes &&
          other.relativePath == this.relativePath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.sourceKind == this.sourceKind &&
          other.sourceRef == this.sourceRef &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MemesCompanion extends UpdateCompanion<MemeRow> {
  final Value<String> id;
  final Value<String> sha256;
  final Value<String> mimeType;
  final Value<int> width;
  final Value<int> height;
  final Value<int> sizeBytes;
  final Value<String> relativePath;
  final Value<String> thumbnailPath;
  final Value<String> sourceKind;
  final Value<String?> sourceRef;
  final Value<String?> title;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MemesCompanion({
    this.id = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemesCompanion.insert({
    required String id,
    required String sha256,
    required String mimeType,
    required int width,
    required int height,
    required int sizeBytes,
    required String relativePath,
    required String thumbnailPath,
    required String sourceKind,
    this.sourceRef = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sha256 = Value(sha256),
       mimeType = Value(mimeType),
       width = Value(width),
       height = Value(height),
       sizeBytes = Value(sizeBytes),
       relativePath = Value(relativePath),
       thumbnailPath = Value(thumbnailPath),
       sourceKind = Value(sourceKind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemeRow> custom({
    Expression<String>? id,
    Expression<String>? sha256,
    Expression<String>? mimeType,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sizeBytes,
    Expression<String>? relativePath,
    Expression<String>? thumbnailPath,
    Expression<String>? sourceKind,
    Expression<String>? sourceRef,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sha256 != null) 'sha256': sha256,
      if (mimeType != null) 'mime_type': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (relativePath != null) 'relative_path': relativePath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemesCompanion copyWith({
    Value<String>? id,
    Value<String>? sha256,
    Value<String>? mimeType,
    Value<int>? width,
    Value<int>? height,
    Value<int>? sizeBytes,
    Value<String>? relativePath,
    Value<String>? thumbnailPath,
    Value<String>? sourceKind,
    Value<String?>? sourceRef,
    Value<String?>? title,
    Value<String?>? notes,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MemesCompanion(
      id: id ?? this.id,
      sha256: sha256 ?? this.sha256,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      relativePath: relativePath ?? this.relativePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceRef: sourceRef ?? this.sourceRef,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemesCompanion(')
          ..write('id: $id, ')
          ..write('sha256: $sha256, ')
          ..write('mimeType: $mimeType, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('relativePath: $relativePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String name;
  final String normalizedName;
  const TagRow({
    required this.id,
    required this.name,
    required this.normalizedName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
    };
  }

  TagRow copyWith({String? id, String? name, String? normalizedName}) => TagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemeTagsTable extends MemeTags
    with TableInfo<$MemeTagsTable, MemeTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemeTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [memeId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meme_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemeTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {memeId, tagId};
  @override
  MemeTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemeTagRow(
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $MemeTagsTable createAlias(String alias) {
    return $MemeTagsTable(attachedDatabase, alias);
  }
}

class MemeTagRow extends DataClass implements Insertable<MemeTagRow> {
  final String memeId;
  final String tagId;
  const MemeTagRow({required this.memeId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meme_id'] = Variable<String>(memeId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  MemeTagsCompanion toCompanion(bool nullToAbsent) {
    return MemeTagsCompanion(memeId: Value(memeId), tagId: Value(tagId));
  }

  factory MemeTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemeTagRow(
      memeId: serializer.fromJson<String>(json['memeId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'memeId': serializer.toJson<String>(memeId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  MemeTagRow copyWith({String? memeId, String? tagId}) =>
      MemeTagRow(memeId: memeId ?? this.memeId, tagId: tagId ?? this.tagId);
  MemeTagRow copyWithCompanion(MemeTagsCompanion data) {
    return MemeTagRow(
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemeTagRow(')
          ..write('memeId: $memeId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(memeId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemeTagRow &&
          other.memeId == this.memeId &&
          other.tagId == this.tagId);
}

class MemeTagsCompanion extends UpdateCompanion<MemeTagRow> {
  final Value<String> memeId;
  final Value<String> tagId;
  final Value<int> rowid;
  const MemeTagsCompanion({
    this.memeId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemeTagsCompanion.insert({
    required String memeId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : memeId = Value(memeId),
       tagId = Value(tagId);
  static Insertable<MemeTagRow> custom({
    Expression<String>? memeId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (memeId != null) 'meme_id': memeId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemeTagsCompanion copyWith({
    Value<String>? memeId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return MemeTagsCompanion(
      memeId: memeId ?? this.memeId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemeTagsCompanion(')
          ..write('memeId: $memeId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StickerPacksTable extends StickerPacks
    with TableInfo<$StickerPacksTable, StickerPackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickerPacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    publisher,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sticker_packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<StickerPackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    } else if (isInserting) {
      context.missing(_publisherMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StickerPackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StickerPackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StickerPacksTable createAlias(String alias) {
    return $StickerPacksTable(attachedDatabase, alias);
  }
}

class StickerPackRow extends DataClass implements Insertable<StickerPackRow> {
  final String id;
  final String name;
  final String publisher;
  final int createdAt;
  final int updatedAt;
  const StickerPackRow({
    required this.id,
    required this.name,
    required this.publisher,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['publisher'] = Variable<String>(publisher);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  StickerPacksCompanion toCompanion(bool nullToAbsent) {
    return StickerPacksCompanion(
      id: Value(id),
      name: Value(name),
      publisher: Value(publisher),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StickerPackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StickerPackRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      publisher: serializer.fromJson<String>(json['publisher']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'publisher': serializer.toJson<String>(publisher),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  StickerPackRow copyWith({
    String? id,
    String? name,
    String? publisher,
    int? createdAt,
    int? updatedAt,
  }) => StickerPackRow(
    id: id ?? this.id,
    name: name ?? this.name,
    publisher: publisher ?? this.publisher,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StickerPackRow copyWithCompanion(StickerPacksCompanion data) {
    return StickerPackRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StickerPackRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('publisher: $publisher, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, publisher, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StickerPackRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.publisher == this.publisher &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StickerPacksCompanion extends UpdateCompanion<StickerPackRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> publisher;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const StickerPacksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.publisher = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickerPacksCompanion.insert({
    required String id,
    required String name,
    required String publisher,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       publisher = Value(publisher),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StickerPackRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? publisher,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (publisher != null) 'publisher': publisher,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickerPacksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? publisher,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return StickerPacksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      publisher: publisher ?? this.publisher,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickerPacksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('publisher: $publisher, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StickerPackItemsTable extends StickerPackItems
    with TableInfo<$StickerPackItemsTable, StickerPackItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickerPackItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packIdMeta = const VerificationMeta('packId');
  @override
  late final GeneratedColumn<String> packId = GeneratedColumn<String>(
    'pack_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sticker_packs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _memeIdMeta = const VerificationMeta('memeId');
  @override
  late final GeneratedColumn<String> memeId = GeneratedColumn<String>(
    'meme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojisMeta = const VerificationMeta('emojis');
  @override
  late final GeneratedColumn<String> emojis = GeneratedColumn<String>(
    'emojis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [packId, memeId, position, emojis];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sticker_pack_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StickerPackItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pack_id')) {
      context.handle(
        _packIdMeta,
        packId.isAcceptableOrUnknown(data['pack_id']!, _packIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packIdMeta);
    }
    if (data.containsKey('meme_id')) {
      context.handle(
        _memeIdMeta,
        memeId.isAcceptableOrUnknown(data['meme_id']!, _memeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('emojis')) {
      context.handle(
        _emojisMeta,
        emojis.isAcceptableOrUnknown(data['emojis']!, _emojisMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packId, memeId};
  @override
  StickerPackItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StickerPackItemRow(
      packId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_id'],
      )!,
      memeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meme_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      emojis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emojis'],
      ),
    );
  }

  @override
  $StickerPackItemsTable createAlias(String alias) {
    return $StickerPackItemsTable(attachedDatabase, alias);
  }
}

class StickerPackItemRow extends DataClass
    implements Insertable<StickerPackItemRow> {
  final String packId;
  final String memeId;
  final int position;

  /// JSON array of at most three emoji strings.
  final String? emojis;
  const StickerPackItemRow({
    required this.packId,
    required this.memeId,
    required this.position,
    this.emojis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pack_id'] = Variable<String>(packId);
    map['meme_id'] = Variable<String>(memeId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || emojis != null) {
      map['emojis'] = Variable<String>(emojis);
    }
    return map;
  }

  StickerPackItemsCompanion toCompanion(bool nullToAbsent) {
    return StickerPackItemsCompanion(
      packId: Value(packId),
      memeId: Value(memeId),
      position: Value(position),
      emojis: emojis == null && nullToAbsent
          ? const Value.absent()
          : Value(emojis),
    );
  }

  factory StickerPackItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StickerPackItemRow(
      packId: serializer.fromJson<String>(json['packId']),
      memeId: serializer.fromJson<String>(json['memeId']),
      position: serializer.fromJson<int>(json['position']),
      emojis: serializer.fromJson<String?>(json['emojis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packId': serializer.toJson<String>(packId),
      'memeId': serializer.toJson<String>(memeId),
      'position': serializer.toJson<int>(position),
      'emojis': serializer.toJson<String?>(emojis),
    };
  }

  StickerPackItemRow copyWith({
    String? packId,
    String? memeId,
    int? position,
    Value<String?> emojis = const Value.absent(),
  }) => StickerPackItemRow(
    packId: packId ?? this.packId,
    memeId: memeId ?? this.memeId,
    position: position ?? this.position,
    emojis: emojis.present ? emojis.value : this.emojis,
  );
  StickerPackItemRow copyWithCompanion(StickerPackItemsCompanion data) {
    return StickerPackItemRow(
      packId: data.packId.present ? data.packId.value : this.packId,
      memeId: data.memeId.present ? data.memeId.value : this.memeId,
      position: data.position.present ? data.position.value : this.position,
      emojis: data.emojis.present ? data.emojis.value : this.emojis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StickerPackItemRow(')
          ..write('packId: $packId, ')
          ..write('memeId: $memeId, ')
          ..write('position: $position, ')
          ..write('emojis: $emojis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(packId, memeId, position, emojis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StickerPackItemRow &&
          other.packId == this.packId &&
          other.memeId == this.memeId &&
          other.position == this.position &&
          other.emojis == this.emojis);
}

class StickerPackItemsCompanion extends UpdateCompanion<StickerPackItemRow> {
  final Value<String> packId;
  final Value<String> memeId;
  final Value<int> position;
  final Value<String?> emojis;
  final Value<int> rowid;
  const StickerPackItemsCompanion({
    this.packId = const Value.absent(),
    this.memeId = const Value.absent(),
    this.position = const Value.absent(),
    this.emojis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickerPackItemsCompanion.insert({
    required String packId,
    required String memeId,
    required int position,
    this.emojis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : packId = Value(packId),
       memeId = Value(memeId),
       position = Value(position);
  static Insertable<StickerPackItemRow> custom({
    Expression<String>? packId,
    Expression<String>? memeId,
    Expression<int>? position,
    Expression<String>? emojis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packId != null) 'pack_id': packId,
      if (memeId != null) 'meme_id': memeId,
      if (position != null) 'position': position,
      if (emojis != null) 'emojis': emojis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickerPackItemsCompanion copyWith({
    Value<String>? packId,
    Value<String>? memeId,
    Value<int>? position,
    Value<String?>? emojis,
    Value<int>? rowid,
  }) {
    return StickerPackItemsCompanion(
      packId: packId ?? this.packId,
      memeId: memeId ?? this.memeId,
      position: position ?? this.position,
      emojis: emojis ?? this.emojis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packId.present) {
      map['pack_id'] = Variable<String>(packId.value);
    }
    if (memeId.present) {
      map['meme_id'] = Variable<String>(memeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (emojis.present) {
      map['emojis'] = Variable<String>(emojis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickerPackItemsCompanion(')
          ..write('packId: $packId, ')
          ..write('memeId: $memeId, ')
          ..write('position: $position, ')
          ..write('emojis: $emojis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemesTable memes = $MemesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $MemeTagsTable memeTags = $MemeTagsTable(this);
  late final $StickerPacksTable stickerPacks = $StickerPacksTable(this);
  late final $StickerPackItemsTable stickerPackItems = $StickerPackItemsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memes,
    tags,
    memeTags,
    stickerPacks,
    stickerPackItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meme_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meme_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sticker_packs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sticker_pack_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'memes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sticker_pack_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MemesTableCreateCompanionBuilder =
    MemesCompanion Function({
      required String id,
      required String sha256,
      required String mimeType,
      required int width,
      required int height,
      required int sizeBytes,
      required String relativePath,
      required String thumbnailPath,
      required String sourceKind,
      Value<String?> sourceRef,
      Value<String?> title,
      Value<String?> notes,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MemesTableUpdateCompanionBuilder =
    MemesCompanion Function({
      Value<String> id,
      Value<String> sha256,
      Value<String> mimeType,
      Value<int> width,
      Value<int> height,
      Value<int> sizeBytes,
      Value<String> relativePath,
      Value<String> thumbnailPath,
      Value<String> sourceKind,
      Value<String?> sourceRef,
      Value<String?> title,
      Value<String?> notes,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$MemesTableReferences
    extends BaseReferences<_$AppDatabase, $MemesTable, MemeRow> {
  $$MemesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemeTagsTable, List<MemeTagRow>>
  _memeTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memeTags,
    aliasName: 'memes__id__meme_tags__meme_id',
  );

  $$MemeTagsTableProcessedTableManager get memeTagsRefs {
    final manager = $$MemeTagsTableTableManager(
      $_db,
      $_db.memeTags,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memeTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StickerPackItemsTable, List<StickerPackItemRow>>
  _stickerPackItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stickerPackItems,
    aliasName: 'memes__id__sticker_pack_items__meme_id',
  );

  $$StickerPackItemsTableProcessedTableManager get stickerPackItemsRefs {
    final manager = $$StickerPackItemsTableTableManager(
      $_db,
      $_db.stickerPackItems,
    ).filter((f) => f.memeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stickerPackItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemesTableFilterComposer extends Composer<_$AppDatabase, $MemesTable> {
  $$MemesTableFilterComposer({
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

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memeTagsRefs(
    Expression<bool> Function($$MemeTagsTableFilterComposer f) f,
  ) {
    final $$MemeTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeTags,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeTagsTableFilterComposer(
            $db: $db,
            $table: $db.memeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stickerPackItemsRefs(
    Expression<bool> Function($$StickerPackItemsTableFilterComposer f) f,
  ) {
    final $$StickerPackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickerPackItems,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPackItemsTableFilterComposer(
            $db: $db,
            $table: $db.stickerPackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemesTable> {
  $$MemesTableOrderingComposer({
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

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemesTable> {
  $$MemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> memeTagsRefs<T extends Object>(
    Expression<T> Function($$MemeTagsTableAnnotationComposer a) f,
  ) {
    final $$MemeTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeTags,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.memeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stickerPackItemsRefs<T extends Object>(
    Expression<T> Function($$StickerPackItemsTableAnnotationComposer a) f,
  ) {
    final $$StickerPackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickerPackItems,
      getReferencedColumn: (t) => t.memeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stickerPackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemesTable,
          MemeRow,
          $$MemesTableFilterComposer,
          $$MemesTableOrderingComposer,
          $$MemesTableAnnotationComposer,
          $$MemesTableCreateCompanionBuilder,
          $$MemesTableUpdateCompanionBuilder,
          (MemeRow, $$MemesTableReferences),
          MemeRow,
          PrefetchHooks Function({bool memeTagsRefs, bool stickerPackItemsRefs})
        > {
  $$MemesTableTableManager(_$AppDatabase db, $MemesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> thumbnailPath = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemesCompanion(
                id: id,
                sha256: sha256,
                mimeType: mimeType,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                relativePath: relativePath,
                thumbnailPath: thumbnailPath,
                sourceKind: sourceKind,
                sourceRef: sourceRef,
                title: title,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sha256,
                required String mimeType,
                required int width,
                required int height,
                required int sizeBytes,
                required String relativePath,
                required String thumbnailPath,
                required String sourceKind,
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemesCompanion.insert(
                id: id,
                sha256: sha256,
                mimeType: mimeType,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                relativePath: relativePath,
                thumbnailPath: thumbnailPath,
                sourceKind: sourceKind,
                sourceRef: sourceRef,
                title: title,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MemesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({memeTagsRefs = false, stickerPackItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memeTagsRefs) db.memeTags,
                    if (stickerPackItemsRefs) db.stickerPackItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memeTagsRefs)
                        await $_getPrefetchedData<
                          MemeRow,
                          $MemesTable,
                          MemeTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableReferences
                              ._memeTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableReferences(
                                db,
                                table,
                                p0,
                              ).memeTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stickerPackItemsRefs)
                        await $_getPrefetchedData<
                          MemeRow,
                          $MemesTable,
                          StickerPackItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemesTableReferences
                              ._stickerPackItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemesTableReferences(
                                db,
                                table,
                                p0,
                              ).stickerPackItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.memeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MemesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemesTable,
      MemeRow,
      $$MemesTableFilterComposer,
      $$MemesTableOrderingComposer,
      $$MemesTableAnnotationComposer,
      $$MemesTableCreateCompanionBuilder,
      $$MemesTableUpdateCompanionBuilder,
      (MemeRow, $$MemesTableReferences),
      MemeRow,
      PrefetchHooks Function({bool memeTagsRefs, bool stickerPackItemsRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      required String normalizedName,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemeTagsTable, List<MemeTagRow>>
  _memeTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memeTags,
    aliasName: 'tags__id__meme_tags__tag_id',
  );

  $$MemeTagsTableProcessedTableManager get memeTagsRefs {
    final manager = $$MemeTagsTableTableManager(
      $_db,
      $_db.memeTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memeTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memeTagsRefs(
    Expression<bool> Function($$MemeTagsTableFilterComposer f) f,
  ) {
    final $$MemeTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeTagsTableFilterComposer(
            $db: $db,
            $table: $db.memeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  Expression<T> memeTagsRefs<T extends Object>(
    Expression<T> Function($$MemeTagsTableAnnotationComposer a) f,
  ) {
    final $$MemeTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memeTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemeTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.memeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool memeTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({memeTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (memeTagsRefs) db.memeTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (memeTagsRefs)
                    await $_getPrefetchedData<TagRow, $TagsTable, MemeTagRow>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._memeTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).memeTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool memeTagsRefs})
    >;
typedef $$MemeTagsTableCreateCompanionBuilder =
    MemeTagsCompanion Function({
      required String memeId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$MemeTagsTableUpdateCompanionBuilder =
    MemeTagsCompanion Function({
      Value<String> memeId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$MemeTagsTableReferences
    extends BaseReferences<_$AppDatabase, $MemeTagsTable, MemeTagRow> {
  $$MemeTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemesTable _memeIdTable(_$AppDatabase db) =>
      db.memes.createAlias('meme_tags__meme_id__memes__id');

  $$MemesTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableManager(
      $_db,
      $_db.memes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('meme_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemeTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MemeTagsTable> {
  $$MemeTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemesTableFilterComposer get memeId {
    final $$MemesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableFilterComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemeTagsTable> {
  $$MemeTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemesTableOrderingComposer get memeId {
    final $$MemesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableOrderingComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemeTagsTable> {
  $$MemeTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MemesTableAnnotationComposer get memeId {
    final $$MemesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableAnnotationComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemeTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemeTagsTable,
          MemeTagRow,
          $$MemeTagsTableFilterComposer,
          $$MemeTagsTableOrderingComposer,
          $$MemeTagsTableAnnotationComposer,
          $$MemeTagsTableCreateCompanionBuilder,
          $$MemeTagsTableUpdateCompanionBuilder,
          (MemeTagRow, $$MemeTagsTableReferences),
          MemeTagRow,
          PrefetchHooks Function({bool memeId, bool tagId})
        > {
  $$MemeTagsTableTableManager(_$AppDatabase db, $MemeTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemeTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemeTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemeTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> memeId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  MemeTagsCompanion(memeId: memeId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String memeId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => MemeTagsCompanion.insert(
                memeId: memeId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemeTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({memeId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable: $$MemeTagsTableReferences
                                    ._memeIdTable(db),
                                referencedColumn: $$MemeTagsTableReferences
                                    ._memeIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$MemeTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$MemeTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemeTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemeTagsTable,
      MemeTagRow,
      $$MemeTagsTableFilterComposer,
      $$MemeTagsTableOrderingComposer,
      $$MemeTagsTableAnnotationComposer,
      $$MemeTagsTableCreateCompanionBuilder,
      $$MemeTagsTableUpdateCompanionBuilder,
      (MemeTagRow, $$MemeTagsTableReferences),
      MemeTagRow,
      PrefetchHooks Function({bool memeId, bool tagId})
    >;
typedef $$StickerPacksTableCreateCompanionBuilder =
    StickerPacksCompanion Function({
      required String id,
      required String name,
      required String publisher,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$StickerPacksTableUpdateCompanionBuilder =
    StickerPacksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> publisher,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$StickerPacksTableReferences
    extends BaseReferences<_$AppDatabase, $StickerPacksTable, StickerPackRow> {
  $$StickerPacksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StickerPackItemsTable, List<StickerPackItemRow>>
  _stickerPackItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stickerPackItems,
    aliasName: 'sticker_packs__id__sticker_pack_items__pack_id',
  );

  $$StickerPackItemsTableProcessedTableManager get stickerPackItemsRefs {
    final manager = $$StickerPackItemsTableTableManager(
      $_db,
      $_db.stickerPackItems,
    ).filter((f) => f.packId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stickerPackItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StickerPacksTableFilterComposer
    extends Composer<_$AppDatabase, $StickerPacksTable> {
  $$StickerPacksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stickerPackItemsRefs(
    Expression<bool> Function($$StickerPackItemsTableFilterComposer f) f,
  ) {
    final $$StickerPackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickerPackItems,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPackItemsTableFilterComposer(
            $db: $db,
            $table: $db.stickerPackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StickerPacksTableOrderingComposer
    extends Composer<_$AppDatabase, $StickerPacksTable> {
  $$StickerPacksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StickerPacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StickerPacksTable> {
  $$StickerPacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> stickerPackItemsRefs<T extends Object>(
    Expression<T> Function($$StickerPackItemsTableAnnotationComposer a) f,
  ) {
    final $$StickerPackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stickerPackItems,
      getReferencedColumn: (t) => t.packId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stickerPackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StickerPacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StickerPacksTable,
          StickerPackRow,
          $$StickerPacksTableFilterComposer,
          $$StickerPacksTableOrderingComposer,
          $$StickerPacksTableAnnotationComposer,
          $$StickerPacksTableCreateCompanionBuilder,
          $$StickerPacksTableUpdateCompanionBuilder,
          (StickerPackRow, $$StickerPacksTableReferences),
          StickerPackRow,
          PrefetchHooks Function({bool stickerPackItemsRefs})
        > {
  $$StickerPacksTableTableManager(_$AppDatabase db, $StickerPacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StickerPacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StickerPacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StickerPacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> publisher = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickerPacksCompanion(
                id: id,
                name: name,
                publisher: publisher,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String publisher,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StickerPacksCompanion.insert(
                id: id,
                name: name,
                publisher: publisher,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StickerPacksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stickerPackItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (stickerPackItemsRefs) db.stickerPackItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stickerPackItemsRefs)
                    await $_getPrefetchedData<
                      StickerPackRow,
                      $StickerPacksTable,
                      StickerPackItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$StickerPacksTableReferences
                          ._stickerPackItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$StickerPacksTableReferences(
                            db,
                            table,
                            p0,
                          ).stickerPackItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.packId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$StickerPacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StickerPacksTable,
      StickerPackRow,
      $$StickerPacksTableFilterComposer,
      $$StickerPacksTableOrderingComposer,
      $$StickerPacksTableAnnotationComposer,
      $$StickerPacksTableCreateCompanionBuilder,
      $$StickerPacksTableUpdateCompanionBuilder,
      (StickerPackRow, $$StickerPacksTableReferences),
      StickerPackRow,
      PrefetchHooks Function({bool stickerPackItemsRefs})
    >;
typedef $$StickerPackItemsTableCreateCompanionBuilder =
    StickerPackItemsCompanion Function({
      required String packId,
      required String memeId,
      required int position,
      Value<String?> emojis,
      Value<int> rowid,
    });
typedef $$StickerPackItemsTableUpdateCompanionBuilder =
    StickerPackItemsCompanion Function({
      Value<String> packId,
      Value<String> memeId,
      Value<int> position,
      Value<String?> emojis,
      Value<int> rowid,
    });

final class $$StickerPackItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StickerPackItemsTable,
          StickerPackItemRow
        > {
  $$StickerPackItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StickerPacksTable _packIdTable(_$AppDatabase db) => db.stickerPacks
      .createAlias('sticker_pack_items__pack_id__sticker_packs__id');

  $$StickerPacksTableProcessedTableManager get packId {
    final $_column = $_itemColumn<String>('pack_id')!;

    final manager = $$StickerPacksTableTableManager(
      $_db,
      $_db.stickerPacks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_packIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MemesTable _memeIdTable(_$AppDatabase db) =>
      db.memes.createAlias('sticker_pack_items__meme_id__memes__id');

  $$MemesTableProcessedTableManager get memeId {
    final $_column = $_itemColumn<String>('meme_id')!;

    final manager = $$MemesTableTableManager(
      $_db,
      $_db.memes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StickerPackItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StickerPackItemsTable> {
  $$StickerPackItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emojis => $composableBuilder(
    column: $table.emojis,
    builder: (column) => ColumnFilters(column),
  );

  $$StickerPacksTableFilterComposer get packId {
    final $$StickerPacksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.stickerPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPacksTableFilterComposer(
            $db: $db,
            $table: $db.stickerPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MemesTableFilterComposer get memeId {
    final $$MemesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableFilterComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickerPackItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StickerPackItemsTable> {
  $$StickerPackItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emojis => $composableBuilder(
    column: $table.emojis,
    builder: (column) => ColumnOrderings(column),
  );

  $$StickerPacksTableOrderingComposer get packId {
    final $$StickerPacksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.stickerPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPacksTableOrderingComposer(
            $db: $db,
            $table: $db.stickerPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MemesTableOrderingComposer get memeId {
    final $$MemesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableOrderingComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickerPackItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StickerPackItemsTable> {
  $$StickerPackItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get emojis =>
      $composableBuilder(column: $table.emojis, builder: (column) => column);

  $$StickerPacksTableAnnotationComposer get packId {
    final $$StickerPacksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.packId,
      referencedTable: $db.stickerPacks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StickerPacksTableAnnotationComposer(
            $db: $db,
            $table: $db.stickerPacks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MemesTableAnnotationComposer get memeId {
    final $$MemesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memeId,
      referencedTable: $db.memes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemesTableAnnotationComposer(
            $db: $db,
            $table: $db.memes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StickerPackItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StickerPackItemsTable,
          StickerPackItemRow,
          $$StickerPackItemsTableFilterComposer,
          $$StickerPackItemsTableOrderingComposer,
          $$StickerPackItemsTableAnnotationComposer,
          $$StickerPackItemsTableCreateCompanionBuilder,
          $$StickerPackItemsTableUpdateCompanionBuilder,
          (StickerPackItemRow, $$StickerPackItemsTableReferences),
          StickerPackItemRow,
          PrefetchHooks Function({bool packId, bool memeId})
        > {
  $$StickerPackItemsTableTableManager(
    _$AppDatabase db,
    $StickerPackItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StickerPackItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StickerPackItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StickerPackItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> packId = const Value.absent(),
                Value<String> memeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> emojis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickerPackItemsCompanion(
                packId: packId,
                memeId: memeId,
                position: position,
                emojis: emojis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packId,
                required String memeId,
                required int position,
                Value<String?> emojis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StickerPackItemsCompanion.insert(
                packId: packId,
                memeId: memeId,
                position: position,
                emojis: emojis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StickerPackItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({packId = false, memeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (packId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.packId,
                                referencedTable:
                                    $$StickerPackItemsTableReferences
                                        ._packIdTable(db),
                                referencedColumn:
                                    $$StickerPackItemsTableReferences
                                        ._packIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (memeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.memeId,
                                referencedTable:
                                    $$StickerPackItemsTableReferences
                                        ._memeIdTable(db),
                                referencedColumn:
                                    $$StickerPackItemsTableReferences
                                        ._memeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StickerPackItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StickerPackItemsTable,
      StickerPackItemRow,
      $$StickerPackItemsTableFilterComposer,
      $$StickerPackItemsTableOrderingComposer,
      $$StickerPackItemsTableAnnotationComposer,
      $$StickerPackItemsTableCreateCompanionBuilder,
      $$StickerPackItemsTableUpdateCompanionBuilder,
      (StickerPackItemRow, $$StickerPackItemsTableReferences),
      StickerPackItemRow,
      PrefetchHooks Function({bool packId, bool memeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemesTableTableManager get memes =>
      $$MemesTableTableManager(_db, _db.memes);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$MemeTagsTableTableManager get memeTags =>
      $$MemeTagsTableTableManager(_db, _db.memeTags);
  $$StickerPacksTableTableManager get stickerPacks =>
      $$StickerPacksTableTableManager(_db, _db.stickerPacks);
  $$StickerPackItemsTableTableManager get stickerPackItems =>
      $$StickerPackItemsTableTableManager(_db, _db.stickerPackItems);
}
