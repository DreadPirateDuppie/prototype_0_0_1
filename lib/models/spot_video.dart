class SpotVideo {
  final String id;
  final String spotId;
  final String url;
  final String platform;
  final String? trickName;
  final String? skaterName;
  final String? description;
  final String? submittedBy;
  final String status;
  final int upvotes;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final int? userVote; // Current user's vote: 1, -1, or null
  final String? thumbnailUrl;
  final List<String> tags;

  SpotVideo({
    required this.id,
    required this.spotId,
    required this.url,
    required this.platform,
    this.trickName,
    this.skaterName,
    this.description,
    this.submittedBy,
    required this.status,
    required this.upvotes,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.userVote,
    this.thumbnailUrl,
    this.tags = const [],
  });

  factory SpotVideo.fromMap(Map<String, dynamic> map) {
    return SpotVideo(
      id: map['id'] as String,
      spotId: map['spot_id'] as String,
      url: map['url'] as String,
      platform: map['platform'] as String? ?? 'native',
      trickName: map['trick_name'] as String?,
      skaterName: map['skater_name'] as String?,
      description: map['description'] as String?,
      submittedBy: map['submitted_by'] as String?,
      status: map['status'] as String? ?? 'pending',
      upvotes: (map['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      approvedAt: map['approved_at'] != null 
          ? DateTime.parse(map['approved_at'] as String)
          : null,
      approvedBy: map['approved_by'] as String?,
      userVote: map['user_vote'] as int?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spot_id': spotId,
      'url': url,
      'platform': platform,
      'trick_name': trickName,
      'skater_name': skaterName,
      'description': description,
      'submitted_by': submittedBy,
      'status': status,
      'upvotes': upvotes,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'thumbnail_url': thumbnailUrl,
      'tags': tags,
    };
  }

  String get displayTitle {
    if (trickName != null && trickName!.isNotEmpty) {
      return trickName!;
    }
    if (skaterName != null && skaterName!.isNotEmpty) {
      return skaterName!;
    }
    return 'Untitled Video';
  }

  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
