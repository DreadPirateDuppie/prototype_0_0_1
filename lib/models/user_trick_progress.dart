class UserTrickProgress {
  final String id;
  final String userId;
  final String trickId;
  final String status; // 'locked', 'available', 'learned', 'mastered'
  final String? videoProofUrl;
  final DateTime? learnedAt;
  final DateTime createdAt;

  UserTrickProgress({
    required this.id,
    required this.userId,
    required this.trickId,
    required this.status,
    this.videoProofUrl,
    this.learnedAt,
    required this.createdAt,
  });

  factory UserTrickProgress.fromMap(Map<String, dynamic> map) {
    return UserTrickProgress(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      trickId: map['trick_id'] as String,
      status: map['status'] as String? ?? 'locked',
      videoProofUrl: map['video_proof_url'] as String?,
      learnedAt: map['learned_at'] != null
          ? DateTime.parse(map['learned_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'trick_id': trickId,
      'status': status,
      'video_proof_url': videoProofUrl,
      'learned_at': learnedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUnlocked => status != 'locked';
  bool get isLearned => status == 'learned' || status == 'mastered';
}
