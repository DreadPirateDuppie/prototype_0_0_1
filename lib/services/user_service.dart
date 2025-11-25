import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:async' as async;
import 'error_types.dart';
import '../config/service_locator.dart';

/// Service responsible for user profile operations
class UserService {
  final SupabaseClient? _injectedClient;

  /// Creates a UserService with optional dependency injection
  UserService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt
  SupabaseClient get _client =>
      _injectedClient ?? getIt<SupabaseClient>();

  /// Get current user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  /// Get user display name
  Future<String?> getUserDisplayName(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      return response?['display_name'];
    } catch (e) {
      developer.log('Error getting display name: $e', name: 'UserService');
      return null;
    }
  }

  /// Get current user display name with fallback
  Future<String?> getCurrentUserDisplayName() async {
    final user = getCurrentUser();
    if (user == null) return null;

    // Try to get from user metadata first
    var displayName = user.userMetadata?['display_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    // Try to get from user_profiles table
    displayName = await getUserDisplayName(user.id);
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    // Fallback to email prefix
    return user.email?.split('@').first ?? 'User';
  }

  /// Get user username
  Future<String?> getUserUsername(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      return response?['username'];
    } catch (e) {
      return null;
    }
  }

  /// Get user avatar URL
  Future<String?> getUserAvatarUrl(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return response?['avatar_url'];
    } catch (e) {
      return null;
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', username);
      return (response as List).isEmpty;
    } catch (e) {
      return true; // Assume available if query fails
    }
  }

  /// Save user display name
  Future<void> saveUserDisplayName(String userId, String displayName) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'display_name': displayName,
      });
    } catch (e) {
      developer.log('Error saving display name: $e', name: 'UserService');
    }
  }

  /// Save user username (with uniqueness constraint)
  Future<void> saveUserUsername(String userId, String username) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'username': username.toLowerCase().trim(),
        'display_name': username.trim(),
      });

      // Update all posts by this user
      await _client
          .from('map_posts')
          .update({'user_name': username.trim()})
          .eq('user_id', userId);

      developer.log('Updated username for user $userId', name: 'UserService');
    } catch (e) {
      throw Exception('Failed to save username: $e');
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (displayName != null && response.user != null) {
      await saveUserDisplayName(response.user!.id, displayName);
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AppAuthException(
        'Authentication failed: ${e.message}',
        userMessage: 'Invalid email or password. Please try again.',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error during sign in',
        originalError: e,
      );
    } on async.TimeoutException catch (e) {
      throw AppTimeoutException(
        'Sign in request timed out',
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        'Sign in failed: $e',
        userMessage: 'Unable to sign in. Please check your credentials.',
        originalError: e,
      );
    }
  }

  /// Sign in with Google via Supabase
  Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(OAuthProvider.google);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error during Google sign in',
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        'Google Sign-In failed: $e',
        userMessage: 'Unable to sign in with Google. Please try again.',
        originalError: e,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Listen to auth state changes
  Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  /// Upload profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'profiles/avatar_${userId}_$timestamp.jpg';

      final bytes = await imageFile.readAsBytes();
      await _client.storage.from('post_images').uploadBinary(
            filename,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final publicUrl =
          _client.storage.from('post_images').getPublicUrl(filename);

      // Update user profile with new avatar URL
      await _client.from('user_profiles').upsert({
        'id': userId,
        'avatar_url': publicUrl,
      });

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      developer.log('Error marking notification read: $e', name: 'UserService');
    }
  }

  /// Create a notification
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log('Error creating notification: $e', name: 'UserService');
    }
  }

  /// Submit user feedback
  Future<void> submitFeedback(String feedbackText, {String? userId}) async {
    try {
      await _client.from('user_feedback').insert({
        'user_id': userId,
        'feedback_text': feedbackText,
      });
    } catch (e) {
      developer.log('Error submitting feedback: $e', name: 'UserService');
      throw Exception('Failed to submit feedback');
    }
  }
}
