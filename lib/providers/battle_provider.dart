import 'package:flutter/foundation.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';

/// Provider for managing battle state across the app
class BattleProvider extends ChangeNotifier {
  List<Battle> _activeBattles = [];
  List<Battle> _completedBattles = [];
  List<Battle> _pendingBattles = [];
  Battle? _currentBattle;
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  // Getters
  List<Battle> get activeBattles => _activeBattles;
  List<Battle> get completedBattles => _completedBattles;
  List<Battle> get pendingBattles => _pendingBattles;
  Battle? get currentBattle => _currentBattle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Load all battles for a user
  Future<void> loadBattles(String userId) async {
    if (_isLoading) return;
    
    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check for expired turns first
      await BattleService.checkExpiredTurns(userId);
      
      final battles = await BattleService.getUserBattles(userId);
      
      _activeBattles = battles
          .where((b) => !b.isComplete())
          .toList();
      _completedBattles = battles.where((b) => b.isComplete()).toList();
      _pendingBattles = [];
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load battles: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load a specific battle by ID
  Future<void> loadBattle(String battleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentBattle = await BattleService.getBattle(battleId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load battle: $e';
      _currentBattle = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh battles for current user
  Future<void> refresh() async {
    if (_currentUserId != null) {
      await loadBattles(_currentUserId!);
    }
  }

  /// Clear current battle
  void clearCurrentBattle() {
    _currentBattle = null;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if user is currently in an active battle
  bool get isInActiveBattle => _activeBattles.isNotEmpty;

  /// Get count of battles requiring user action
  int get battlesRequiringAction {
    if (_currentUserId == null) return 0;
    return _activeBattles
        .where((b) => b.currentTurnPlayerId == _currentUserId)
        .length;
  }
}
