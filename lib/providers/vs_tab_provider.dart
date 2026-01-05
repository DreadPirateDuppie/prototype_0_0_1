import 'package:flutter/foundation.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';

class VsTabProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<Battle> _activeBattles = [];
  List<Battle> _completedBattles = [];
  List<Map<String, dynamic>> _leaderboard = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Battle> get activeBattles => _activeBattles;
  List<Battle> get completedBattles => _completedBattles;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;

  Future<void> loadData(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadBattles(userId),
        _loadLeaderboard(),
      ]);
    } catch (e) {
      _error = 'Failed to load data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadBattles(String userId) async {
    try {
      // Check for expired turns first
      await BattleService.checkExpiredTurns(userId);
      
      final battles = await BattleService.getUserBattles(userId);
      
      _activeBattles = battles.where((b) => !b.isComplete()).toList();
      _completedBattles = battles.where((b) => b.isComplete()).toList();
    } catch (e) {
      debugPrint('Error loading battles: $e');
      rethrow;
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      _leaderboard = await BattleService().getTopBattlePlayers(limit: 5);
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      // Don't rethrow, just show empty leaderboard
      _leaderboard = [];
    }
  }

  Future<void> refresh(String userId) async {
    await loadData(userId);
  }
}
