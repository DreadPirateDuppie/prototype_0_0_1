import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../utils/logger.dart';
import '../config/service_locator.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../models/trick_definition.dart';
import '../models/spot_video.dart';
import 'auth_service.dart';
import 'points_service.dart';
import 'social_service.dart';
import 'location_service.dart';
import 'user_service.dart';
import 'admin_service.dart';
import 'post_service.dart';
import 'battle_service.dart';
import 'trick_service.dart';

/// Legacy service that delegates to specialized services.
/// @deprecated Use specific services (AuthService, SocialService, etc.) instead.
class SupabaseService {
  static final AuthService _authService = getIt<AuthService>();
  static final SocialService _socialService = getIt<SocialService>();
  static final LocationService _locationService = getIt<LocationService>();
  static final UserService _userService = getIt<UserService>();
  static final AdminService _adminService = getIt<AdminService>();
  static final PostService _postService = getIt<PostService>();
  static final BattleService _battleService = getIt<BattleService>();
  static final PointsService _pointsService = getIt<PointsService>();
  static final TrickService _trickService = getIt<TrickService>();

  // ========== AUTH DELEGATION ==========
  static User? getCurrentUser() => _authService.getCurrentUser();
  static Session? getCurrentSession() => _authService.getCurrentSession();
  static Future<AuthResponse> signUp(String email, String password, {String? displayName, String? username, int? age}) => 
      _authService.signUp(email, password, displayName: displayName, username: username, age: age);
  static Future<AuthResponse> signIn(String email, String password) => _authService.signIn(email, password);
  static Future<void> signOut() => _authService.signOut();
  static Future<void> updateLastActive() => _authService.updateLastActive();

  // ========== USER DELEGATION ==========
  static Future<Map<String, dynamic>?> getCurrentUserProfile() => _userService.getUserProfile(getCurrentUser()?.id ?? '');
  static Future<String?> getUserDisplayName(String userId) => _userService.getUserDisplayName(userId);
  static Future<String?> getCurrentUserDisplayName() => _userService.getCurrentUserDisplayName();
  static Future<String?> getUserUsername(String userId) => _userService.getUserUsername(userId);
  static Future<String?> getUserAvatarUrl(String userId) => _userService.getUserAvatarUrl(userId);
  static Future<bool> isUsernameAvailable(String username) => _userService.isUsernameAvailable(username);
  static Future<void> saveUserDisplayName(String userId, String displayName) => _userService.saveUserDisplayName(userId, displayName);
  static Future<void> saveUserUsername(String userId, String username) => _userService.saveUserUsername(userId, username);
  static Future<String?> getUserBio(String userId) => _userService.getUserBio(userId);
  static Future<void> saveUserBio(String userId, String bio) => _userService.saveUserBio(userId, bio);
  static Future<int?> getUserAge(String userId) => _userService.getUserAge(userId);
  static Future<void> saveUserAge(String userId, int age) => _userService.saveUserAge(userId, age);
  static Future<Map<String, dynamic>?> getUserProfile(String userId) => _userService.getUserProfile(userId);
  static Future<void> setPrivacy(bool isPrivate) async => _userService.setPrivacy(getCurrentUser()?.id ?? '', isPrivate);
  static Future<bool> isUserPrivate(String userId) => _userService.isUserPrivate(userId);
  static Future<String> uploadProfileImage(String userId, File imageFile) => _userService.uploadProfileImage(imageFile, userId);

  // ========== SOCIAL DELEGATION ==========
  static Future<void> followUser(String userIdToFollow) => _socialService.followUser(userIdToFollow);
  static Future<void> unfollowUser(String userIdToUnfollow) => _socialService.unfollowUser(userIdToUnfollow);
  static Future<bool> isFollowing(String userId) => _socialService.isFollowing(userId);
  static Future<List<Map<String, dynamic>>> getFollowers(String userId) => _socialService.getFollowers(userId);
  static Future<List<Map<String, dynamic>>> getFollowing(String userId) => _socialService.getFollowing(userId);
  static Future<List<Map<String, dynamic>>> getMutualFollowers() => _socialService.getMutualFollowers();
  static Future<Map<String, int>> getFollowCounts(String userId) => _socialService.getFollowCounts(userId);
  static Future<List<Map<String, dynamic>>> searchUsers(String query) => _socialService.searchUsers(query);
  static Future<String?> getRandomOpponent({bool mutualOnly = false}) => _socialService.getRandomOpponent(mutualOnly: mutualOnly);

  // ========== LOCATION DELEGATION ==========
  static Future<void> updateUserLocation(double latitude, double longitude) => _locationService.updateUserLocation(latitude, longitude);
  static Future<void> updateLocationSharingMode(String mode) => _locationService.updateLocationSharingMode(mode);
  static Future<void> updateLocationBlacklist(List<String> blacklist) => _locationService.updateLocationBlacklist(blacklist);
  static Future<Map<String, dynamic>> getLocationPrivacySettings() => _locationService.getLocationPrivacySettings();
  static Future<List<Map<String, dynamic>>> getVisibleUserLocations() => _locationService.getVisibleUserLocations();
  static Future<List<Map<String, dynamic>>> getNearbyOnlineUsers(double latitude, double longitude, {double radiusInMeters = 100.0}) => 
      _locationService.getNearbyOnlineUsers(latitude, longitude, radiusInMeters: radiusInMeters);

  // ========== ADMIN DELEGATION ==========
  static Future<bool> isCurrentUserAdmin() => _adminService.isCurrentUserAdmin();

  // ========== POST DELEGATION ==========
  static Future<MapPost?> createMapPost({
    required String userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    List<String> photoUrls = const [],
    String? userName,
    String? userEmail,
    String? videoUrl,
    String category = 'Other',
    List<String> tags = const [],
    double? qualityRating,
    double? securityRating,
    double? popularityRating,
  }) {
    return _postService.createMapPost(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        title: title,
        description: description,
        photoUrls: photoUrls,
        userName: userName,
        userEmail: userEmail,
        videoUrl: videoUrl,
        category: category,
        tags: tags,
        qualityRating: qualityRating,
        securityRating: securityRating,
        popularityRating: popularityRating,
      );
  }

  static Future<MapPost?> updateMapPost({
    required String postId,
    required String title,
    required String description,
    List<String>? photoUrls,
    String? videoUrl,
    double? popularityRating,
    double? securityRating,
    double? qualityRating,
    String? category,
    List<String>? tags,
  }) => _postService.updateMapPost(
        postId: postId,
        title: title,
        description: description,
        photoUrls: photoUrls,
        videoUrl: videoUrl,
        popularityRating: popularityRating,
        securityRating: securityRating,
        qualityRating: qualityRating,
        category: category,
        tags: tags,
      );

  static Future<void> deletePost(String postId) => _postService.deleteMapPost(postId, getCurrentUser()?.id ?? '');
  static Future<void> votePost({required String postId, required String voterId, required int voteType}) => 
      _postService.votePost(postId: postId, voterId: voterId, voteType: voteType);
  
  static Future<bool> toggleSavePost(String postId, String userId) => _postService.toggleSavePost(postId, userId);
  static Future<bool> isPostSaved(String postId, [String? userId]) => _postService.isPostSaved(postId, userId ?? getCurrentUser()?.id ?? '');
  
  static Future<void> savePost(String postId) async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return;
    final isSaved = await _postService.isPostSaved(postId, userId);
    if (!isSaved) {
      await _postService.toggleSavePost(postId, userId);
    }
  }

  static Future<void> unsavePost(String postId) async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return;
    final isSaved = await _postService.isPostSaved(postId, userId);
    if (isSaved) {
      await _postService.toggleSavePost(postId, userId);
    }
  }

  static Future<String> uploadPostImage(File imageFile, String userId) => _postService.uploadPostImage(imageFile, userId);
  static Future<String> uploadPostVideo(File videoFile, String userId) => _postService.uploadPostVideo(videoFile, userId);

  // ========== BATTLE DELEGATION ==========
  static Future<List<Map<String, dynamic>>> getTopBattlePlayers({int limit = 10}) => _battleService.getTopBattlePlayers(limit: limit);
  static Future<String> createLobby() => BattleService.createLobby();
  static Future<String> joinLobby(String code) => BattleService.joinLobby(code);
  static Stream<Map<String, dynamic>> streamLobby(String lobbyId) => BattleService.streamLobby(lobbyId);
  static Stream<List<Map<String, dynamic>>> streamLobbyPlayers(String lobbyId) => BattleService.streamLobbyPlayers(lobbyId);
  static Stream<Map<String, dynamic>> streamLobbyEvents(String lobbyId) => BattleService.streamLobbyEvents(lobbyId);
  static Future<void> leaveLobby(String lobbyId) => BattleService.leaveLobby(lobbyId);
  static Future<void> updatePlayerLetters(String lobbyId, List<String> letters) => BattleService.updatePlayerLetters(lobbyId, letters);
  static Future<void> sendLobbyEvent(String lobbyId, String type, Map<String, dynamic> data) => BattleService.sendLobbyEvent(lobbyId, type, data);

  // ========== POST EXTRA DELEGATION ==========
  static Future<List<MapPost>> getAllMapPosts({
    String? category,
    String? tag,
    String? searchQuery,
    String sortBy = 'newest',
    int page = 1,
    int pageSize = 20,
  }) => _postService.getAllMapPosts(
        category: category,
        tag: tag,
        searchQuery: searchQuery,
        sortBy: sortBy,
        page: page,
        pageSize: pageSize,
      );
  
  static Future<List<MapPost>> getUserMapPosts(String userId) => _postService.getUserMapPosts(userId);
  
  static Future<List<MapPost>> getSavedPosts() async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    return _postService.getSavedPosts(userId);
  }

  static Future<void> reportPost({required String postId, required String reporterUserId, required String reason, String? details}) =>
      _postService.reportPost(postId: postId, reporterUserId: reporterUserId, reason: reason, details: details);

  static Future<void> rateMapPost({
    required String postId,
    required double popularityRating,
    required double securityRating,
    required double qualityRating,
  }) => 
      _postService.updateMapPost(
        postId: postId, 
        title: '', 
        description: '', 
        popularityRating: popularityRating,
        securityRating: securityRating,
        qualityRating: qualityRating,
      );

  // ========== USER EXTRA DELEGATION ==========
  static Future<void> recalculateUserXP(String userId) => _pointsService.recalculateUserXP(userId);
  static Future<double> getUserPoints(String userId) => _pointsService.getUserPoints(userId);
  static Future<Map<String, dynamic>> getUserStreak(String userId) => _pointsService.getUserStreak(userId);
  static Future<DateTime?> getLastTransactionTime(String userId, String type) => _pointsService.getLastTransactionTime(userId, type);
  static Future<List<Map<String, dynamic>>> getPointTransactions(String userId) => _pointsService.getPointTransactions(userId);
  static Future<double> checkDailyStreak() async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return 0.0;
    return _pointsService.checkDailyStreak(userId);
  }
  static Future<void> awardPoints(String userId, double points, String reason, {String? referenceId, String? description}) =>
      _pointsService.awardPoints(userId, points, reason, referenceId: referenceId, description: description);
  
  static Future<bool> isUsernameAvailableForUser(String username, String userId) => _userService.isUsernameAvailableForUser(username, userId);
  static Future<List<Map<String, dynamic>>> getProfileMedia(String userId) => _userService.getProfileMedia(userId);
  static Future<UserScores?> getUserScores(String userId) => _userService.getUserScores(userId);
  static Future<String> uploadProfileMedia(File file, String userId, String mediaType) => _userService.uploadProfileMedia(file, userId, mediaType);
  static Future<void> createProfileMedia({
    required String userId, 
    required String mediaUrl, 
    required String mediaType,
    String? caption,
  }) => _userService.createProfileMedia(
    userId: userId,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    caption: caption,
  );
  
  static Future<List<TrickDefinition>> getTrickSuggestions(String query) => _trickService.getTrickSuggestions(query);
  
  static Future<void> submitTrick({
    required String spotId,
    required String userId,
    required String url,
    required String trickName,
    String? skaterName,
    String? description,
    required bool isOwnClip,
    required String stance,
    double difficultyMultiplier = 1.0,
    List<String> tags = const [],
  }) => _trickService.submitTrick(
    spotId: spotId,
    userId: userId,
    url: url,
    trickName: trickName,
    skaterName: skaterName,
    description: description,
    isOwnClip: isOwnClip,
    stance: stance,
    difficultyMultiplier: difficultyMultiplier,
    tags: tags,
  );

  static Future<List<SpotVideo>> getSpotArchive(String spotId, {String? searchQuery, String? category}) => 
      _trickService.getSpotArchive(spotId, searchQuery: searchQuery, category: category);

  static Future<List<SpotVideo>> getSpotHighlights(String spotId, {int limit = 3}) => 
      _trickService.getSpotHighlights(spotId, limit: limit);

  // ========== AUTH EXTRA DELEGATION ==========
  static Future<bool> signInWithGoogle() => _authService.signInWithGoogle();
  static Future<void> deleteAccount() => _authService.deleteAccount();

  // ========== UTILS ==========
  static void logError(String message, {Object? error, StackTrace? stackTrace}) {
    AppLogger.log(message, error: error, stackTrace: stackTrace, name: 'SupabaseService');
  }

  static Future<List<Map<String, dynamic>>> getErrorLogs({int? limit}) => _adminService.getErrorLogs(limit: limit);

  static Future<void> submitFeedback(String feedback) => _userService.submitFeedback(feedback, userId: getCurrentUser()?.id);

  // ========== NOTIFICATIONS (Placeholder) ==========
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    return _userService.getNotifications(userId);
  }
  static Future<void> markNotificationRead(String notificationId) => _userService.markNotificationRead(notificationId);
  
  // ========== FEED (Placeholder) ==========
  static Future<List<MapPost>> getAllMapPostsWithVotes({
    String? category,
    String? tag,
    String? searchQuery,
    String sortBy = 'newest',
    int page = 1,
    int pageSize = 20,
  }) async {
    return getAllMapPosts(
      category: category,
      tag: tag,
      searchQuery: searchQuery,
      sortBy: sortBy,
      page: page,
      pageSize: pageSize,
    );
  }
  
  static Future<List<MapPost>> getFollowingMapPostsWithVotes({
    String? category,
    String? tag,
    String? searchQuery,
    String sortBy = 'newest',
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    
    return _postService.getFollowingMapPosts(
      userId: userId,
      category: category,
      tag: tag,
      searchQuery: searchQuery,
      sortBy: sortBy,
      page: page,
      pageSize: pageSize,
    );
  }
}
