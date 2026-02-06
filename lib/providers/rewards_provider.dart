import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/rewarded_ad_service.dart';

class RewardsProvider extends ChangeNotifier {
  double _points = 0.0;
  int _streak = 0;
  DateTime? _lastLoginDate;
  DateTime? _lastAdTime;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  String? _error;

  static const Duration adCooldown = Duration(hours: 2);

  // Getters
  double get points => _points;
  int get streak => _streak;
  DateTime? get lastLoginDate => _lastLoginDate;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get canWatchAd {
    if (_lastAdTime == null) return true;
    return DateTime.now().difference(_lastAdTime!) >= adCooldown;
  }

  Duration? get adCooldownRemaining {
    if (canWatchAd) return null;
    final remaining = adCooldown - DateTime.now().difference(_lastAdTime!);
    return remaining.isNegative ? null : remaining;
  }

  bool hasCheckedInToday() {
    if (_lastLoginDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLogin = DateTime(_lastLoginDate!.year, _lastLoginDate!.month, _lastLoginDate!.day);
    
    if (!lastLogin.isAtSameMomentAs(today)) {
      return false;
    }

    final hasTransaction = _transactions.any((tx) {
      final txDate = DateTime.parse(tx['created_at'] as String).toLocal();
      final txDay = DateTime(txDate.year, txDate.month, txDate.day);
      return tx['transaction_type'] == 'daily_login' && txDay.isAtSameMomentAs(today);
    });

    return hasTransaction;
  }

  Future<void> loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final points = await SupabaseService.getUserPoints(user.id);
      final streakData = await SupabaseService.getUserStreak(user.id);
      final transactions = await SupabaseService.getPointTransactions(user.id);

      _points = points.toDouble();
      _transactions = transactions;
      
      // Calculate effective streak
      final dbStreak = streakData['current_streak'] as int;
      final lastLoginStr = streakData['last_login_date'] as String?;
      _lastLoginDate = lastLoginStr != null ? DateTime.parse(lastLoginStr) : null;
      
      if (_lastLoginDate == null) {
        _streak = 0;
      } else {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastLogin = DateTime(_lastLoginDate!.year, _lastLoginDate!.month, _lastLoginDate!.day);
        final difference = today.difference(lastLogin).inDays;
        
        if (difference > 1) {
          _streak = 0;
        } else if (difference == 0) {
          final hasTransaction = transactions.any((tx) {
            final txDate = DateTime.parse(tx['created_at'] as String).toLocal();
            final txDay = DateTime(txDate.year, txDate.month, txDate.day);
            return tx['transaction_type'] == 'daily_login' && txDay.isAtSameMomentAs(today);
          });
          _streak = hasTransaction ? dbStreak : 0;
        } else {
          _streak = dbStreak;
        }
      }

      // Fetch last ad time from PointsService
      _lastAdTime = await SupabaseService.getLastTransactionTime(user.id, 'ad_watch');
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<double> checkDailyLogin() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final earnedPoints = await SupabaseService.checkDailyStreak();
      await loadData();
      return earnedPoints.toDouble();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> showRewardedAd({
    required Function(int) onRewardEarned,
    required Function(String) onError,
  }) async {
    final adService = RewardedAdService.instance;
    
    if (!canWatchAd) {
      onError('Please wait for the cooldown to expire');
      return;
    }

    if (!adService.isAdReady) {
      onError('Ad is not ready yet');
      return;
    }

    await adService.showAd();
    await loadData();
    onRewardEarned(4.2.toInt()); // Standardizing to integer for UI but acknowledging the 4.2 value
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
