import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:developer' as developer;
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
      developer.log('Error getting display name: $e', name: 'SupabaseService');
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

  // Get user avatar URL
  static Future<String?> getUserAvatarUrl(String userId) async {
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

  /// Checks if the current user has admin privileges.
  /// Returns false if the user is not logged in, the user profile doesn't exist,
  /// or if there's any error during the check.
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        developer.log('User not logged in', name: 'AdminCheck');
        return false;
      }

      // First, check if the user is the hardcoded admin (if needed)
      if (user.email == 'admin@example.com' || user.email == '123@123.com') {
        // Change this to your admin email
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
      developer.log('Error saving display name: $e', name: 'SupabaseService');
      // Silently fail - table may not exist yet
    }
  }

  // Save user username (with uniqueness constraint)
  static Future<void> saveUserUsername(String userId, String username) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': userId,
        'username': username.toLowerCase().trim(),
        'display_name': username.trim(), // Also update display name for consistency
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
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload profile image
  static Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'profiles/avatar_${userId}_$timestamp.jpg';

      final bytes = await imageFile.readAsBytes();
      await _client.storage
          .from('post_images')
          .uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final publicUrl = _client.storage
          .from('post_images')
          .getPublicUrl(filename);

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

      final post = MapPost.fromMap(response);
      
      // Award XP for creating a post (e.g., 15 XP)
    await _updatePosterXP(userId, 15);
    
    // Award Points for creating a post (4.20 Points)
    await awardPoints(userId, 4.20, 'post_reward', referenceId: post.id, description: 'Created a new spot');
    
    return post;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Recalculate user XP based on posts and votes
  static Future<void> recalculateUserXP(String userId) async {
    try {
      // 1. Count user's posts
      final postsResponse = await _client
          .from('map_posts')
          .select('id, likes')
          .eq('user_id', userId);
      
      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      final postCount = posts.length;
      
      // 2. Calculate XP from posts (100 XP per post)
    double xpFromPosts = postCount * 100.0;
      
      // 3. Calculate XP from upvotes received (1 XP per upvote)
      // Note: 'likes' column in map_posts is a simple counter, but for accuracy 
      // we should ideally count positive votes in post_votes table.
      // For now, we'll use the 'likes' counter as it's faster and simpler.
      // If we want to be strict about "upvotes only", we'd query post_votes.
      // Let's stick to the simple 'likes' count for now as it aligns with current logic.
      double xpFromVotes = 0;
      for (var post in posts) {
        xpFromVotes += (post['likes'] as num? ?? 0).toDouble();
      }
      
      // 4. Total Map Score
      final totalMapScore = xpFromPosts + xpFromVotes;
      
      // 5. Update user_scores
      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': totalMapScore,
      });
      
      developer.log('Recalculated XP for $userId: $totalMapScore ($postCount posts, $xpFromVotes votes)', name: 'SupabaseService');
    } catch (e) {
      developer.log('Error recalculating XP: $e', name: 'SupabaseService');
      throw Exception('Failed to recalculate XP: $e');
    }
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

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
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

  // Get user's map posts
  static Future<List<MapPost>> getUserMapPosts(String userId) async {
    try {
      final response = await _client
          .from('map_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((post) => MapPost.fromMap(post)).toList();
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
        
        // Use fetched profile name if available, otherwise fallback to post's stored name
        if (userNames.containsKey(userId)) {
          post['user_name'] = userNames[userId];
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
  static Future<void> checkDailyStreak() async {
    try {
      final user = getCurrentUser();
      if (user == null) return;

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
        await awardPoints(user.id, 10, 'daily_login', description: 'First login bonus');
        return;
      }

      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      
      final difference = today.difference(lastLoginDate).inDays;

      if (difference == 0) {
        // Already logged in today, do nothing
        return;
      } else if (difference == 1) {
        // Logged in yesterday, increment streak
        final newStreak = currentStreak + 1;
        final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
        await _updateStreak(user.id, newStreak, newLongest, today);
        
        // Calculate bonus: Base 3.5 + (Streak * 0.5)
        final bonus = 3.5 + (newStreak * 0.5);
        await awardPoints(user.id, bonus, 'daily_login', description: 'Daily streak: $newStreak days');
      } else {
        // Missed a day (or more), reset streak
        await _updateStreak(user.id, 1, longestStreak, today);
        await awardPoints(user.id, 3.5, 'daily_login', description: 'Daily login (streak reset)');
      }
    } catch (e) {
      developer.log('Error checking daily streak: $e', name: 'SupabaseService');
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

  // Award points (or deduct if negative)
  static Future<void> awardPoints(
    String userId, 
    double amount, 
    String type, 
    {String? referenceId, String? description}
  ) async {
    try {
      // 1. Update wallet balance
      // First ensure wallet exists
      final currentPoints = await getUserPoints(userId);
      final newBalance = currentPoints + amount;
      
      await _client.from('user_wallets').upsert({
        'user_id': userId,
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Log transaction
      await _client.from('point_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_type': type,
        'reference_id': referenceId,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      developer.log('Awarded $amount points to $userId for $type', name: 'SupabaseService');
    } catch (e) {
      developer.log('Error awarding points: $e', name: 'SupabaseService');
      // Don't throw, just log error to prevent blocking user actions
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
