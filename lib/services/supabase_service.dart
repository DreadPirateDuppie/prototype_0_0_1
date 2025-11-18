import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/post.dart';
import '../models/user_points.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static RealtimeChannel? _activeSkatersChannel;

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

  // Rate a map post
  static Future<void> rateMapPost({
    required String postId,
    required double popularityRating,
    required double securityRating,
    required double qualityRating,
  }) async {
    try {
      await _client
          .from('map_posts')
          .update({
            'popularity_rating': popularityRating,
            'security_rating': securityRating,
            'quality_rating': qualityRating,
          })
          .eq('id', postId);
    } catch (e) {
      throw Exception('Failed to rate post: $e');
    }
  }

  // Report a post for moderation
  static Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    try {
      final user = getCurrentUser();
      await _client.from('post_reports').insert({
        'post_id': postId,
        'reporter_user_id': user?.id,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to report post: $e');
    }
  }

  // Get all reported posts (for admin dashboard)
  static Future<List<Map<String, dynamic>>> getReportedPosts() async {
    try {
      final response = await _client
          .from('post_reports')
          .select('*, map_posts(*)')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
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
        await _client.from('user_points').insert({
          'user_id': userId,
          'points': 0,
        });
        return UserPoints(userId: userId, points: 0);
      }

      return UserPoints.fromMap(response);
    } catch (e) {
      // Return default points if table doesn't exist yet
      return UserPoints(userId: userId, points: 0);
    }
  }

  // Update points after spin
  static Future<UserPoints> updatePointsAfterSpin(
    String userId,
    int pointsWon,
  ) async {
    try {
      final now = DateTime.now();
      final existing = await _client
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        final inserted = await _client
            .from('user_points')
            .insert({
              'user_id': userId,
              'points': pointsWon,
              'last_spin_date': now.toIso8601String(),
            })
            .select()
            .single();
        return UserPoints.fromMap(inserted);
      } else {
        final currentPoints = (existing['points'] as int?) ?? 0;
        final updated = await _client
            .from('user_points')
            .update({
              'points': currentPoints + pointsWon,
              'last_spin_date': now.toIso8601String(),
            })
            .eq('user_id', userId)
            .select()
            .single();
        return UserPoints.fromMap(updated);
      }
    } catch (e) {
      throw Exception('Failed to update points: $e');
    }
  }

  // Presence: Active skaters sharing location
  static Future<void> startLocationSharing({
    required double latitude,
    required double longitude,
    String? spotId,
  }) async {
    final user = getCurrentUser();
    if (user == null) return;

    try {
      _activeSkatersChannel ??=
          _client.channel('active_skaters', opts: const RealtimeChannelConfig(self: true));
      _activeSkatersChannel!.onPresenceSync((_) {});
      _activeSkatersChannel!.subscribe((status, [ref]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          final username = await getUserUsername(user.id) ?? user.email ?? 'Skater';
          await _activeSkatersChannel!.track({
            'user_id': user.id,
            'username': username,
            'lat': latitude,
            'lng': longitude,
            'spot_id': spotId,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      // Silently fail if realtime not available
    }
  }

  static Future<void> stopLocationSharing() async {
    try {
      await _activeSkatersChannel?.untrack();
    } catch (e) {
      // Ignore errors
    }
  }

  static List<Map<String, dynamic>> getActiveSkatersPresence() {
    try {
      final state = _activeSkatersChannel?.presenceState();
      if (state == null) return [];
      final List<Map<String, dynamic>> result = [];
      for (final single in state as List) {
        final dynamic metas = (single as dynamic).metas ?? single['metas'];
        if (metas is List) {
          for (final m in metas) {
            try {
              final dynamic payload = (m as dynamic).payload ?? m['payload'] ?? m;
              if (payload is Map) {
                result.add(Map<String, dynamic>.from(payload));
              }
            } catch (e) {
              // ignore malformed payloads
            }
          }
        }
      }
      return result;
    } catch (e) {
      return [];
    }
  }
}



