class BattleTrick {
  final String? id;
  final String battleId;
  final String setterId;
  final String attempterId;
  final String trickName;
  final String setTrickVideoUrl;
  final String attemptVideoUrl;
  final String outcome; // 'landed' or 'missed'
  final String lettersGiven;
  final DateTime createdAt;

  BattleTrick({
    this.id,
    required this.battleId,
    required this.setterId,
    required this.attempterId,
    required this.trickName,
    required this.setTrickVideoUrl,
    required this.attemptVideoUrl,
    required this.outcome,
    required this.lettersGiven,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'battle_id': battleId,
      'setter_id': setterId,
      'attempter_id': attempterId,
      'trick_name': trickName,
      'set_trick_video_url': setTrickVideoUrl,
      'attempt_video_url': attemptVideoUrl,
      'outcome': outcome,
      'letters_given': lettersGiven,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BattleTrick.fromMap(Map<String, dynamic> map) {
    return BattleTrick(
      id: map['id'] as String?,
      battleId: map['battle_id'] as String,
      setterId: map['setter_id'] as String,
      attempterId: map['attempter_id'] as String,
      trickName: map['trick_name'] as String,
      setTrickVideoUrl: map['set_trick_video_url'] as String,
      attemptVideoUrl: map['attempt_video_url'] as String,
      outcome: map['outcome'] as String,
      lettersGiven: map['letters_given'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
