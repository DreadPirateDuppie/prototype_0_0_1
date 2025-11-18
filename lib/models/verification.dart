import 'battle.dart';

class Vote {
  final String? id;
  final String attemptId;
  final String userId;
  final VoteType voteType;
  final double voteWeight;
  final DateTime createdAt;

  Vote({
    this.id,
    required this.attemptId,
    required this.userId,
    required this.voteType,
    required this.voteWeight,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'attempt_id': attemptId,
      'user_id': userId,
      'vote_type': voteType.toString().split('.').last,
      'vote_weight': voteWeight,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Vote.fromMap(Map<String, dynamic> map) {
    return Vote(
      id: map['id'] as String?,
      attemptId: map['attempt_id'] as String,
      userId: map['user_id'] as String,
      voteType: VoteType.values.firstWhere(
        (e) => e.toString().split('.').last == map['vote_type'],
        orElse: () => VoteType.noLand,
      ),
      voteWeight: (map['vote_weight'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class QuickFireVote {
  final String? id;
  final String attemptId;
  final String player1Id;
  final String player2Id;
  final VoteType? player1Vote;
  final VoteType? player2Vote;
  final DateTime createdAt;

  QuickFireVote({
    this.id,
    required this.attemptId,
    required this.player1Id,
    required this.player2Id,
    this.player1Vote,
    this.player2Vote,
    required this.createdAt,
  });

  bool get bothPlayersVoted => player1Vote != null && player2Vote != null;

  bool get playersAgree => bothPlayersVoted && player1Vote == player2Vote;

  bool get needsRebate => 
      bothPlayersVoted && (player1Vote == VoteType.rebate || player2Vote == VoteType.rebate);

  bool get needsCommunityVerification => 
      bothPlayersVoted && !playersAgree && !needsRebate;

  VoteType? get agreedVote => playersAgree ? player1Vote : null;

  Map<String, dynamic> toMap() {
    return {
      'attempt_id': attemptId,
      'player1_id': player1Id,
      'player2_id': player2Id,
      'player1_vote': player1Vote?.toString().split('.').last,
      'player2_vote': player2Vote?.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory QuickFireVote.fromMap(Map<String, dynamic> map) {
    return QuickFireVote(
      id: map['id'] as String?,
      attemptId: map['attempt_id'] as String,
      player1Id: map['player1_id'] as String,
      player2Id: map['player2_id'] as String,
      player1Vote: map['player1_vote'] != null 
          ? VoteType.values.firstWhere(
              (e) => e.toString().split('.').last == map['player1_vote'],
              orElse: () => VoteType.noLand,
            )
          : null,
      player2Vote: map['player2_vote'] != null 
          ? VoteType.values.firstWhere(
              (e) => e.toString().split('.').last == map['player2_vote'],
              orElse: () => VoteType.noLand,
            )
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  QuickFireVote copyWith({
    String? id,
    String? attemptId,
    String? player1Id,
    String? player2Id,
    VoteType? player1Vote,
    VoteType? player2Vote,
    DateTime? createdAt,
  }) {
    return QuickFireVote(
      id: id ?? this.id,
      attemptId: attemptId ?? this.attemptId,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      player1Vote: player1Vote ?? this.player1Vote,
      player2Vote: player2Vote ?? this.player2Vote,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VerificationAttempt {
  final String? id;
  final String battleId;
  final String attemptingPlayerId;
  final String attemptVideoUrl;
  final VerificationStatus status;
  final VoteType? result;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  VerificationAttempt({
    this.id,
    required this.battleId,
    required this.attemptingPlayerId,
    required this.attemptVideoUrl,
    this.status = VerificationStatus.pending,
    this.result,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'battle_id': battleId,
      'attempting_player_id': attemptingPlayerId,
      'attempt_video_url': attemptVideoUrl,
      'status': status.toString().split('.').last,
      'result': result?.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  factory VerificationAttempt.fromMap(Map<String, dynamic> map) {
    return VerificationAttempt(
      id: map['id'] as String?,
      battleId: map['battle_id'] as String,
      attemptingPlayerId: map['attempting_player_id'] as String,
      attemptVideoUrl: map['attempt_video_url'] as String,
      status: VerificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VerificationStatus.pending,
      ),
      result: map['result'] != null 
          ? VoteType.values.firstWhere(
              (e) => e.toString().split('.').last == map['result'],
              orElse: () => VoteType.noLand,
            )
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      resolvedAt: map['resolved_at'] != null 
          ? DateTime.parse(map['resolved_at'] as String) 
          : null,
    );
  }

  VerificationAttempt copyWith({
    String? id,
    String? battleId,
    String? attemptingPlayerId,
    String? attemptVideoUrl,
    VerificationStatus? status,
    VoteType? result,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return VerificationAttempt(
      id: id ?? this.id,
      battleId: battleId ?? this.battleId,
      attemptingPlayerId: attemptingPlayerId ?? this.attemptingPlayerId,
      attemptVideoUrl: attemptVideoUrl ?? this.attemptVideoUrl,
      status: status ?? this.status,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
