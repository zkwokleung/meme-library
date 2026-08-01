import 'package:meta/meta.dart';

import 'tag.dart';

/// Where a meme entered the library.
enum MemeSourceKind { clipboard, url, share, restore }

/// A saved meme and its metadata. Immutable; use [copyWith] to derive
/// updated instances.
@immutable
class Meme {
  const Meme({
    required this.id,
    required this.sha256,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.relativePath,
    required this.thumbnailPath,
    required this.sourceKind,
    required this.createdAt,
    required this.updatedAt,
    this.sourceRef,
    this.title,
    this.notes,
    this.tags = const [],
  });

  final String id;

  /// Lowercase hex SHA-256 of the original file bytes; unique per library.
  final String sha256;

  final String mimeType;
  final int width;
  final int height;
  final int sizeBytes;

  /// Path of the original image, relative to the managed media root.
  final String relativePath;

  /// Path of the thumbnail, relative to the managed media root.
  final String thumbnailPath;

  final MemeSourceKind sourceKind;

  /// Source detail: the URL for [MemeSourceKind.url], a file name for
  /// shares, absent otherwise.
  final String? sourceRef;

  final String? title;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Tag> tags;

  Meme copyWith({
    String? Function()? title,
    String? Function()? notes,
    List<Tag>? tags,
    DateTime? updatedAt,
  }) {
    return Meme(
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
      title: title != null ? title() : this.title,
      notes: notes != null ? notes() : this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sha256': sha256,
    'mimeType': mimeType,
    'width': width,
    'height': height,
    'sizeBytes': sizeBytes,
    'relativePath': relativePath,
    'thumbnailPath': thumbnailPath,
    'sourceKind': sourceKind.name,
    'sourceRef': sourceRef,
    'title': title,
    'notes': notes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'tags': [for (final tag in tags) tag.toJson()],
  };

  factory Meme.fromJson(Map<String, Object?> json) => Meme(
    id: json['id']! as String,
    sha256: json['sha256']! as String,
    mimeType: json['mimeType']! as String,
    width: json['width']! as int,
    height: json['height']! as int,
    sizeBytes: json['sizeBytes']! as int,
    relativePath: json['relativePath']! as String,
    thumbnailPath: json['thumbnailPath']! as String,
    sourceKind: MemeSourceKind.values.byName(json['sourceKind']! as String),
    sourceRef: json['sourceRef'] as String?,
    title: json['title'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    tags: [
      for (final tag in (json['tags'] as List<Object?>? ?? const []))
        Tag.fromJson(tag! as Map<String, Object?>),
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is Meme &&
      other.id == id &&
      other.sha256 == sha256 &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.sizeBytes == sizeBytes &&
      other.relativePath == relativePath &&
      other.thumbnailPath == thumbnailPath &&
      other.sourceKind == sourceKind &&
      other.sourceRef == sourceRef &&
      other.title == title &&
      other.notes == notes &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      _tagsEqual(other.tags, tags);

  static bool _tagsEqual(List<Tag> a, List<Tag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, sha256, updatedAt, Object.hashAll(tags));

  @override
  String toString() => 'Meme($id, $mimeType, ${width}x$height)';
}
