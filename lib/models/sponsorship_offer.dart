class SponsorshipOffer {
  final String id;
  final String shopId;
  final String userId;
  final String type; // 'flow', 'am', 'pro', 'one_time'
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final String? terms;
  final DateTime createdAt;
  final DateTime? expiresAt;

  SponsorshipOffer({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.type,
    required this.status,
    this.terms,
    required this.createdAt,
    this.expiresAt,
  });

  factory SponsorshipOffer.fromMap(Map<String, dynamic> map) {
    return SponsorshipOffer(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      userId: map['user_id'] as String,
      type: map['type'] as String,
      status: map['status'] as String? ?? 'pending',
      terms: map['terms'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'user_id': userId,
      'type': type,
      'status': status,
      'terms': terms,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
