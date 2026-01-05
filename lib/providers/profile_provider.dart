import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';

class ProfileProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _profileData;
  UserScores? _userScores;
  List<MapPost> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get profileData => _profileData;
  UserScores? get userScores => _userScores;
  List<MapPost> get userPosts => _userPosts;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;

  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadProfileData(userId),
        _loadUserScores(userId),
        _loadUserPosts(userId),
        _loadFollowCounts(userId),
      ]);
    } catch (e) {
      _error = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfileData(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      _profileData = data;
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      rethrow;
    }
  }

  Future<void> _loadUserScores(String userId) async {
    try {
      _userScores = await SupabaseService.getUserScores(userId);
    } catch (e) {
      debugPrint('Error loading user scores: $e');
      // Don't fail entire load if scores fail
    }
  }

  Future<void> _loadUserPosts(String userId) async {
    try {
      _userPosts = await SupabaseService.getUserMapPosts(userId);
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      _userPosts = [];
    }
  }

  Future<void> _loadFollowCounts(String userId) async {
    try {
      final followers = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .count();
      
      final following = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .count();

      _followersCount = followers.count;
      _followingCount = following.count;
    } catch (e) {
      debugPrint('Error loading follow counts: $e');
    }
  }

  Future<void> updateProfile({String? username, String? bio}) async {
    final userId = _profileData?['id'];
    if (userId == null) return;

    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      
      if (updates.isEmpty) return;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await Supabase.instance.client
          .from('user_profiles')
          .update(updates)
          .eq('id', userId);

      // Reload profile data to reflect changes
      await _loadProfileData(userId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> refresh(String userId) async {
    await loadProfile(userId);
  }
}
