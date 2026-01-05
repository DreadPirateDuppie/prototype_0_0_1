import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../config/service_locator.dart';
import '../models/user_scores.dart';
import 'auth_service.dart';

/// Service responsible for user profile operations
class UserService {
  final SupabaseClient? _injectedClient;
  final AuthService _authService = getIt<AuthService>();

  /// Creates a UserService with optional dependency injection
  UserService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt or Supabase.instance
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

  /// Get current user - delegated to AuthService
  User? getCurrentUser() => _authService.getCurrentUser();

  /// Get current session - delegated to AuthService
  Session? getCurrentSession() => _authService.getCurrentSession();

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

    var displayName = user.userMetadata?['display_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    displayName = await getUserDisplayName(user.id);
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

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

  /// Check if username is available (excluding current user's current username if they own it)
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', username.toLowerCase().trim());
      return (response as List).isEmpty;
    } catch (e) {
      return true;
    }
  }

  /// Check if username is available for a specific user (allowing them to keep their own)
  Future<bool> isUsernameAvailableForUser(String username, String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', username.toLowerCase().trim());
      
      final results = response as List;
      if (results.isEmpty) return true;
      
      // If the only person with this username is the user themselves
      return results.length == 1 && results.first['id'] == userId;
    } catch (e) {
      return true;
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

  /// Normalize username for storage (lowercase, trimmed)
  static String normalizeUsername(String username) {
    return username.toLowerCase().trim();
  }

  /// Save user username (with uniqueness constraint)
  Future<void> saveUserUsername(String userId, String username) async {
    try {
      final normalizedUsername = normalizeUsername(username);
      await _client.from('user_profiles').upsert({
        'id': userId,
        'username': normalizedUsername,
        'display_name': username.trim(),
      });

      await _client
          .from('map_posts')
          .update({'user_name': username.trim()})
          .eq('user_id', userId);

      developer.log('Updated username for user $userId', name: 'UserService');
    } catch (e) {
      throw Exception('Failed to save username: $e');
    }
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

  /// Get user bio
  Future<String?> getUserBio(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('bio')
          .eq('id', userId)
          .maybeSingle();
      return response?['bio'] as String?;
    } catch (e) {
      developer.log('Error fetching user bio: $e', name: 'UserService');
      return null;
    }
  }

  /// Save user bio
  Future<void> saveUserBio(String userId, String bio) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'bio': bio.trim(),
      });
    } catch (e) {
      throw Exception('Failed to save bio: $e');
    }
  }

  /// Set user privacy status
  Future<void> setPrivacy(String userId, bool isPrivate) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'is_private': isPrivate,
      });
    } catch (e) {
      developer.log('Error setting privacy: $e', name: 'UserService');
      throw Exception('Failed to set privacy');
    }
  }

  /// Check if user is private
  Future<bool> isUserPrivate(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('is_private')
          .eq('id', userId)
          .maybeSingle();
      return response?['is_private'] as bool? ?? false;
    } catch (e) {
      developer.log('Error checking privacy: $e', name: 'UserService');
      return false; // Default to public on error
    }
  }

  /// Get user age
  Future<int?> getUserAge(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('age')
          .eq('id', userId)
          .maybeSingle();
      return response?['age'] as int?;
    } catch (e) {
      developer.log('Error fetching user age: $e', name: 'UserService');
      return null;
    }
  }

  /// Save user age
  Future<void> saveUserAge(String userId, int age) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'age': age,
      });
    } catch (e) {
      throw Exception('Failed to save age: $e');
    }
  }

  /// Get user profile by ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      developer.log('Error getting user profile: $e', name: 'UserService');
      return null;
    }
  }

  /// Get user scores (delegates to PointService implementation usually, but here as a bridge)
  Future<UserScores?> getUserScores(String userId) async {
    try {
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        return UserScores.fromMap(response);
      }
      return UserScores(userId: userId);
    } catch (e) {
      return null;
    }
  }

  /// Get profile media (gallery images + media from posts)
  Future<List<Map<String, dynamic>>> getProfileMedia(String userId) async {
    try {
      // 1. Fetch media directly uploaded to profile gallery
      final galleryFuture = _client
          .from('profile_media')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      // 2. Fetch posts with media
      final postsFuture = _client
          .from('map_posts')
          .select('id, created_at, photo_urls, photo_url, video_url, title, description')
          .eq('user_id', userId)
          .or('video_url.neq.null,photo_url.neq.null,photo_urls.neq.[]')
          .order('created_at', ascending: false);

      final results = await Future.wait([galleryFuture, postsFuture]);
      final galleryMedia = (results[0] as List).cast<Map<String, dynamic>>();
      final posts = (results[1] as List).cast<Map<String, dynamic>>();

      final List<Map<String, dynamic>> allMedia = [...galleryMedia];

      // 3. Map posts to media structure
      for (var post in posts) {
        // Handle Video
        if (post['video_url'] != null) {
          allMedia.add({
            'id': 'post_video_${post['id']}',
            'user_id': userId,
            'media_url': post['video_url'],
            'media_type': 'video',
            'caption': post['title'] ?? post['description'],
            'created_at': post['created_at'],
            'source': 'post',
            'post_id': post['id'],
          });
        }

        // Handle Images (Priority to photo_urls list, fallback to photo_url)
        List<String> images = [];
        if (post['photo_urls'] != null && (post['photo_urls'] as List).isNotEmpty) {
           images = (post['photo_urls'] as List).cast<String>();
        } else if (post['photo_url'] != null) {
           images = [post['photo_url'] as String];
        }

        for (int i = 0; i < images.length; i++) {
          allMedia.add({
            'id': 'post_image_${post['id']}_$i',
            'user_id': userId,
            'media_url': images[i],
            'media_type': 'image',
            'caption': post['title'] ?? post['description'],
            'created_at': post['created_at'],
            'source': 'post',
            'post_id': post['id'],
          });
        }
      }

      // 4. Sort combined list by created_at descending
      allMedia.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });
      
      return allMedia;
    } catch (e) {
      developer.log('Error fetching profile media: $e', name: 'UserService');
      return [];
    }
  }

  /// Upload media to profile storage
  Future<String> uploadProfileMedia(File file, String userId, String mediaType) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final bucket = mediaType == 'video' ? 'profile_videos' : 'profile_media';
    final path = '$userId/gallery/$fileName';

    await _client.storage.from(bucket).upload(path, file);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Create a profile media record in the database
  Future<void> createProfileMedia({
    required String userId, 
    required String mediaUrl, 
    required String mediaType,
    String? caption,
  }) async {
    await _client.from('profile_media').insert({
      'user_id': userId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
