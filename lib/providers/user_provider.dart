import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_scores.dart';
import '../services/supabase_service.dart';
import '../services/battle_service.dart';
import '../utils/logger.dart';

/// Provider for managing user state across the app
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  String? _username;
  String? _avatarUrl;
  String? _bio;
  int? _age;
  UserScores? _userScores;
  bool _isLoading = false;
  bool _isPremium = false;
  bool _isAdmin = false;
  bool _isVerified = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  String? get username => _username;
  String? get avatarUrl => _avatarUrl;
  String? get bio => _bio;
  int? get age => _age;
  UserScores? get userScores => _userScores;
  bool get isLoading => _isLoading;
  bool get isAdmin => _isAdmin;
  bool get isPremium => _isPremium;
  bool get isVerified => _isVerified;
  bool get shouldShowAds => !_isAdmin && !_isPremium;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isLoggedIn => _currentUser != null;
  String get displayName => _username ?? _currentUser?.email?.split('@').first ?? 'User';

  /// Initialize user from current auth state
  Future<void> initialize() async {
    _currentUser = SupabaseService.getCurrentUser();
    if (_currentUser != null) {
      await loadUserProfile();
      await SupabaseService.updateLastActive();
    }
    notifyListeners();
  }

  /// Load user profile data
  Future<void> loadUserProfile() async {
    if (_currentUser == null) {
      AppLogger.log('Cannot load profile: No current user', name: 'UserProvider');
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.log('Loading profile for user: ${_currentUser!.id}', name: 'UserProvider');
      
      // Load essential profile data in parallel for speed
      final results = await Future.wait([
        SupabaseService.getUserUsername(_currentUser!.id),
        SupabaseService.getUserAvatarUrl(_currentUser!.id),
        SupabaseService.getUserBio(_currentUser!.id),
        SupabaseService.getUserAge(_currentUser!.id),
        SupabaseService.isCurrentUserAdmin(),
        SupabaseService.getUserProfile(_currentUser!.id),
        BattleService.getUserScores(_currentUser!.id),
      ]);

      _username = results[0] as String?;
      _avatarUrl = results[1] as String?;
      _bio = results[2] as String?;
      _age = results[3] as int?;
      _isAdmin = results[4] as bool? ?? false;
      
      final profile = results[5] as Map<String, dynamic>?;
      if (profile != null) {
        _isVerified = profile['is_verified'] as bool? ?? false;
        _isPremium = profile['is_premium'] as bool? ?? false;
        AppLogger.log('Profile loaded: premium=$_isPremium, admin=$_isAdmin, verified=$_isVerified', name: 'UserProvider');
      } else {
        AppLogger.log('Profile record not found in database for ${_currentUser!.id}', name: 'UserProvider');
      }
      
      _userScores = results[6] as UserScores?;
      
      _error = null;
    } catch (e) {
      AppLogger.log('Critical error loading user profile', error: e, name: 'UserProvider');
      _error = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refresh all user data
  Future<void> refresh() async {
    await loadUserProfile();
  }

  /// Update username
  Future<bool> updateUsername(String newUsername) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.saveUserUsername(_currentUser!.id, newUsername);
      _username = newUsername;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update username: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update avatar URL after upload
  void updateAvatarUrl(String? url) {
    _avatarUrl = url;
    notifyListeners();
  }

  /// Update bio
  Future<bool> updateBio(String newBio) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.saveUserBio(_currentUser!.id, newBio);
      _bio = newBio;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update bio: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update age
  Future<bool> updateAge(int newAge) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.saveUserAge(_currentUser!.id, newAge);
      _age = newAge;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update age: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh user scores
  Future<void> refreshScores() async {
    if (_currentUser == null) return;
    
    try {
      // Recalculate XP first
      await SupabaseService.recalculateUserXP(_currentUser!.id);
      
      // Then reload scores
      _userScores = await BattleService.getUserScores(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to refresh scores: $e';
      notifyListeners();
    }
  }

  /// Set user after login
  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
    loadUserProfile();
  }

  /// Clear user on logout
  void clearUser() {
    _currentUser = null;
    _username = null;
    _avatarUrl = null;
    _bio = null;
    _userScores = null;
    _isAdmin = false;
    _isPremium = false;
    _isVerified = false;
    _error = null;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if user has completed onboarding
  bool get hasCompletedOnboarding {
    return _username != null && _username!.isNotEmpty;
  }

  /// Get user level from scores
  int get mapLevel => _userScores?.mapLevel ?? 1;
  int get playerLevel => _userScores?.playerLevel ?? 1;
  double get voteWeight => _userScores?.voteWeight ?? 0;
}
