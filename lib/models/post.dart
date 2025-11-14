class MapPost {
  final String? id;
  final String userId;
  final double latitude;
  final double longitude;
  final String title;
  final String description;
  final DateTime createdAt;
  final int likes;

  MapPost({
    this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
    required this.createdAt,
    this.likes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
    };
  }

  factory MapPost.fromMap(Map<String, dynamic> map) {
    return MapPost(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      likes: map['likes'] as int? ?? 0,
    );
  }
}
