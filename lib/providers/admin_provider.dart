import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/admin_service.dart';
import '../config/service_locator.dart';

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = getIt<AdminService>();

  // State
  bool _isLoading = false;
  bool _isAdmin = false;
  String? _error;
  
  // Basic Stats
  Map<String, dynamic> _stats = {
    'total_posts': 0,
    'total_users': 0,
    'pending_reports': 0,
  };

  // Time-Series Analytics Data
  List<Map<String, dynamic>> _dailyPostStats = [];
  List<Map<String, dynamic>> _userGrowthStats = [];
  
  // Battle & Spot Specific Metrics
  int _maxWager = 0;
  List<Map<String, dynamic>> _competitiveSpots = [];

  // User Management State
  List<Map<String, dynamic>> _users = [];
  int _currentPage = 0;
  int _totalUsers = 0;
  bool _hasNextPage = false;
  static const int _pageSize = 20;
  
  // Reports & Other Data
  List<Map<String, dynamic>> _reports = [];
  List<MapPost> _unverifiedPosts = [];
  List<Map<String, dynamic>> _pendingVideos = [];
  List<Map<String, dynamic>> _errorLogs = [];
  Map<String, dynamic> _appSettings = {};
  
  // Realtime subscription
  StreamSubscription? _errorsSubscription;

  // Getters
  bool get isLoading => _isLoading;
  bool get isAdmin => _isAdmin;
  String? get error => _error;
  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get reports => _reports;
  List<MapPost> get unverifiedPosts => _unverifiedPosts;
  List<Map<String, dynamic>> get pendingVideos => _pendingVideos;
  List<Map<String, dynamic>> get errorLogs => _errorLogs;
  Map<String, dynamic> get appSettings => _appSettings;
  
  List<Map<String, dynamic>> get dailyPostStats => _dailyPostStats;
  List<Map<String, dynamic>> get userGrowthStats => _userGrowthStats;
  
  bool get hasNextPage => _hasNextPage;
  int get totalUsers => _totalUsers;
  int get maxWager => _maxWager;
  List<Map<String, dynamic>> get competitiveSpots => _competitiveSpots;

  // Initialization
  Future<void> init() async {
    await checkAdminStatus();
    if (_isAdmin) {
      await loadAllData();
    }
  }

  Future<void> checkAdminStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _isAdmin = await _adminService.isCurrentUserAdmin();
    } catch (e) {
      _error = 'Failed to check admin status: $e';
      _isAdmin = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadStats(),
        loadAnalytics(),
        loadUsersPaginated(reset: true),
        loadReports(),
        loadUnverifiedPosts(),
        loadPendingVideos(),
        loadAppSettings(),
        loadErrorLogs(),
        loadDetailedBattleStats(),
      ]);
      _subscribeToErrors();
    } catch (e) {
      _error = 'Failed to load dashboard data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Analytics Actions
  Future<void> loadStats() async {
    try {
      _stats = await _adminService.getAppStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> loadDetailedBattleStats() async {
    try {
      final results = await _adminService.getDetailedBattleStats();
      _maxWager = results['max_wager'] as int;
      _competitiveSpots = results['competitive_spots'] as List<Map<String, dynamic>>;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading detailed battle stats: $e');
    }
  }

  // Advanced Analytics Data
  List<Map<String, dynamic>> _cohortRetention = [];
  Map<String, dynamic> _stickinessRatio = {'ratio': 0.0, 'dau': 0, 'mau': 0};
  List<Map<String, dynamic>> _healthScores = [];
  double _timeToValue = 0.0;
  List<Map<String, dynamic>> _atRiskUsers = [];

  // Getters
  List<Map<String, dynamic>> get cohortRetention => _cohortRetention;
  Map<String, dynamic> get stickinessRatio => _stickinessRatio;
  List<Map<String, dynamic>> get healthScores => _healthScores;
  double get timeToValue => _timeToValue;
  List<Map<String, dynamic>> get atRiskUsers => _atRiskUsers;

  Future<void> loadAnalytics() async {
    try {
      final results = await Future.wait([
        _adminService.getDailyPostStats(),
        _adminService.getUserGrowthStats(),
        // Advanced Analytics
        _adminService.getCohortRetention(),
        _adminService.getStickinessRatio(),
        _adminService.getCustomerHealthScores(),
        _adminService.getTimeToValue(),
        _adminService.getAtRiskUsers(),
      ]);
      
      _dailyPostStats = results[0] as List<Map<String, dynamic>>;
      _userGrowthStats = results[1] as List<Map<String, dynamic>>;
      
      _cohortRetention = results[2] as List<Map<String, dynamic>>;
      _stickinessRatio = results[3] as Map<String, dynamic>;
      _healthScores = results[4] as List<Map<String, dynamic>>;
      _timeToValue = results[5] as double;
      _atRiskUsers = results[6] as List<Map<String, dynamic>>;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading detailed analytics: $e');
    }
  }

  // User Management Actions
  Future<void> loadUsersPaginated({
    bool reset = false, 
    String? searchQuery,
    String? sortBy
  }) async {
    if (reset) {
      _currentPage = 0;
      _users = [];
    }

    try {
      final result = await _adminService.getUsersPaginated(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: searchQuery,
        sortBy: sortBy,
      );
      
      final newUsers = result['users'] as List<Map<String, dynamic>>;
      final count = result['count'] as int;

      if (reset) {
        _users = newUsers;
      } else {
        _users.addAll(newUsers);
      }

      _totalUsers = count;
      _hasNextPage = _users.length < _totalUsers;
      
      if (newUsers.isNotEmpty) {
        _currentPage++;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading users: $e');
      _error = 'Failed to load users: $e';
      notifyListeners();
    }
  }
  
  // Legacy alias
  Future<void> loadUsers() async {
    await loadUsersPaginated(reset: true);
  }

  Future<void> toggleAdminStatus(String userId, bool makeAdmin) async {
    try {
      await _adminService.setUserAdminStatus(userId, makeAdmin);
      await loadUsersPaginated(reset: true); // Refresh list
    } catch (e) {
      _error = 'Failed to update admin status: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleVerificationStatus(String userId, bool makeVerified) async {
    try {
      if (makeVerified) {
        await _adminService.verifyUser(userId);
      } else {
        await _adminService.unverifyUser(userId);
      }
      await loadUsers();
    } catch (e) {
      _error = 'Failed to update verification status: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> banUser(String userId, String reason) async {
    try {
      await _adminService.banUser(userId, reason);
      await loadUsers();
    } catch (e) {
      _error = 'Failed to ban user: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unbanUser(String userId) async {
    try {
      await _adminService.unbanUser(userId);
      await loadUsers();
    } catch (e) {
      _error = 'Failed to unban user: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> togglePostingRestriction(String userId, bool canPost) async {
    try {
      await _adminService.togglePostingRestriction(userId, canPost);
      await loadUsers();
    } catch (e) {
      _error = 'Failed to update posting restriction: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addPoints(String userId, double amount, String description) async {
    try {
      await _adminService.addPointTransaction(
        userId: userId,
        amount: amount,
        type: 'admin_adjustment',
        description: description,
      );
      await loadUsers();
    } catch (e) {
      _error = 'Failed to add points: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removePoints(String userId, double amount, String description) async {
    try {
      await _adminService.addPointTransaction(
        userId: userId,
        amount: -amount, // Negative amount for removal
        type: 'admin_adjustment',
        description: description,
      );
      await loadUsers();
    } catch (e) {
      _error = 'Failed to remove points: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Reports & Moderation Actions
  Future<void> loadReports() async {
    try {
      _reports = await _adminService.getReportedPosts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
  }

  Future<void> loadUnverifiedPosts() async {
    try {
      _unverifiedPosts = await _adminService.getUnverifiedPosts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unverified posts: $e');
    }
  }

  Future<void> loadPendingVideos() async {
    try {
      _pendingVideos = await _adminService.getPendingVideos();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending videos: $e');
    }
  }

  Future<void> dismissReport(String reportId) async {
    try {
      await _adminService.updateReportStatus(reportId, 'dismissed');
      await loadReports();
      await loadStats(); // Update pending count
    } catch (e) {
      _error = 'Failed to dismiss report: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyPost(String postId) async {
    try {
      await _adminService.verifyMapPost(postId);
      await loadUnverifiedPosts();
      await loadStats();
    } catch (e) {
      _error = 'Failed to verify post: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> moderateVideo(String videoId, String status) async {
    try {
      await _adminService.moderateVideo(videoId, status);
      await loadPendingVideos();
    } catch (e) {
      _error = 'Failed to moderate video: $e';
      notifyListeners();
      rethrow;
    }
  }

  // App Settings Actions
  Future<void> loadAppSettings() async {
    try {
      final config = await _adminService.getAppSettings('points_config');
      if (config != null) {
        _appSettings = config;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  Future<void> updatePointsConfig(Map<String, dynamic> newConfig) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _adminService.updateAppSettings('points_config', newConfig);
      _appSettings = newConfig;
    } catch (e) {
      _error = 'Failed to update settings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Error Log Actions
  Future<void> loadErrorLogs() async {
    try {
      _errorLogs = await _adminService.getErrorLogs(limit: 50);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading error logs: $e');
    }
  }

  void _subscribeToErrors() {
    _errorsSubscription?.cancel();
    _errorsSubscription = _adminService.subscribeToErrorLogs().listen(
      (logs) {
        _errorLogs = logs;
        notifyListeners();
      },
      onError: (e) => debugPrint('Error subscription failed: $e'),
    );
  }

  // Helper to load transaction history for a specific user
  Future<List<Map<String, dynamic>>> getUserTransactionHistory(String userId) async {
    return await _adminService.getPointTransactions(userId);
  }

  @override
  void dispose() {
    _errorsSubscription?.cancel();
    super.dispose();
  }
}
