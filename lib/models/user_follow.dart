class UserFollow {
  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;
  
  // Optional populated user data
  final String? followerUsername;
  final String? followerDisplayName;
  final String? followerAvatarUrl;
  final String? followingUsername;
  final String? followingDisplayName;
  final String? followingAvatarUrl;

  UserFollow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
    this.followerUsername,
    this.followerDisplayName,
    this.followerAvatarUrl,
    this.followingUsername,
    this.followingDisplayName,
    this.followingAvatarUrl,
  });

  factory UserFollow.fromMap(Map<String, dynamic> map) {
    return UserFollow(
      id: map['id'] as String,
      followerId: map['follower_id'] as String,
      followingId: map['following_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      followerUsername: map['follower_username'] as String?,
      followerDisplayName: map['follower_display_name'] as String?,
      followerAvatarUrl: map['follower_avatar_url'] as String?,
      followingUsername: map['following_username'] as String?,
      followingDisplayName: map['following_display_name'] as String?,
      followingAvatarUrl: map['following_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Simple user info for displaying in follower lists
class UserInfo {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  final bool isFollowing; // Whether current user follows this user
  final bool isFollower;  // Whether this user follows current user

  UserInfo({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.isFollowing = false,
    this.isFollower = false,
  });

  String get name => displayName ?? username ?? email?.split('@')[0] ?? 'User';
  
  bool get isMutualFollower => isFollowing && isFollower;

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      id: map['id'] as String,
      username: map['username'] as String?,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      email: map['email'] as String?,
      isFollowing: map['is_following'] as bool? ?? false,
      isFollower: map['is_follower'] as bool? ?? false,
    );
  }
}
