class TrickDefinition {
  final String id;
  final String slug;
  final String displayName;
  final String category;
  final double difficultyMultiplier;
  final String? description;
  final DateTime createdAt;

  TrickDefinition({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.category,
    required this.difficultyMultiplier,
    this.description,
    required this.createdAt,
  });

  factory TrickDefinition.fromMap(Map<String, dynamic> map) {
    return TrickDefinition(
      id: map['id'] as String,
      slug: map['slug'] as String,
      displayName: map['display_name'] as String,
      category: map['category'] as String,
      difficultyMultiplier: (map['difficulty_multiplier'] as num?)?.toDouble() ?? 1.0,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slug': slug,
      'display_name': displayName,
      'category': category,
      'difficulty_multiplier': difficultyMultiplier,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
