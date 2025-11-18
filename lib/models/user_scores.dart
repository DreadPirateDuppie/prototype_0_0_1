class UserScores {
  final String userId;
  final double mapScore;
  final double playerScore;
  final double rankingScore;

  UserScores({
    required this.userId,
    this.mapScore = 500.0,
    this.playerScore = 500.0,
    this.rankingScore = 500.0,
  });

  // Calculate Final Score as average of the three scores
  double get finalScore => (mapScore + playerScore + rankingScore) / 3;

  // Calculate vote weight (0-1) based on Final Score
  double get voteWeight => finalScore / 1000;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'map_score': mapScore,
      'player_score': playerScore,
      'ranking_score': rankingScore,
    };
  }

  factory UserScores.fromMap(Map<String, dynamic> map) {
    return UserScores(
      userId: map['user_id'] as String,
      mapScore: (map['map_score'] as num?)?.toDouble() ?? 500.0,
      playerScore: (map['player_score'] as num?)?.toDouble() ?? 500.0,
      rankingScore: (map['ranking_score'] as num?)?.toDouble() ?? 500.0,
    );
  }

  UserScores copyWith({
    String? userId,
    double? mapScore,
    double? playerScore,
    double? rankingScore,
  }) {
    return UserScores(
      userId: userId ?? this.userId,
      mapScore: mapScore ?? this.mapScore,
      playerScore: playerScore ?? this.playerScore,
      rankingScore: rankingScore ?? this.rankingScore,
    );
  }
}
