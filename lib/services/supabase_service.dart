import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:async' as async;
import '../models/post.dart';
import 'error_types.dart';
import 'admin_service.dart';
import 'user_service.dart';
import 'points_service.dart';

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

  // Get user display name - delegates to UserService
  static Future<String?> getUserDisplayName(String userId) async {
    final userService = UserService();
    return userService.getUserDisplayName(userId);
  }

  // Get current user display name with fallback - delegates to UserService
  static Future<String?> getCurrentUserDisplayName() async {
    final userService = UserService();
    return userService.getCurrentUserDisplayName();
  }

  // Get user username - delegates to UserService
  static Future<String?> getUserUsername(String userId) async {
    final userService = UserService();
    return userService.getUserUsername(userId);
  }

  // Get user avatar URL - delegates to UserService
  static Future<String?> getUserAvatarUrl(String userId) async {
    final userService = UserService();
    return userService.getUserAvatarUrl(userId);
  }

  /// Checks if the current user has admin privileges.
  /// Delegates to AdminService for consistent admin checking.
  /// Returns false if the user is not logged in, the user profile doesn't exist,
  /// or if there's any error during the check.
  static Future<bool> isCurrentUserAdmin() async {
    // Delegate to AdminService to avoid duplicate logic
    final adminService = AdminService();
    return adminService.isCurrentUserAdmin();
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

  // Check if username is available for a specific user (excludes their own current username)
  static Future<bool> isUsernameAvailableForUser(String username, String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', username.toLowerCase().trim())
          .neq('id', userId);  // Exclude current user
      return (response as List).isEmpty;
    } catch (e) {
      developer.log('Error checking username availability: $e', name: 'SupabaseService');
      return true; // Assume available if query fails
    }
  }

  // Search for users by username or display name (excludes current user)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return [];

      final response = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error searching users: $e', name: 'SupabaseService');
      return [];
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
      developer.log('Error saving display name: $e', name: 'SupabaseService');
      // Silently fail - table may not exist yet
    }
  }

  // Save user username (with uniqueness constraint)
  static Future<void> saveUserUsername(String userId, String username) async {
    try {
      // Update user profile
      await _client.from('user_profiles').upsert({
        'id': userId,
        'username': username.toLowerCase().trim(),
        'display_name': username.trim(), // Also update display name for consistency
      });
      
      // Update all posts by this user to reflect the new username
      await _client
          .from('map_posts')
          .update({'user_name': username.trim()})
          .eq('user_id', userId);
          
      developer.log('Updated username for user $userId and all their posts', name: 'SupabaseService');
    } catch (e) {
      throw Exception('Failed to save username: $e');
    }
  }

  // ========== FOLLOW SYSTEM ==========

  /// Follow a user
  static Future<void> followUser(String userIdToFollow) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');
      
      if (currentUser.id == userIdToFollow) {
        throw Exception('Cannot follow yourself');
      }

      await _client.from('follows').insert({
        'follower_id': currentUser.id,
        'following_id': userIdToFollow,
      });
      
      developer.log('User ${currentUser.id} followed $userIdToFollow', name: 'SupabaseService');
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  /// Unfollow a user
  static Future<void> unfollowUser(String userIdToUnfollow) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');

      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', userIdToUnfollow);
      
      developer.log('User ${currentUser.id} unfollowed $userIdToUnfollow', name: 'SupabaseService');
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  /// Check if current user is following a specific user
  static Future<bool> isFollowing(String userId) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return false;

      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      developer.log('Error checking follow status: $e', name: 'SupabaseService');
      return false;
    }
  }

  /// Get list of users who follow the specified user
  static Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      // Get follower IDs
      final followsResponse = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      final followerIds = (followsResponse as List)
          .map((f) => f['follower_id'] as String)
          .toList();

      if (followerIds.isEmpty) return [];

      // Get user profiles for followers
      final profilesResponse = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url')
          .filter('id', 'in', followerIds);

      return (profilesResponse as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting followers: $e', name: 'SupabaseService');
      return [];
    }
  }

  /// Get list of users that the specified user is following
  static Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      // Get following IDs
      final followsResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = (followsResponse as List)
          .map((f) => f['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      // Get user profiles for following
      final profilesResponse = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url')
          .filter('id', 'in', followingIds);

      return (profilesResponse as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting following: $e', name: 'SupabaseService');
      return [];
    }
  }

  /// Get mutual followers - users who follow you AND you follow back
  static Future<List<Map<String, dynamic>>> getMutualFollowers() async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return [];

      // Get users who follow me
      final myFollowers = await getFollowers(currentUser.id);
      final followerIds = myFollowers.map((f) => f['id'] as String).toSet();

      // Get users I follow
      final myFollowing = await getFollowing(currentUser.id);
      final followingIds = myFollowing.map((f) => f['id'] as String).toSet();

      // Find intersection (mutual follows)
      final mutualIds = followerIds.intersection(followingIds).toList();

      if (mutualIds.isEmpty) return [];

      // Return user profiles for mutual followers
      return myFollowers.where((user) => mutualIds.contains(user['id'])).toList();
    } catch (e) {
      developer.log('Error getting mutual followers: $e', name: 'SupabaseService');
      return [];
    }
  }

  /// Get follower and following counts for a user
  static Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      // Count followers
      final followersCount = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('following_id', userId);
      
      // Count following
      final followingCount = await _client
          .from('follows')
          .count(CountOption.exact)
          .eq('follower_id', userId);
      
      return {
        'followers': followersCount,
        'following': followingCount,
      };
    } catch (e) {
      developer.log('Error getting follow counts: $e', name: 'SupabaseService');
      return {'followers': 0, 'following': 0};
    }
  }

  /// Get a random opponent for quick match
  /// Prioritizes mutual followers, falls back to any user if mutualOnly is false
  static Future<String?> getRandomOpponent({bool mutualOnly = false}) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return null;

      // Try to get mutual followers first
      final mutualFollowers = await getMutualFollowers();
      
      if (mutualFollowers.isNotEmpty) {
        mutualFollowers.shuffle();
        return mutualFollowers.first['id'] as String;
      }

      // If mutualOnly is true and no mutual followers found, return null
      if (mutualOnly) return null;

      // Fall back to any random user (excluding self)
      final usersResponse = await _client
          .from('user_profiles')
          .select('id')
          .neq('id', currentUser.id)
          .limit(100);  // Get up to 100 users

      final users = (usersResponse as List).cast<Map<String, dynamic>>();
      if (users.isEmpty) return null;

      users.shuffle();
      return users.first['id'] as String;
    } catch (e) {
      developer.log('Error getting random opponent: $e', name: 'SupabaseService');
      return null;
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
        userMessage: 'Unable to sign in. Please check your credentials and try again.',
        originalError: e,
      );
    }
  }

  // Sign in with Google via Supabase
  static Future<bool> signInWithGoogle() async {
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
      await _client.storage
          .from('post_images')
          .uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _client.storage
          .from('post_images')
          .getPublicUrl(filename);
      return publicUrl;
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error during image upload',
        originalError: e,
      );
    } on async.TimeoutException catch (e) {
      throw AppTimeoutException(
        'Image upload timed out',
        userMessage: 'Upload is taking too long. Please check your connection and try again.',
        originalError: e,
      );
    } on FileSystemException catch (e) {
      throw AppStorageException(
        'File system error: $e',
        userMessage: 'Unable to read the image file. Please try selecting it again.',
        originalError: e,
      );
    } catch (e) {
      throw AppStorageException(
        'Failed to upload image: $e',
        userMessage: 'Image upload failed. Please try again.',
        originalError: e,
      );
    }
  }

  // Upload profile image
  // Upload profile image - delegates to UserService
  static Future<String> uploadProfileImage(File imageFile, String userId) async {
    final userService = UserService();
    return userService.uploadProfileImage(imageFile, userId);
  }

  // Create a map post
  static Future<MapPost?> createMapPost({
    required String userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    String? photoUrl,
    String? userName,  // Deprecated - will fetch from user_profiles
    String? userEmail,  // Deprecated - will fetch from user
    String category = 'Other',
    List<String> tags = const [],
  }) async {
    try {
      // Fetch current username from user_profiles
      final currentUsername = await getUserDisplayName(userId);
      final user = getCurrentUser();
      
      final response = await _client
          .from('map_posts')
          .insert({
            'user_id': userId,
            'user_name': currentUsername ?? user?.email?.split('@')[0],
            'user_email': user?.email,
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

      final post = MapPost.fromMap(response);
      
      // Award XP for creating a post (e.g., 15 XP)
    await _updatePosterXP(userId, 15);
    
    // Award Points for creating a post (4.20 Points)
    await awardPoints(userId, 3.5, 'post_reward', referenceId: post.id, description: 'Created a new spot');
    
    return post;
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

  // Recalculate user XP based on posts and votes
  // Recalculate user XP - delegates to PointsService
  static Future<void> recalculateUserXP(String userId) async {
    final pointsService = PointsService();
    return pointsService.recalculateUserXP(userId);
  }

  // Get all map posts with optional filters
  static Future<List<MapPost>> getAllMapPosts({
    String? category,
    String? tag,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('map_posts')
          .select();

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }

      if (tag != null && tag.isNotEmpty) {
        query = query.contains('tags', [tag]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);
      final posts = (response as List).cast<Map<String, dynamic>>();

      // Fetch user profiles for these posts to get up-to-date display names
      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      Map<String, String> userNames = {};
      
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await _client
              .from('user_profiles')
              .select('id, display_name, username')
              .filter('id', 'in', userIds);
              
          for (final profile in (profilesResponse as List)) {
            final id = profile['id'] as String;
            final name = profile['display_name'] as String? ?? profile['username'] as String?;
            if (name != null) {
              userNames[id] = name;
            }
          }
        } catch (e) {
          developer.log('Error fetching profiles: $e', name: 'SupabaseService');
        }
      }

      return posts.map((post) {
        final userId = post['user_id'] as String;
        if (userNames.containsKey(userId)) {
          post['user_name'] = userNames[userId];
        }
        return MapPost.fromMap(post);
      }).toList();
    } catch (e) {
      // Table may not exist yet
      return [];
    }
  }

  // Search map posts
  static Future<List<MapPost>> searchPosts(String query) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
    } catch (e) {
      return [];
    }
  }

  // Get all map posts for a specific user
  static Future<List<MapPost>> getUserMapPosts(String userId) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final posts = (response as List).cast<Map<String, dynamic>>();
      
      // Fetch current username to ensure consistency
      String? currentUsername;
      try {
        currentUsername = await getUserDisplayName(userId);
      } catch (e) {
        // Ignore error, will fallback
      }

      return posts.map((post) {
        if (currentUsername != null) {
          post['user_name'] = currentUsername;
        } else {
          // Clear email if no username set
          post['user_name'] = null;
        }
        return MapPost.fromMap(post);
      }).toList();
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
      developer.log('Error deleting post: $e', name: 'SupabaseService');
      // Silently fail
    }
  }

  // Like a post
  static Future<void> likeMapPost(String postId, int currentLikes) async {
    try {
      await _client
          .from('map_posts')
          .update({'likes': currentLikes + 1})
          .eq('id', postId);
    } catch (e) {
      developer.log('Error liking post: $e', name: 'SupabaseService');
      // Silently fail
    }
  }

  // Update a map post
  static Future<MapPost?> updateMapPost({
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

  // Rate a map post
  static Future<void> rateMapPost({
    required String postId,
    required double popularityRating,
    required double securityRating,
    required double qualityRating,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Upsert into post_ratings table
      // The database trigger will handle updating the average on map_posts
      await _client.from('post_ratings').upsert({
        'post_id': postId,
        'user_id': user.id,
        'popularity_rating': popularityRating,
        'security_rating': securityRating,
        'quality_rating': qualityRating,
      }, onConflict: 'post_id, user_id');
    } catch (e) {
      developer.log('Error rating post: $e', name: 'SupabaseService');
      // Fallback for when trigger/table doesn't exist yet (maintain old behavior for now)
      try {
        await _client
            .from('map_posts')
            .update({
              'popularity_rating': popularityRating,
              'security_rating': securityRating,
              'quality_rating': qualityRating,
            })
            .eq('id', postId);
      } catch (fallbackError) {
        throw Exception('Failed to rate post: $fallbackError');
      }
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
      if (user == null) {
        throw AppAuthException(
          'User not authenticated',
          userMessage: 'Please sign in to report posts.',
        );
      }
      
      await _client.from('post_reports').insert({
        'post_id': postId,
        'reporter_user_id': user.id,
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

  // ========== VOTING SYSTEM ==========

  // Vote on a post (1 = upvote, -1 = downvote)
  static Future<void> votePost(String postId, int voteType) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Get the post to check if user is the poster
      final postResponse = await _client
          .from('map_posts')
          .select('user_id')
          .eq('id', postId)
          .single();
      
      final postUserId = postResponse['user_id'] as String;
      
      // Don't allow voting on own posts
      if (postUserId == user.id) {
        throw Exception('Cannot vote on your own post');
      }

      // Get current vote if exists
      final currentVote = await getUserVote(postId);
      
      if (currentVote == voteType) {
        // Same vote - remove it
        await removeVote(postId);
      } else if (currentVote != null) {
        // Different vote - update it
        await _client
            .from('post_votes')
            .update({
              'vote_type': voteType,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('post_id', postId)
            .eq('user_id', user.id);
        
        // Update XP: if changing from downvote to upvote or vice versa
        if (currentVote == -1 && voteType == 1) {
          // Changed from downvote to upvote: +1 XP
          await _updatePosterXP(postUserId, 1);
        } else if (currentVote == 1 && voteType == -1) {
          // Changed from upvote to downvote: -1 XP
          await _updatePosterXP(postUserId, -1);
        }
      } else {
        // New vote - insert it
        await _client.from('post_votes').insert({
          'post_id': postId,
          'user_id': user.id,
          'vote_type': voteType,
        });
        
        // Award XP only for upvotes
      if (voteType == 1) {
        await _updatePosterXP(postUserId, 1);
        // Award Points to poster for receiving an upvote (e.g., 5 Points)
        await awardPoints(postUserId, 5, 'upvote_reward', referenceId: postId, description: 'Received an upvote');
      }
      } // Close else
    } catch (e) {
      throw Exception('Failed to vote: $e');
    }
  }

  // Remove user's vote from a post
  static Future<void> removeVote(String postId) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Get current vote to determine XP change
      final currentVote = await getUserVote(postId);
      
      if (currentVote != null) {
        // Get post user ID for XP update
        final postResponse = await _client
            .from('map_posts')
            .select('user_id')
            .eq('id', postId)
            .single();
        
        final postUserId = postResponse['user_id'] as String;
        
        // Delete the vote
        await _client
            .from('post_votes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
        
        // Remove XP only if it was an upvote
        if (currentVote == 1) {
          await _updatePosterXP(postUserId, -1);
        }
      }
    } catch (e) {
      throw Exception('Failed to remove vote: $e');
    }
  }

  // Get user's current vote on a post (-1, 0, or 1)
  static Future<int?> getUserVote(String postId) async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final response = await _client
          .from('post_votes')
          .select('vote_type')
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response?['vote_type'] as int?;
    } catch (e) {
      return null;
    }
  }

  // Update poster's map score (XP) based on votes
  static Future<void> _updatePosterXP(String userId, int xpChange) async {
    try {
      // Get current map score
      final response = await _client
          .from('user_scores')
          .select('map_score')
          .eq('user_id', userId)
          .maybeSingle();

      final currentScore = (response?['map_score'] as num?)?.toDouble() ?? 0.0;
      final newScore = (currentScore + xpChange).clamp(0.0, double.infinity);

      // Update map score
      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': newScore,
      });
    } catch (e) {
      developer.log('Error updating poster XP: $e', name: 'SupabaseService');
      // Silently fail - don't block voting if XP update fails
    }
  }

  // Get all map posts with user's vote status
  static Future<List<MapPost>> getAllMapPostsWithVotes() async {
    try {
      final user = getCurrentUser();
      
      // Get all posts with vote counts
      final postsResponse = await _client
          .from('map_posts')
          .select()
          .order('created_at', ascending: false);

      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      
      // Fetch user profiles for these posts to get up-to-date display names
      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      Map<String, String> userNames = {};
      
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await _client
              .from('user_profiles')
              .select('id, display_name, username')
              .filter('id', 'in', userIds);
              
          for (final profile in (profilesResponse as List)) {
            final id = profile['id'] as String;
            final name = profile['display_name'] as String? ?? profile['username'] as String?;
            if (name != null) {
              userNames[id] = name;
            }
          }
        } catch (e) {
          developer.log('Error fetching profiles: $e', name: 'SupabaseService');
          // Continue without profiles if this fails
        }
      }

      // Get user's votes for all posts if logged in
      Map<String, int> voteMap = {};
      if (user != null) {
        final votesResponse = await _client
            .from('post_votes')
            .select('post_id, vote_type')
            .eq('user_id', user.id);

        final votes = (votesResponse as List).cast<Map<String, dynamic>>();
        voteMap = {for (var v in votes) v['post_id']: v['vote_type']};
      }

      // Combine posts with vote info and user names
      return posts.map((post) {
        final postId = post['id'] as String;
        final userId = post['user_id'] as String;
        
        post['user_vote'] = voteMap[postId];
        
        // Use fetched profile name if available
        if (userNames.containsKey(userId)) {
          post['user_name'] = userNames[userId];
        } else {
          // Clear email from user_name if no username is set
          // This ensures UI shows 'User' instead of email
          post['user_name'] = null;
        }
        
        return MapPost.fromMap(post);
      }).toList();
    } catch (e) {
      developer.log('Error getting posts with votes: $e', name: 'SupabaseService');
      // Fallback to regular posts
      return getAllMapPosts();
    }
  }
  // --- Rewards & Points System ---

  // Get user wallet balance
  static Future<double> getUserPoints(String userId) async {
    try {
      final response = await _client
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      return (response?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      developer.log('Error getting user points: $e', name: 'SupabaseService');
      return 0.0;
    }
  }

  // Get user daily streak
  static Future<Map<String, dynamic>> getUserStreak(String userId) async {
    try {
      final response = await _client
          .from('daily_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) {
        return {
          'current_streak': 0,
          'longest_streak': 0,
          'last_login_date': null,
        };
      }
      
      return response;
    } catch (e) {
      developer.log('Error getting user streak: $e', name: 'SupabaseService');
      return {
        'current_streak': 0,
        'longest_streak': 0,
        'last_login_date': null,
      };
    }
  }

  // Check and update daily streak
  // Returns the amount of points awarded, or 0.0 if already claimed today
  static Future<double> checkDailyStreak() async {
    try {
      final user = getCurrentUser();
      if (user == null) return 0.0;

      // Get current streak data
      final streakData = await getUserStreak(user.id);
      final currentStreak = streakData['current_streak'] as int;
      final longestStreak = streakData['longest_streak'] as int;
      final lastLoginStr = streakData['last_login_date'] as String?;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // If never logged in before
      if (lastLoginStr == null) {
        await _updateStreak(user.id, 1, 1, today);
        const points = 1.0;
        await awardPoints(user.id, points, 'daily_login', description: 'Daily check-in');
        return points;
      }

      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      
      final difference = today.difference(lastLoginDate).inDays;

      if (difference == 0) {
        // Already logged in today, check if points were actually awarded
        final hasTransaction = await _hasDailyLoginTransaction(user.id, today);
        if (hasTransaction) {
          return 0.0;
        }
        // If no transaction, proceed to award points (retry)
        const points = 1.0;
        await awardPoints(user.id, points, 'daily_login', description: 'Daily check-in (Retry)');
        return points;
      } else if (difference == 1) {
        // Logged in yesterday, increment streak
        final newStreak = currentStreak + 1;
        final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
        await _updateStreak(user.id, newStreak, newLongest, today);
        
        const points = 1.0;
        await awardPoints(user.id, points, 'daily_login', description: 'Daily check-in: $newStreak day streak');
        return points;
      } else {
        // Missed a day (or more), reset streak
        await _updateStreak(user.id, 1, longestStreak, today);
        const points = 1.0;
        await awardPoints(user.id, points, 'daily_login', description: 'Daily check-in (streak reset)');
        return points;
      }
    } catch (e) {
      developer.log('Error checking daily streak: $e', name: 'SupabaseService');
      rethrow; // Rethrow to let UI handle/display error
    }
  }

  static Future<bool> _hasDailyLoginTransaction(String userId, DateTime date) async {
    try {
      // date is assumed to be Local midnight
      // Convert start and end of local day to UTC for database query
      final startOfDay = date.toUtc().toIso8601String();
      final endOfDay = date.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)).toUtc().toIso8601String();

      final response = await _client
          .from('point_transactions')
          .select('id')
          .eq('user_id', userId)
          .eq('transaction_type', 'daily_login')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _updateStreak(String userId, int streak, int longest, DateTime date) async {
    await _client.from('daily_streaks').upsert({
      'user_id': userId,
      'current_streak': streak,
      'longest_streak': longest,
      'last_login_date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> awardPoints(
    String userId, 
    double amount, 
    String type, 
    {String? referenceId, String? description}
  ) async {
    try {
      developer.log('Attempting to award $amount points to $userId for $type', name: 'SupabaseService');
      
      // 1. Update wallet balance
      // First ensure wallet exists
      final currentPoints = await getUserPoints(userId);
      developer.log('Current points: $currentPoints', name: 'SupabaseService');
      final newBalance = currentPoints + amount;
      
      final walletResult = await _client.from('user_wallets').upsert({
        'user_id': userId,
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      }).select();
      developer.log('Wallet upsert result: $walletResult', name: 'SupabaseService');

      // 2. Log transaction
      final transactionResult = await _client.from('point_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_type': type,
        'reference_id': referenceId,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      developer.log('Transaction insert result: $transactionResult', name: 'SupabaseService');
      
      developer.log('Successfully awarded $amount points to $userId for $type. New balance: $newBalance', name: 'SupabaseService');
    } catch (e, stackTrace) {
      developer.log('Error awarding points: $e\nStack trace: $stackTrace', name: 'SupabaseService', error: e);
      // Rethrow to surface the error during debugging
      rethrow;
    }
  }

  // Get transaction history
  static Future<List<Map<String, dynamic>>> getPointTransactions(String userId) async {
    try {
      final response = await _client
          .from('point_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting transactions: $e', name: 'SupabaseService');
      return [];
    }
  }
  // Submit user feedback
  static Future<void> submitFeedback(String feedbackText) async {
    try {
      final user = getCurrentUser();
      await _client.from('user_feedback').insert({
        'user_id': user?.id,
        'feedback_text': feedbackText,
      });
    } catch (e) {
      developer.log('Error submitting feedback: $e', name: 'SupabaseService');
      throw Exception('Failed to submit feedback');
    }
  }

  // --- Video History Methods ---

  /// Get videos for a specific spot
  static Future<List<Map<String, dynamic>>> getSpotVideos(String spotId, {String sortBy = 'recent'}) async {
    try {
      final user = getCurrentUser();
      
      // Build base query
      var queryBuilder = _client
          .from('spot_videos')
          .select('*, user_vote:video_upvotes!left(vote_type)')
          .eq('spot_id', spotId);
      
      // Only show approved videos OR user's own videos
      if (user != null) {
        queryBuilder = queryBuilder.or('status.eq.approved,submitted_by.eq.${user.id}');
      } else {
        queryBuilder = queryBuilder.eq('status', 'approved');
      }
      
      // Apply sorting and execute query
      final dynamic response;
      switch (sortBy) {
        case 'popular':
          response = await queryBuilder.order('upvotes', ascending: false);
          break;
        case 'oldest':
          response = await queryBuilder.order('created_at', ascending: true);
          break;
        case 'recent':
        default:
          response = await queryBuilder.order('created_at', ascending: false);
      }
      
      // Process user votes
      final videos = (response as List).cast<Map<String, dynamic>>();
      for (var video in videos) {
        final votes = video['user_vote'] as List?;
        if (votes != null && votes.isNotEmpty && user != null) {
          video['user_vote'] = votes.first['vote_type'];
        } else {
          video['user_vote'] = null;
        }
      }
      
      return videos;
    } catch (e) {
      developer.log('Error getting spot videos: $e', name: 'SupabaseService');
      return [];
    }
  }

  /// Submit a new video for a spot
  static Future<String?> submitSpotVideo({
    required String spotId,
    required String url,
    String? skaterName,
    String? description,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');
      
      // Detect platform from URL
      String platform = 'other';
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
        platform = 'youtube';
      } else if (lowerUrl.contains('instagram.com')) {
        platform = 'instagram';
      } else if (lowerUrl.contains('tiktok.com')) {
        platform = 'tiktok';
      } else if (lowerUrl.contains('vimeo.com')) {
        platform = 'vimeo';
      }
      
      final response = await _client.from('spot_videos').insert({
        'spot_id': spotId,
        'url': url,
        'platform': platform,
        'skater_name': skaterName,
        'description': description,
        'submitted_by': user.id,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      return response['id'] as String;
    } catch (e) {
      developer.log('Error submitting video: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  /// Vote on a video (upvote or downvote)
  static Future<void> voteVideo(String videoId, int voteType) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');
      
      // Check if user has already voted
      final existing = await _client
          .from('video_upvotes')
          .select()
          .eq('video_id', videoId)
          .eq('user_id', user.id)
          .maybeSingle();
      
      if (existing != null) {
        // Update existing vote
        if (existing['vote_type'] == voteType) {
          // Remove vote if clicking same button
          await _client
              .from('video_upvotes')
              .delete()
              .eq('video_id', videoId)
              .eq('user_id', user.id);
        } else {
          // Change vote
          await _client
              .from('video_upvotes')
              .update({'vote_type': voteType})
              .eq('video_id', videoId)
              .eq('user_id', user.id);
        }
      } else {
        // Insert new vote
        await _client.from('video_upvotes').insert({
          'video_id': videoId,
          'user_id': user.id,
          'vote_type': voteType,
        });
      }
    } catch (e) {
      developer.log('Error voting on video: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  /// Delete a video (only if user is the submitter)
  static Future<void> deleteSpotVideo(String videoId) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('User not logged in');
      
      await _client
          .from('spot_videos')
          .delete()
          .eq('id', videoId)
          .eq('submitted_by', user.id);
    } catch (e) {
      developer.log('Error deleting video: $e', name: 'SupabaseService');
      rethrow;
    }
  }
  // --- Saved Posts Methods ---

  // Toggle save post status
  static Future<bool> toggleSavePost(String postId) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('User not logged in');

    try {
      // Check if already saved
      final existing = await _client
          .from('saved_posts')
          .select()
          .eq('user_id', user.id)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        // Unsave
        await _client
            .from('saved_posts')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
        return false; // Not saved anymore
      } else {
        // Save
        await _client.from('saved_posts').insert({
          'user_id': user.id,
          'post_id': postId,
        });
        return true; // Saved
      }
    } catch (e) {
      developer.log('Error toggling save post: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // Check if post is saved
  static Future<bool> isPostSaved(String postId) async {
    final user = getCurrentUser();
    if (user == null) return false;

    try {
      final response = await _client
          .from('saved_posts')
          .select()
          .eq('user_id', user.id)
          .eq('post_id', postId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Get user's saved posts
  static Future<List<MapPost>> getSavedPosts() async {
    final user = getCurrentUser();
    if (user == null) return [];

    try {
      // First get saved post IDs
      final savedData = await _client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (savedData.isEmpty) return [];

      final postIds = (savedData as List)
          .map((e) => e['post_id'] as String)
          .toList();

      // Then fetch the posts
      final postsData = await _client
          .from('map_posts')
          .select()
          .filter('id', 'in', postIds);

      // Map to MapPost objects
        final posts = (postsData as List)
          .map((data) => MapPost.fromMap(data))
          .toList();

      // Sort to match saved order (most recent saved first)
      // This is a bit inefficient but necessary since we can't easily join and sort in one go with the current setup
      // A better approach would be a join query, but this works for now
      final postMap = {for (var p in posts) p.id!: p};
      return postIds
          .map((id) => postMap[id])
          .where((p) => p != null)
          .cast<MapPost>()
          .toList();
    } catch (e) {
      developer.log('Error getting saved posts: $e', name: 'SupabaseService');
      return [];
    }
  }

  // --- Notifications Methods ---

  // Get user notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = getCurrentUser();
    if (user == null) return [];

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Mark notification as read
  static Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      // Silently fail
    }
  }

  // Create a notification (system use)
  static Future<void> createNotification({
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
      developer.log('Error creating notification: $e', name: 'SupabaseService');
    }
  }
}
