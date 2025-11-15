import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/post.dart';
import '../models/user_points.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Get current user session
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // Get current session
  static Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  // Get user display name
  static Future<String?> getUserDisplayName(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      return response?['display_name'];
    } catch (e) {
      // Silently fail - table may not exist yet
      return null;
    }
  }

  // Get user role
  static Future<String?> getUserRole(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] ?? 'user';
    } catch (e) {
      // Silently fail - table may not exist yet
      return 'user';
    }
  }

  // Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = getCurrentUser();
    if (user == null) return false;
    final role = await getUserRole(user.id);
    return role == 'admin';
  }

  // Save user display name
  static Future<void> saveUserDisplayName(
    String userId,
    String displayName,
  ) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'display_name': displayName,
      });
    } catch (e) {
      // Silently fail - table may not exist yet
    }
  }

  // Sign up with email and password
  static Future<AuthResponse> signUp(
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

  // Sign in with email and password
  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google via Supabase
  static Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Listen to auth state changes
  static Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  // Upload post image to Supabase storage
  static Future<String> uploadPostImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'post_${userId}_$timestamp.jpg';
      
      final bytes = await imageFile.readAsBytes();
      await _client.storage.from('post_images').uploadBinary(
        filename,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final publicUrl = _client.storage
          .from('post_images')
          .getPublicUrl(filename);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Create a map post
  static Future<MapPost?> createMapPost({
    required String userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    String? photoUrl,
    String? userName,
    String? userEmail,
  }) async {
    try {
      final response = await _client.from('map_posts').insert({
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'latitude': latitude,
        'longitude': longitude,
        'title': title,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
        'likes': 0,
        'photo_url': photoUrl,
      }).select().single();

      return MapPost.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Get all map posts
  static Future<List<MapPost>> getAllMapPosts() async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((post) => MapPost.fromMap(post))
          .toList();
    } catch (e) {
      // Table may not exist yet
      return [];
    }
  }

  // Get user's map posts
  static Future<List<MapPost>> getUserMapPosts(String userId) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((post) => MapPost.fromMap(post))
          .toList();
    } catch (e) {
      // Table may not exist yet
      return [];
    }
  }

  // Delete a map post
  static Future<void> deleteMapPost(String postId) async {
    try {
      await _client.from('map_posts').delete().eq('id', postId);
    } catch (e) {
      // Silently fail
    }
  }

  // Like a post (new implementation with individual tracking)
  static Future<bool> likeMapPost(String postId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;

      // Check if user already liked this post
      final existingLike = await _client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        // User already liked, so unlike
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
        return false; // Return false to indicate unliked
      } else {
        // User hasn't liked, so add like
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
        return true; // Return true to indicate liked
      }
    } catch (e) {
      // Silently fail
      return false;
    }
  }

  // Check if current user has liked a post
  static Future<bool> hasUserLikedPost(String postId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;

      final response = await _client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Rate a post
  static Future<void> rateMapPost({
    required String postId,
    required int popularityRating,
    required int securityRating,
    required int qualityRating,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

      await _client.from('post_ratings').upsert({
        'post_id': postId,
        'user_id': user.id,
        'popularity_rating': popularityRating,
        'security_rating': securityRating,
        'quality_rating': qualityRating,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Get user's rating for a post
  static Future<Map<String, int>?> getUserRatingForPost(String postId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final response = await _client
          .from('post_ratings')
          .select('popularity_rating, security_rating, quality_rating')
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return {
          'popularity': response['popularity_rating'] as int,
          'security': response['security_rating'] as int,
          'quality': response['quality_rating'] as int,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update a map post
  static Future<MapPost?> updateMapPost({
    required String postId,
    required String title,
    required String description,
    String? photoUrl,
  }) async {
    try {
      final updateData = {
        'title': title,
        'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
      };

      final response = await _client
          .from('map_posts')
          .update(updateData)
          .eq('id', postId)
          .select()
          .single();

      return MapPost.fromMap(response);
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Update post user name (when display name changes)
  static Future<void> updatePostUserName(String userId, String userName) async {
    try {
      await _client
          .from('map_posts')
          .update({'user_name': userName})
          .eq('user_id', userId);
    } catch (e) {
      // Silently fail
    }
  }

  // Get user points
  static Future<UserPoints> getUserPoints(String userId) async {
    try {
      final response = await _client
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create initial points record if it doesn't exist
        final newPoints = UserPoints(userId: userId, points: 0);
        await _client.from('user_points').insert(newPoints.toMap());
        return newPoints;
      }

      return UserPoints.fromMap(response);
    } catch (e) {
      // Return default points if table doesn't exist
      return UserPoints(userId: userId, points: 0);
    }
  }

  // Update user points after wheel spin
  static Future<UserPoints> updatePointsAfterSpin(
    String userId,
    int pointsToAdd,
  ) async {
    try {
      final currentPoints = await getUserPoints(userId);
      final newPoints = currentPoints.points + pointsToAdd;
      
      final updateData = {
        'user_id': userId,
        'points': newPoints,
        'last_spin_date': DateTime.now().toIso8601String(),
      };

      await _client.from('user_points').upsert(updateData);

      return UserPoints(
        userId: userId,
        points: newPoints,
        lastSpinDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to update points: $e');
    }
  }
}



