import 'dart:math';

class UserScores {
  final String userId;
  final double mapScore;
  final double playerScore;
  final double rankingScore;

  UserScores({
    required this.userId,
    this.mapScore = 0.0, // XP system starts at 0
    this.playerScore = 0.0, // XP system starts at 0
    this.rankingScore = 500.0, // Ranking score starts at 500
  });

  // Calculate Final Score as average of the three scores
  double get finalScore => (mapScore + playerScore + rankingScore) / 3;

  // Calculate vote weight (0-1) based on Final Score
  double get voteWeight => finalScore / 1000;

  // Progressive leveling: Calculate level from XP
  // Formula: XP for level N = 100 * N * (N + 1) / 2
  static int getLevelFromXP(double xp) {
    if (xp <= 0) return 0;
    
    // Solve quadratic equation: 100 * N * (N + 1) / 2 = xp
    // Simplified: N^2 + N - (2*xp/100) = 0
    // Using quadratic formula: N = (-1 + sqrt(1 + 8*xp/100)) / 2
    final discriminant = 1 + (8 * xp / 100);
    final level = ((-1 + sqrt(discriminant)) / 2).floor();
    return level;
  }

  // Get total XP required to reach a specific level
  static double getXPForLevel(int level) {
    if (level <= 0) return 0;
    return 100 * level * (level + 1) / 2;
  }

  // Get XP required for the next level from current XP
  static double getXPForNextLevel(double currentXP) {
    final currentLevel = getLevelFromXP(currentXP);
    return getXPForLevel(currentLevel + 1);
  }

  // Get progress (0-1) towards next level
  static double getLevelProgress(double xp) {
    final currentLevel = getLevelFromXP(xp);
    final currentLevelXP = getXPForLevel(currentLevel);
    final nextLevelXP = getXPForLevel(currentLevel + 1);
    final xpIntoLevel = xp - currentLevelXP;
    final xpNeededForLevel = nextLevelXP - currentLevelXP;
    
    if (xpNeededForLevel <= 0) return 0;
    return (xpIntoLevel / xpNeededForLevel).clamp(0.0, 1.0);
  }

  // Instance getters for map score
  int get mapLevel => getLevelFromXP(mapScore);
  double get mapLevelProgress => getLevelProgress(mapScore);
  double get mapXPForNextLevel => getXPForNextLevel(mapScore);

  // Instance getters for player score
  int get playerLevel => getLevelFromXP(playerScore);
  double get playerLevelProgress => getLevelProgress(playerScore);
  double get playerXPForNextLevel => getXPForNextLevel(playerScore);

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
      mapScore: (map['map_score'] as num?)?.toDouble() ?? 0.0, // Default to 0 for XP
      playerScore: (map['player_score'] as num?)?.toDouble() ?? 0.0, // Default to 0 for XP
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
