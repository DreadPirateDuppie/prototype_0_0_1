import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../config/service_locator.dart';
import 'auth_service.dart';

/// Service responsible for social operations (following, followers, search)
class SocialService {
  final SupabaseClient? _injectedClient;
  final AuthService _authService = getIt<AuthService>();

  SocialService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) {
      return injected;
    }
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Follow a user
  Future<void> followUser(String userIdToFollow) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');
      
      if (currentUser.id == userIdToFollow) {
        throw Exception('Cannot follow yourself');
      }

      await _client.from('follows').insert({
        'follower_id': currentUser.id,
        'following_id': userIdToFollow,
      });
      
      AppLogger.log('User ${currentUser.id} followed $userIdToFollow', name: 'SocialService');
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String userIdToUnfollow) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');

      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', userIdToUnfollow);
      
      AppLogger.log('User ${currentUser.id} unfollowed $userIdToUnfollow', name: 'SocialService');
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  /// Check if current user is following a specific user
  Future<bool> isFollowing(String userId) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return false;

      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger.log('Error checking follow status: $e', name: 'SocialService');
      return false;
    }
  }

  /// Get list of users who follow the specified user
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final followsResponse = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      final followerIds = (followsResponse as List)
          .map((f) => f['follower_id'] as String)
          .toList();

      if (followerIds.isEmpty) return [];

      final profilesResponse = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url, is_verified')
          .filter('id', 'in', followerIds);

      return (profilesResponse as List).cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.log('Error getting followers: $e', name: 'SocialService');
      return [];
    }
  }

  /// Get list of users that the specified user is following
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      final followsResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = (followsResponse as List)
          .map((f) => f['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      final profilesResponse = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url, is_verified')
          .filter('id', 'in', followingIds);

      return (profilesResponse as List).cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.log('Error getting following: $e', name: 'SocialService');
      return [];
    }
  }

  /// Get mutual followers - users who follow you AND you follow back
  Future<List<Map<String, dynamic>>> getMutualFollowers() async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return [];

      final myFollowers = await getFollowers(currentUser.id);
      final followerIds = myFollowers.map((f) => f['id'] as String).toSet();

      final myFollowing = await getFollowing(currentUser.id);
      final followingIds = myFollowing.map((f) => f['id'] as String).toSet();

      final mutualIds = followerIds.intersection(followingIds).toList();

      if (mutualIds.isEmpty) return [];

      return myFollowers.where((user) => mutualIds.contains(user['id'])).toList();
    } catch (e) {
      AppLogger.log('Error getting mutual followers: $e', name: 'SocialService');
      return [];
    }
  }

  /// Get follower and following counts for a user
  Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      final followersCount = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('following_id', userId);
      
      final followingCount = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('follower_id', userId);
      
      return {
        'followers': followersCount,
        'following': followingCount,
      };
    } catch (e) {
      AppLogger.log('Error getting follow counts: $e', name: 'SocialService');
      return {'followers': 0, 'following': 0};
    }
  }

  /// Search for users by username or display name (excludes current user)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return [];

      final response = await _client.rpc('search_profiles', params: {
        'search_query': query,
        'limit_cnt': 20,
      });

      return (response as List).cast<Map<String, dynamic>>().where((u) => u['id'] != currentUser.id).toList();
    } catch (e) {
      AppLogger.log('Error searching users: $e', name: 'SocialService');
      
      // Fallback to legacy search if RPC fails
      try {
        final response = await _client
            .from('user_profiles')
            .select('id, username, display_name, avatar_url, is_verified')
            .or('username.ilike.%$query%,display_name.ilike.%$query%')
            .limit(20);
        return (response as List).cast<Map<String, dynamic>>();
      } catch (fallbackError) {
        return [];
      }
    }
  }

  /// Get a random opponent for quick match
  Future<String?> getRandomOpponent({bool mutualOnly = false}) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return null;

      final mutualFollowers = await getMutualFollowers();
      
      if (mutualFollowers.isNotEmpty) {
        mutualFollowers.shuffle();
        return mutualFollowers.first['id'] as String;
      }

      if (mutualOnly) return null;

      final usersResponse = await _client
          .from('user_profiles')
          .select('id')
          .neq('id', currentUser.id)
          .limit(100);

      final users = (usersResponse as List).cast<Map<String, dynamic>>();
      if (users.isEmpty) return null;

      users.shuffle();
      return users.first['id'] as String;
    } catch (e) {
      AppLogger.log('Error getting random opponent: $e', name: 'SocialService');
      return null;
    }
  }
}
