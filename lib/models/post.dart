class MapPost {
  final String? id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final double latitude;
  final double longitude;
  final String title;
  final String description;
  final DateTime createdAt;
  final int likes;
  final String? photoUrl;
  final double popularityRating;
  final double securityRating;
  final double qualityRating;
  
  // Vote fields
  final int upvotes;
  final int downvotes;
  final int voteScore; // upvotes - downvotes
  final int? userVote; // -1 = downvote, 0 = no vote, 1 = upvote

  MapPost({
    this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
    required this.createdAt,
    this.likes = 0,
    this.photoUrl,
    this.popularityRating = 0.0,
    this.securityRating = 0.0,
    this.qualityRating = 0.0,
    this.upvotes = 0,
    this.downvotes = 0,
    this.voteScore = 0,
    this.userVote,
  });

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
      'photo_url': photoUrl,
      'popularity_rating': popularityRating,
      'security_rating': securityRating,
      'quality_rating': qualityRating,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'vote_score': voteScore,
    };
  }

  factory MapPost.fromMap(Map<String, dynamic> map) {
    return MapPost(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String?,
      userEmail: map['user_email'] as String?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      likes: map['likes'] as int? ?? 0,
      photoUrl: map['photo_url'] as String?,
      popularityRating: (map['popularity_rating'] as num?)?.toDouble() ?? 0.0,
      securityRating: (map['security_rating'] as num?)?.toDouble() ?? 0.0,
      qualityRating: (map['quality_rating'] as num?)?.toDouble() ?? 0.0,
      upvotes: map['upvotes'] as int? ?? 0,
      downvotes: map['downvotes'] as int? ?? 0,
      voteScore: map['vote_score'] as int? ?? 0,
      userVote: map['user_vote'] as int?,
    );
  }
}
