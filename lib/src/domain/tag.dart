import 'package:meta/meta.dart';

/// A user-defined label attached to memes.
///
/// Tag identity is case-insensitive: [normalized] is the unique key while
/// [name] preserves the casing the user typed.
@immutable
class Tag {
  const Tag({required this.id, required this.name});

  final String id;
  final String name;

  /// Canonical form used for uniqueness and lookups.
  String get normalized => normalize(name);

  /// Normalizes a raw tag name: trims, collapses inner whitespace, and
  /// lowercases.
  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Tag copyWith({String? name}) => Tag(id: id, name: name ?? this.name);

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory Tag.fromJson(Map<String, Object?> json) =>
      Tag(id: json['id']! as String, name: json['name']! as String);

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Tag($id, $name)';
}
