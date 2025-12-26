enum GameMode {
  skate,  // S-K-A-T-E
  sk8,    // S-K-8
  custom  // User defined letters
}

enum VerificationStatus {
  pending,
  quickFireVoting,
  communityVerification,
  resolved
}

enum VoteType {
  land,
  noLand,
  rebate
}

enum BattleStatus {
  active,
  completed,
  expired
}

class Battle {
  final String? id;
  final String player1Id;
  final String player2Id;
  final GameMode gameMode;
  final String customLetters;
  final String player1Letters;
  final String player2Letters;
  final String? setTrickVideoUrl;
  final String? attemptVideoUrl;
  final VerificationStatus verificationStatus;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winnerId;
  final String currentTurnPlayerId;
  final int wagerAmount;
  final int betAmount;
  final bool isQuickfire;
  final DateTime? turnDeadline;
  final bool betAccepted;
  final String? setterId;
  final String? attempterId;
  final String? setterVote; // 'landed' or 'missed'
  final String? attempterVote; // 'landed' or 'missed'
  final String? trickName;
  final String? player1RpsMove;
  final String? player2RpsMove;
  final String? rpsWinnerId;

  Battle({
    this.id,
    required this.player1Id,
    required this.player2Id,
    required this.gameMode,
    this.customLetters = '',
    this.player1Letters = '',
    this.player2Letters = '',
    this.setTrickVideoUrl,
    this.attemptVideoUrl,
    this.verificationStatus = VerificationStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.winnerId,
    required this.currentTurnPlayerId,
    this.wagerAmount = 0,
    this.betAmount = 0,
    this.isQuickfire = false,
    this.turnDeadline,
    this.betAccepted = false,
    this.setterId,
    this.attempterId,
    this.setterVote,
    this.attempterVote,
    this.trickName,
    this.player1RpsMove,
    this.player2RpsMove,
    this.rpsWinnerId,
  });

  String getGameLetters() {
    switch (gameMode) {
      case GameMode.skate:
        return 'SKATE';
      case GameMode.sk8:
        return 'SK8';
      case GameMode.custom:
        return customLetters;
    }
  }

  bool isComplete() {
    if (winnerId != null) return true;
    final targetLetters = getGameLetters();
    return player1Letters == targetLetters || player2Letters == targetLetters;
  }

  bool isTimerExpired() {
    if (turnDeadline == null) return false;
    return DateTime.now().isAfter(turnDeadline!);
  }

  Duration? getRemainingTime() {
    if (turnDeadline == null) return null;
    final now = DateTime.now();
    if (now.isAfter(turnDeadline!)) return Duration.zero;
    return turnDeadline!.difference(now);
  }

  Duration getTimerDuration() {
    return isQuickfire 
        ? const Duration(minutes: 4, seconds: 20)
        : const Duration(hours: 24);
  }

  BattleStatus get status {
    if (winnerId != null) return BattleStatus.completed;
    if (isTimerExpired()) return BattleStatus.expired;
    return BattleStatus.active;
  }

  Map<String, dynamic> toMap() {
    return {
      'player1_id': player1Id,
      'player2_id': player2Id,
      'game_mode': gameMode.toString().split('.').last,
      'custom_letters': customLetters,
      'player1_letters': player1Letters,
      'player2_letters': player2Letters,
      'set_trick_video_url': setTrickVideoUrl,
      'attempt_video_url': attemptVideoUrl,
      'verification_status': verificationStatus.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'winner_id': winnerId,
      'current_turn_player_id': currentTurnPlayerId,
      'wager_amount': wagerAmount,
      'bet_amount': betAmount,
      'is_quickfire': isQuickfire,
      'turn_deadline': turnDeadline?.toIso8601String(),
      'bet_accepted': betAccepted,
      'setter_id': setterId,
      'attempter_id': attempterId,
      'setter_vote': setterVote,
      'attempter_vote': attempterVote,
      'trick_name': trickName,
      'player1_rps_move': player1RpsMove,
      'player2_rps_move': player2RpsMove,
      'rps_winner_id': rpsWinnerId,
    };
  }

  factory Battle.fromMap(Map<String, dynamic> map) {
    return Battle(
      id: map['id'] as String?,
      player1Id: map['player1_id'] as String,
      player2Id: map['player2_id'] as String,
      gameMode: GameMode.values.firstWhere(
        (e) => e.toString().split('.').last == map['game_mode'],
        orElse: () => GameMode.skate,
      ),
      customLetters: map['custom_letters'] as String? ?? '',
      player1Letters: map['player1_letters'] as String? ?? '',
      player2Letters: map['player2_letters'] as String? ?? '',
      setTrickVideoUrl: map['set_trick_video_url'] as String?,
      attemptVideoUrl: map['attempt_video_url'] as String?,
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['verification_status'],
        orElse: () => VerificationStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at'] as String) 
          : null,
      winnerId: map['winner_id'] as String?,
      currentTurnPlayerId: map['current_turn_player_id'] as String,
      wagerAmount: (map['wager_amount'] as num?)?.toInt() ?? 0,
      betAmount: (map['bet_amount'] as num?)?.toInt() ?? 0,
      isQuickfire: map['is_quickfire'] as bool? ?? false,
      turnDeadline: map['turn_deadline'] != null
          ? DateTime.parse(map['turn_deadline'] as String)
          : null,
      betAccepted: map['bet_accepted'] as bool? ?? false,
      setterId: map['setter_id'] as String?,
      attempterId: map['attempter_id'] as String?,
      setterVote: map['setter_vote'] as String?,
      attempterVote: map['attempter_vote'] as String?,
      trickName: map['trick_name'] as String?,
      player1RpsMove: map['player1_rps_move'] as String?,
      player2RpsMove: map['player2_rps_move'] as String?,
      rpsWinnerId: map['rps_winner_id'] as String?,
    );
  }

  Battle copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    GameMode? gameMode,
    String? customLetters,
    String? player1Letters,
    String? player2Letters,
    String? setTrickVideoUrl,
    String? attemptVideoUrl,
    VerificationStatus? verificationStatus,
    DateTime? createdAt,
    DateTime? completedAt,
    String? winnerId,
    String? currentTurnPlayerId,
    int? wagerAmount,
    int? betAmount,
    bool? isQuickfire,
    DateTime? turnDeadline,
    bool? betAccepted,
    String? setterId,
    String? attempterId,
    String? setterVote,
    String? attempterVote,
    String? trickName,
    String? player1RpsMove,
    String? player2RpsMove,
    String? rpsWinnerId,
  }) {
    return Battle(
      id: id ?? this.id,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      gameMode: gameMode ?? this.gameMode,
      customLetters: customLetters ?? this.customLetters,
      player1Letters: player1Letters ?? this.player1Letters,
      player2Letters: player2Letters ?? this.player2Letters,
      setTrickVideoUrl: setTrickVideoUrl ?? this.setTrickVideoUrl,
      attemptVideoUrl: attemptVideoUrl ?? this.attemptVideoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      winnerId: winnerId ?? this.winnerId,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      wagerAmount: wagerAmount ?? this.wagerAmount,
      betAmount: betAmount ?? this.betAmount,
      isQuickfire: isQuickfire ?? this.isQuickfire,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      betAccepted: betAccepted ?? this.betAccepted,
      setterId: setterId ?? this.setterId,
      attempterId: attempterId ?? this.attempterId,
      setterVote: setterVote ?? this.setterVote,
      attempterVote: attempterVote ?? this.attempterVote,
      trickName: trickName ?? this.trickName,
      player1RpsMove: player1RpsMove ?? this.player1RpsMove,
      player2RpsMove: player2RpsMove ?? this.player2RpsMove,
      rpsWinnerId: rpsWinnerId ?? this.rpsWinnerId,
    );
  }
}
