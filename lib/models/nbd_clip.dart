/// NBD ("Never Been Done") Registry clip — Master Blueprint §3.3.
///
/// A raw clip pinned to exact geo-coordinates for a genuinely new trick or
/// spot usage. Bypasses public likes/algorithmic sorting; enters a
/// peer-review queue of verified community veterans and, once approved, is
/// permanently locked to its landmark with an automated points bounty.
/// Mirrors `public.clips` (supabase/migrations/20260708_nbd_registry.sql).
class NbdClip {
  final String? id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String trickName;
  final String? description;
  final double latitude;
  final double longitude;

  /// Optional link to an existing spot landmark (map_posts.id).
  final String? spotId;

  final bool isNbd;

  /// 'pending' | 'approved' | 'rejected'.
  final String status;
  final DateTime? approvedAt;
  final double? bountyPoints;
  final bool bountyPaid;
  final DateTime createdAt;

  NbdClip({
    this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.trickName,
    this.description,
    required this.latitude,
    required this.longitude,
    this.spotId,
    this.isNbd = true,
    this.status = 'pending',
    this.approvedAt,
    this.bountyPoints,
    this.bountyPaid = false,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory NbdClip.fromMap(Map<String, dynamic> map) {
    return NbdClip(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      videoUrl: map['video_url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      trickName: map['trick_name'] as String,
      description: map['description'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      spotId: map['spot_id'] as String?,
      isNbd: map['is_nbd'] as bool? ?? true,
      status: map['status'] as String? ?? 'pending',
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
      bountyPoints: (map['bounty_points'] as num?)?.toDouble(),
      bountyPaid: map['bounty_paid'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'trick_name': trickName,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'spot_id': spotId,
      'is_nbd': isNbd,
      'status': status,
      'approved_at': approvedAt?.toIso8601String(),
      'bounty_points': bountyPoints,
      'bounty_paid': bountyPaid,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A single reviewer verdict on an NBD clip (mirrors `public.nbd_reviews`).
class NbdReview {
  final String? id;
  final String clipId;
  final String reviewerId;

  /// 'approve' | 'reject'.
  final String verdict;
  final String? notes;
  final DateTime createdAt;

  NbdReview({
    this.id,
    required this.clipId,
    required this.reviewerId,
    required this.verdict,
    this.notes,
    required this.createdAt,
  });

  factory NbdReview.fromMap(Map<String, dynamic> map) {
    return NbdReview(
      id: map['id'] as String?,
      clipId: map['clip_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      verdict: map['verdict'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
