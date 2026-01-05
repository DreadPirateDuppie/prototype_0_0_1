class Shop {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final DateTime createdAt;

  Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.latitude,
    this.longitude,
    this.isVerified = false,
    required this.createdAt,
  });

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      websiteUrl: map['website_url'] as String?,
      latitude: (map['location_lat'] as num?)?.toDouble(),
      longitude: (map['location_lng'] as num?)?.toDouble(),
      isVerified: map['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'logo_url': logoUrl,
      'website_url': websiteUrl,
      'location_lat': latitude,
      'location_lng': longitude,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
