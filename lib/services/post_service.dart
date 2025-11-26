import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../models/post.dart';
import 'error_types.dart';
import '../config/service_locator.dart';

/// Service responsible for map post operations
class PostService {
  final SupabaseClient? _injectedClient;

  /// Creates a PostService with optional dependency injection
  PostService({SupabaseClient? client}) : _injectedClient = client;

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

  /// Create a map post
  Future<MapPost?> createMapPost({
    required String userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    String? photoUrl,
    String? userName,
    String? userEmail,
    String category = 'Other',
    List<String> tags = const [],
  }) async {
    try {
      final response = await _client
          .from('map_posts')
          .insert({
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
            'category': category,
            'tags': tags,
          })
          .select()
          .single();

      return MapPost.fromMap(response);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error while creating post',
        originalError: e,
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AppConflictException(
          'Duplicate post detected',
          userMessage: 'A similar post already exists at this location.',
          originalError: e,
        );
      }
      throw AppServerException(
        'Database error: ${e.message}',
        userMessage: 'Unable to create post. Please try again.',
        originalError: e,
      );
    } catch (e) {
      throw AppServerException(
        'Failed to create post: $e',
        userMessage: 'Unable to create post. Please try again later.',
        originalError: e,
      );
    }
  }

  /// Get all map posts with optional filters
  Future<List<MapPost>> getAllMapPosts({
    String? category,
    String? tag,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('map_posts').select();

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }

      if (tag != null && tag.isNotEmpty) {
        query = query.contains('tags', [tag]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
            'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
    } catch (e) {
      developer.log('Error getting map posts: $e', name: 'PostService');
      return [];
    }
  }

  /// Search map posts
  Future<List<MapPost>> searchPosts(String query) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
    } catch (e) {
      developer.log('Error searching posts: $e', name: 'PostService');
      return [];
    }
  }

  /// Get all map posts for a specific user
  Future<List<MapPost>> getUserMapPosts(String userId) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
    } catch (e) {
      developer.log('Error getting user posts: $e', name: 'PostService');
      return [];
    }
  }

  /// Update a map post
  Future<MapPost?> updateMapPost({
    required String postId,
    required String title,
    required String description,
    String? photoUrl,
    double? popularityRating,
    double? securityRating,
    double? qualityRating,
    String? category,
    List<String>? tags,
  }) async {
    try {
      final updateData = {
        'title': title,
        'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (popularityRating != null) 'popularity_rating': popularityRating,
        if (securityRating != null) 'security_rating': securityRating,
        if (qualityRating != null) 'quality_rating': qualityRating,
        if (category != null) 'category': category,
        if (tags != null) 'tags': tags,
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

  /// Delete a map post
  Future<void> deleteMapPost(String postId) async {
    try {
      await _client.from('map_posts').delete().eq('id', postId);
    } catch (e) {
      developer.log('Error deleting post: $e', name: 'PostService');
    }
  }

  /// Like a post
  Future<void> likeMapPost(String postId, int currentLikes) async {
    try {
      await _client
          .from('map_posts')
          .update({'likes': currentLikes + 1})
          .eq('id', postId);
    } catch (e) {
      developer.log('Error liking post: $e', name: 'PostService');
    }
  }

  /// Rate a map post (upsert into post_ratings)
  Future<void> rateMapPost({
    required String postId,
    required String userId,
    required double popularityRating,
    required double securityRating,
    required double qualityRating,
  }) async {
    try {
      // Upsert into post_ratings table
      await _client.from('post_ratings').upsert({
        'post_id': postId,
        'user_id': userId,
        'popularity_rating': popularityRating,
        'security_rating': securityRating,
        'quality_rating': qualityRating,
      }, onConflict: 'post_id, user_id');
    } catch (e) {
      developer.log('Error rating post: $e', name: 'PostService');
      // Fallback for when trigger/table doesn't exist yet
      try {
        await _client.from('map_posts').update({
          'popularity_rating': popularityRating,
          'security_rating': securityRating,
          'quality_rating': qualityRating,
        }).eq('id', postId);
      } catch (fallbackError) {
        throw Exception('Failed to rate post: $fallbackError');
      }
    }
  }

  /// Vote on a post (1 = upvote, -1 = downvote)
  Future<void> votePost({
    required String postId,
    required String voterId,
    required int voteType,
  }) async {
    try {
      // Get current vote if exists
      final existingVote = await _client
          .from('post_votes')
          .select('vote_type')
          .eq('post_id', postId)
          .eq('user_id', voterId)
          .maybeSingle();

      final currentVote = existingVote?['vote_type'] as int?;

      if (currentVote == voteType) {
        // Same vote - remove it
        await _client
            .from('post_votes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', voterId);
      } else if (currentVote != null) {
        // Different vote - update it
        await _client.from('post_votes').update({
          'vote_type': voteType,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('post_id', postId).eq('user_id', voterId);
      } else {
        // New vote - insert it
        await _client.from('post_votes').insert({
          'post_id': postId,
          'user_id': voterId,
          'vote_type': voteType,
        });
      }
    } catch (e) {
      throw Exception('Failed to vote: $e');
    }
  }

  /// Get user's current vote on a post
  Future<int?> getUserVote(String postId, String userId) async {
    try {
      final response = await _client
          .from('post_votes')
          .select('vote_type')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response?['vote_type'] as int?;
    } catch (e) {
      return null;
    }
  }

  /// Report a post for moderation
  Future<void> reportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
    String? details,
  }) async {
    try {
      await _client.from('post_reports').insert({
        'post_id': postId,
        'reporter_user_id': reporterUserId,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error while reporting post',
        originalError: e,
      );
    } catch (e) {
      throw AppServerException(
        'Failed to report post: $e',
        userMessage: 'Unable to submit report. Please try again.',
        originalError: e,
      );
    }
  }

  /// Toggle save post status
  Future<bool> toggleSavePost(String postId, String userId) async {
    try {
      // Check if already saved
      final existing = await _client
          .from('saved_posts')
          .select()
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        // Unsave
        await _client
            .from('saved_posts')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
        return false;
      } else {
        // Save
        await _client.from('saved_posts').insert({
          'user_id': userId,
          'post_id': postId,
        });
        return true;
      }
    } catch (e) {
      developer.log('Error toggling save post: $e', name: 'PostService');
      rethrow;
    }
  }

  /// Check if post is saved
  Future<bool> isPostSaved(String postId, String userId) async {
    try {
      final response = await _client
          .from('saved_posts')
          .select()
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get user's saved posts
  Future<List<MapPost>> getSavedPosts(String userId) async {
    try {
      final savedData = await _client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (savedData.isEmpty) return [];

      final postIds =
          (savedData as List).map((e) => e['post_id'] as String).toList();

      final postsData =
          await _client.from('map_posts').select().filter('id', 'in', postIds);

      final posts =
          (postsData as List).map((data) => MapPost.fromMap(data)).toList();

      // Sort to match saved order
      final postMap = {for (var p in posts) p.id!: p};
      return postIds
          .map((id) => postMap[id])
          .where((p) => p != null)
          .cast<MapPost>()
          .toList();
    } catch (e) {
      developer.log('Error getting saved posts: $e', name: 'PostService');
      return [];
    }
  }

  /// Upload post image to Supabase storage
  Future<String> uploadPostImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'post_${userId}_$timestamp.jpg';

      final bytes = await imageFile.readAsBytes();
      await _client.storage.from('post_images').uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      return _client.storage.from('post_images').getPublicUrl(filename);
    } catch (e) {
      throw AppStorageException(
        'Failed to upload image: $e',
        userMessage: 'Image upload failed. Please try again.',
        originalError: e,
      );
    }
  }
}
