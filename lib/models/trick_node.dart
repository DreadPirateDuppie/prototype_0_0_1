class TrickNode {
  final String id;
  final String name;
  final String? description;
  final int difficulty;
  final String category;
  final List<String> parentIds;
  final int pointsValue;
  final DateTime createdAt;

  TrickNode({
    required this.id,
    required this.name,
    this.description,
    this.difficulty = 1,
    required this.category,
    this.parentIds = const [],
    this.pointsValue = 100,
    required this.createdAt,
  });

  factory TrickNode.fromMap(Map<String, dynamic> map) {
    return TrickNode(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      category: map['category'] as String,
      parentIds: (map['parent_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      pointsValue: (map['points_value'] as num?)?.toInt() ?? 100,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty,
      'category': category,
      'parent_ids': parentIds,
      'points_value': pointsValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
