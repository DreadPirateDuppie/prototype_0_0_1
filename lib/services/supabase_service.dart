import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/post.dart';

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

  // Get current user display name with fallback
  static Future<String?> getCurrentUserDisplayName() async {
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

  // Get user username
  static Future<String?> getUserUsername(String userId) async {
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

  // Check if username is available
  static Future<bool> isUsernameAvailable(String username) async {
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

  // Save user username (with uniqueness constraint)
  static Future<void> saveUserUsername(
    String userId,
    String username,
  ) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'username': username.toLowerCase().trim(),
      });
    } catch (e) {
      throw Exception('Failed to save username: $e');
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

  // Like a post
  static Future<void> likeMapPost(String postId, int currentLikes) async {
    try {
      await _client
          .from('map_posts')
          .update({'likes': currentLikes + 1}).eq('id', postId);
    } catch (e) {
      // Silently fail
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
}



