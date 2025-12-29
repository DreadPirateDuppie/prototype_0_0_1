import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../config/service_locator.dart';
import '../models/post.dart';
import 'points_service.dart';

/// Service responsible for admin-related operations
class AdminService {
  final SupabaseClient? _injectedClient;

  /// Creates an AdminService with optional dependency injection
  AdminService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt or Supabase.instance
  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) {
      return injected;
    }
    // Try getIt first, but fallback to Supabase.instance if not registered
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Checks if the current user has admin privileges.
  /// Returns false if the user is not logged in, the user profile doesn't exist,
  /// or if there's any error during the check.
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        developer.log('User not logged in', name: 'AdminCheck');
        return false;
      }

      // Check if the user is a hardcoded admin (emergency fallback)
      // Note: In production, move these to environment variables for security
      // These should be removed once proper admin management is in place
      final hardcodedAdmins = const String.fromEnvironment(
        'ADMIN_EMAILS',
        defaultValue: 'admin@example.com,123@123.com',
      ).split(',');
      
      if (hardcodedAdmins.contains(user.email)) {
        developer.log('User is hardcoded admin', name: 'AdminCheck');
        return true;
      }

      // Check the user_profiles table for admin status
      developer.log(
        'Checking admin status for user: ${user.email} (${user.id})',
        name: 'AdminCheck',
      );

      final response = await _client
          .from('user_profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      final isAdmin = response?['is_admin'] == true;
      developer.log(
        'Database admin status for ${user.email}: $isAdmin',
        name: 'AdminCheck',
      );
      return isAdmin;
    } on PostgrestException catch (e) {
      developer.log(
        'Database error checking admin status: ${e.message}',
        name: 'AdminCheck',
        error: e,
        stackTrace: StackTrace.current,
      );
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Error checking admin status',
        name: 'AdminCheck',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Check if a specific user is an admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('is_admin')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      return response?['is_admin'] == true;
    } catch (e) {
      developer.log('Error checking user admin status: $e', name: 'AdminService');
      return false;
    }
  }

  /// Set admin status for a user
  Future<void> setUserAdminStatus(String userId, bool isAdmin) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'is_admin': isAdmin,
      });
      developer.log('Set admin status for $userId to $isAdmin',
          name: 'AdminService');
    } catch (e) {
      developer.log('Error setting admin status: $e', name: 'AdminService');
      throw Exception('Failed to set admin status: $e');
    }
  }

  /// Get all reported posts (for admin dashboard)
  Future<List<Map<String, dynamic>>> getReportedPosts() async {
    try {
      final response = await _client
          .from('post_reports')
          .select('*, map_posts(*)')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting reported posts: $e', name: 'AdminService');
      return [];
    }
  }

  /// Update report status
  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      await _client
          .from('post_reports')
          .update({'status': status, 'resolved_at': DateTime.now().toIso8601String()})
          .eq('id', reportId);
    } catch (e) {
      developer.log('Error updating report status: $e', name: 'AdminService');
      throw Exception('Failed to update report status: $e');
    }
  }

  /// Get all unverified map posts
  Future<List<MapPost>> getUnverifiedPosts() async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .or('is_verified.eq.false,is_verified.is.null')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('created_at', ascending: false);

      final posts = (response as List).cast<Map<String, dynamic>>();
      return posts.map((p) => MapPost.fromMap(p)).toList();
    } catch (e) {
      developer.log('Error getting unverified posts: $e', name: 'AdminService');
      return [];
    }
  }

  /// Verify a map post and award points to the creator
  Future<void> verifyMapPost(String postId) async {
    try {
      // 1. Get the post to find the user_id and title
      final postResponse = await _client
          .from('map_posts')
          .select('user_id, title')
          .eq('id', postId)
          .single();
      
      final userId = postResponse['user_id'] as String;
      final title = postResponse['title'] as String;

      // 2. Update the post to verified
      await _client
          .from('map_posts')
          .update({'is_verified': true})
          .eq('id', postId);

      // 3. Award points to the creator
      final pointsService = PointsService();
      await pointsService.awardPoints(
        userId, 
        5.0, 
        'create_post', 
        description: 'Spot verified: $title',
        referenceId: postId,
      );

      developer.log('Verified post $postId and awarded points to $userId', name: 'AdminService');
    } catch (e) {
      developer.log('Error verifying post: $e', name: 'AdminService');
      throw Exception('Failed to verify post: $e');
    }
  }

  /// Get pending videos for moderation
  Future<List<Map<String, dynamic>>> getPendingVideos() async {
    try {
      final response = await _client
          .from('spot_videos')
          .select('*, map_posts(title)')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting pending videos: $e', name: 'AdminService');
      return [];
    }
  }

  /// Approve or reject a video
  Future<void> moderateVideo(String videoId, String status) async {
    try {
      await _client
          .from('spot_videos')
          .update({'status': status, 'moderated_at': DateTime.now().toIso8601String()})
          .eq('id', videoId);
    } catch (e) {
      developer.log('Error moderating video: $e', name: 'AdminService');
      throw Exception('Failed to moderate video: $e');
    }
  }

  /// Get all users (for admin management)
  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 1000}) async {
    try {
      // 1. Fetch user profiles
      final response = await _client
          .from('user_profiles')
          .select('id, username, display_name, email, avatar_url, bio, is_admin, is_verified, is_banned, ban_reason, banned_at, created_at, updated_at, can_post')
          .order('created_at', ascending: false)
          .limit(limit);

      final users = (response as List).cast<Map<String, dynamic>>();
      
      if (users.isEmpty) return [];

      // 2. Fetch wallet balances for these users
      final userIds = users.map((u) => u['id'] as String).toList();
      final walletsResponse = await _client
          .from('user_wallets')
          .select('user_id, balance')
          .filter('user_id', 'in', userIds);

      final wallets = (walletsResponse as List).cast<Map<String, dynamic>>();
      final walletMap = {
        for (var w in wallets) w['user_id'] as String: w['balance'] as num
      };

      // 3. Merge points into user data
      return users.map((u) {
        final userId = u['id'] as String;
        return {
          ...u,
          'points': walletMap[userId] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      developer.log('Error getting users in AdminService: $e', name: 'AdminService');
      
      // Fallback to bare minimum if Level 1 fails (e.g., missing columns)
      try {
        final response = await _client
            .from('user_profiles')
            .select('id, username, display_name, is_admin, created_at')
            .order('created_at', ascending: false)
            .limit(limit);

        return (response as List).cast<Map<String, dynamic>>();
      } catch (e2) {
        developer.log('Critical error getting users: $e2', name: 'AdminService');
        throw Exception('Failed to load users: $e2');
      }
    }
  }

  /// Get point transactions for a specific user
  Future<List<Map<String, dynamic>>> getPointTransactions(String userId) async {
    try {
      final response = await _client
          .from('point_transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting point transactions: $e', name: 'AdminService');
      return [];
    }
  }

  /// Get XP history for a specific user
  Future<List<Map<String, dynamic>>> getXpHistory(String userId) async {
    try {
      final response = await _client
          .from('xp_history')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting XP history: $e', name: 'AdminService');
      return [];
    }
  }

  /// Add a point transaction (Add/Remove points)
  Future<void> addPointTransaction({
    required String userId,
    required double amount,
    required String type,
    String? description,
    String? referenceId,
  }) async {
    try {
      // 1. Insert the transaction
      await _client.from('point_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_type': type,
        'description': description,
        'reference_id': referenceId,
      });

      // 2. Update the user's points in user_wallets
      final walletResponse = await _client
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      final currentBalance = (walletResponse?['balance'] as num?)?.toDouble() ?? 0.0;
      await _client.from('user_wallets').upsert({
        'user_id': userId,
        'balance': currentBalance + amount,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Added transaction of $amount for user $userId', name: 'AdminService');
    } catch (e) {
      developer.log('Error adding point transaction: $e', name: 'AdminService');
      throw Exception('Failed to add point transaction: $e');
    }
  }

  /// Delete a point transaction
  Future<void> deletePointTransaction(String transactionId, String userId, double amount) async {
    try {
      // 1. Delete the transaction
      await _client.from('point_transactions').delete().eq('id', transactionId);

      // 2. Reverse the points in user_wallets
      final walletResponse = await _client
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      final currentBalance = (walletResponse?['balance'] as num?)?.toDouble() ?? 0.0;
      await _client.from('user_wallets').upsert({
        'user_id': userId,
        'balance': currentBalance - amount,
        'updated_at': DateTime.now().toIso8601String(),
      });

      developer.log('Deleted transaction $transactionId and reversed $amount points', name: 'AdminService');
    } catch (e) {
      developer.log('Error deleting point transaction: $e', name: 'AdminService');
      throw Exception('Failed to delete point transaction: $e');
    }
  }

  /// Ban a user
  Future<void> banUser(String userId, String reason) async {
    try {
      await _client.from('user_profiles').update({
        'is_banned': true,
        'ban_reason': reason,
        'banned_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      developer.log('Banned user $userId: $reason', name: 'AdminService');
    } catch (e) {
      developer.log('Error banning user: $e', name: 'AdminService');
      throw Exception('Failed to ban user: $e');
    }
  }

  /// Unban a user
  Future<void> unbanUser(String userId) async {
    try {
      await _client.from('user_profiles').update({
        'is_banned': false,
        'ban_reason': null,
        'banned_at': null,
      }).eq('id', userId);
      developer.log('Unbanned user $userId', name: 'AdminService');
    } catch (e) {
      developer.log('Error unbanning user: $e', name: 'AdminService');
      throw Exception('Failed to unban user: $e');
    }
  }

  /// Toggle posting restriction for a user
  Future<void> togglePostingRestriction(String userId, bool canPost) async {
    try {
      await _client.from('user_profiles').update({
        'can_post': canPost,
      }).eq('id', userId);
      developer.log('Set posting restriction for $userId to $canPost', name: 'AdminService');
    } catch (e) {
      developer.log('Error toggling posting restriction: $e', name: 'AdminService');
      throw Exception('Failed to toggle posting restriction: $e');
    }
  }

  /// Verify a user
  Future<void> verifyUser(String userId) async {
    try {
      await _client.from('user_profiles').update({
        'is_verified': true,
      }).eq('id', userId);
      developer.log('Verified user $userId', name: 'AdminService');
    } catch (e) {
      developer.log('Error verifying user: $e', name: 'AdminService');
      throw Exception('Failed to verify user: $e');
    }
  }

  /// Unverify a user
  Future<void> unverifyUser(String userId) async {
    try {
      await _client.from('user_profiles').update({
        'is_verified': false,
      }).eq('id', userId);
      developer.log('Unverified user $userId', name: 'AdminService');
    } catch (e) {
      developer.log('Error unverifying user: $e', name: 'AdminService');
      throw Exception('Failed to unverify user: $e');
    }
  }

  /// Get app statistics for admin dashboard
  Future<Map<String, dynamic>> getAppStats() async {
    try {
      // Get counts from various tables
      final postsCount = await _client.from('map_posts').select('id');
      final usersCount = await _client.from('user_profiles').select('id');
      final reportsCount = await _client
          .from('post_reports')
          .select('id')
          .eq('status', 'pending');

      return {
        'total_posts': (postsCount as List).length,
        'total_users': (usersCount as List).length,
        'pending_reports': (reportsCount as List).length,
      };
    } catch (e) {
      developer.log('Error getting app stats: $e', name: 'AdminService');
      return {
        'total_posts': 0,
        'total_users': 0,
        'pending_reports': 0,
      };
    }
  }
}
