class MapPost {
  final String? id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;  // User profile picture
  final double? latitude;
  final double? longitude;
  final String title;
  final String description;
  final DateTime createdAt;
  final int likes;
  final List<String> photoUrls;
  final String? videoUrl;
  final double popularityRating;
  final double securityRating;
  final double qualityRating;
  final int upvotes;
  final int downvotes;
  final int voteScore;
  final int? userVote;
  final String category;
  final List<String> tags;

  MapPost({
    this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    required this.title,
    required this.description,
    required this.createdAt,
    this.likes = 0,
    List<String>? photoUrls,
    this.videoUrl,
    this.popularityRating = 0.0,
    this.securityRating = 0.0,
    this.qualityRating = 0.0,
    this.upvotes = 0,
    this.downvotes = 0,
    this.voteScore = 0,
    this.userVote,
    this.category = 'Other',
    this.tags = const [],
  }) : photoUrls = photoUrls ?? [];

  // Backward compatibility getter
  String? get photoUrl => photoUrls.isNotEmpty ? photoUrls.first : null;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
      'photo_urls': photoUrls,
      'video_url': videoUrl,
      'popularity_rating': popularityRating,
      'security_rating': securityRating,
      'quality_rating': qualityRating,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'vote_score': voteScore,
      'category': category,
      'tags': tags,
    };
  }

  factory MapPost.fromMap(Map<String, dynamic> map) {
    // Debug logging for photo data
    // print('DEBUG: MapPost.fromMap - ID: ${map['id']}, photo_urls: ${map['photo_urls']}, photo_url: ${map['photo_url']}');

    // Handle both old photo_url and new photo_urls
    List<String> photos = [];
    if (map['photo_urls'] != null && (map['photo_urls'] as List).isNotEmpty) {
      photos = (map['photo_urls'] as List<dynamic>).map((e) => e as String).toList();
    } else if (map['photo_url'] != null) {
      photos = [map['photo_url'] as String];
    }

    return MapPost(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String?,
      userEmail: map['user_email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      likes: map['likes'] as int? ?? 0,
      photoUrls: photos,
      videoUrl: map['video_url'] as String?,
      popularityRating: (map['popularity_rating'] as num?)?.toDouble() ?? 0.0,
      securityRating: (map['security_rating'] as num?)?.toDouble() ?? 0.0,
      qualityRating: (map['quality_rating'] as num?)?.toDouble() ?? 0.0,
      upvotes: map['upvotes'] as int? ?? 0,
      downvotes: map['downvotes'] as int? ?? 0,
      voteScore: map['vote_score'] as int? ?? 0,
      userVote: map['user_vote'] as int?,
      category: map['category'] as String? ?? 'Other',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}
