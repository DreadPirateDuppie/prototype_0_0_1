import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../config/service_locator.dart';

/// Service responsible for admin-related operations
class AdminService {
  final SupabaseClient? _injectedClient;

  /// Creates an AdminService with optional dependency injection
  AdminService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt
  SupabaseClient get _client =>
      _injectedClient ?? getIt<SupabaseClient>();

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

      // Check if the user is the hardcoded admin
      if (user.email == 'admin@example.com' || user.email == '123@123.com') {
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
  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 50, int offset = 0}) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting all users: $e', name: 'AdminService');
      return [];
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
