import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_scores.dart';
import '../services/supabase_service.dart';
import '../services/battle_service.dart';

/// Provider for managing user state across the app
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  String? _username;
  String? _avatarUrl;
  String? _bio;
  int? _age;
  UserScores? _userScores;
  bool _isLoading = false;
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
  bool get isVerified => _isVerified;
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
    if (_currentUser == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load username
      _username = await SupabaseService.getUserUsername(_currentUser!.id);
      
      // Load avatar
      _avatarUrl = await SupabaseService.getUserAvatarUrl(_currentUser!.id);
      
      // Load bio
      _bio = await SupabaseService.getUserBio(_currentUser!.id);
      
      // Load age
      _age = await SupabaseService.getUserAge(_currentUser!.id);
      
      // Load scores
      _userScores = await BattleService.getUserScores(_currentUser!.id);
      
      // Check admin status
      _isAdmin = await SupabaseService.isCurrentUserAdmin();
      
      // Load verification status
      final profile = await SupabaseService.getUserProfile(_currentUser!.id);
      _isVerified = profile?['is_verified'] as bool? ?? false;
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load profile: $e';
    }

    _isLoading = false;
    notifyListeners();
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
