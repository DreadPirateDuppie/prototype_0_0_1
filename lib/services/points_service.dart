import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../config/service_locator.dart';

/// Service responsible for points, wallets, and streak operations
class PointsService {
  final SupabaseClient? _injectedClient;

  /// Creates a PointsService with optional dependency injection
  PointsService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt or Supabase.instance
  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) {
      return injected;
    }
    // Try getIt first, but fallback to Supabase.instance if not registered
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Get user wallet balance
  Future<double> getUserPoints(String userId) async {
    try {
      final response = await _client
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      return (response?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      AppLogger.log('Error getting user points: $e', name: 'PointsService');
      return 0.0;
    }
  }

  /// Get user daily streak
  Future<Map<String, dynamic>> getUserStreak(String userId) async {
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
      AppLogger.log('Error getting user streak: $e', name: 'PointsService');
      return {
        'current_streak': 0,
        'longest_streak': 0,
        'last_login_date': null,
      };
    }
  }

  /// Get points configuration from app settings (with hardcoded fallbacks)
  Future<Map<String, dynamic>> _getPointsConfig() async {
    try {
      final response = await _client
          .from('app_settings')
          .select('value')
          .eq('key', 'points_config')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        return response['value'] as Map<String, dynamic>;
      }
    } catch (e) {
      AppLogger.log('Error fetching points config, using defaults: $e', name: 'PointsService');
    }

    // Default fallbacks
    return {
      'base_daily_points': 3.5,
      'streak_bonus_multiplier': 0.5,
      'first_login_bonus': 10.0,
      'post_xp': 100.0,
      'vote_xp': 1.0,
    };
  }

  /// Check and update daily streak
  Future<double> checkDailyStreak(String userId) async {
    try {
      // Streak state is server-authoritative: record_daily_login is a
      // SECURITY DEFINER RPC and the only remaining write path to
      // daily_streaks (direct client writes are revoked). The server decides
      // first-login / increment / reset from its own clock (UTC, matching
      // award_points_atomic's once-per-day check) and returns what happened.
      final result = await _client.rpc('record_daily_login');
      final streakResult = Map<String, dynamic>.from(result as Map);
      final status = streakResult['status'] as String? ?? '';
      final newStreak = (streakResult['current_streak'] as num?)?.toInt() ?? 1;

      if (status == 'already_logged_today') {
        return 0.0;
      }

      // Load dynamic config for the award amount. The amount is re-validated
      // server-side by award_points_atomic against the same config and the
      // (now server-computed) streak, so a tampered client gains nothing.
      final config = await _getPointsConfig();
      final baseDailyPoints = (config['base_daily_points'] ?? 3.5) as num;
      final streakMultiplier = (config['streak_bonus_multiplier'] ?? 0.5) as num;
      final firstLoginBonus = (config['first_login_bonus'] ?? 10.0) as num;

      switch (status) {
        case 'first_login':
          await awardPoints(userId, firstLoginBonus.toDouble(), 'daily_login',
              description: 'First login bonus');
          return firstLoginBonus.toDouble();
        case 'incremented':
          // Bonus: Base + (Streak * Multiplier)
          final bonus = baseDailyPoints + (newStreak * streakMultiplier);
          await awardPoints(userId, bonus.toDouble(), 'daily_login',
              description: 'Daily streak: $newStreak days');
          return bonus.toDouble();
        case 'reset':
          await awardPoints(userId, baseDailyPoints.toDouble(), 'daily_login',
              description: 'Daily login (streak reset)');
          return baseDailyPoints.toDouble();
        default:
          AppLogger.log('Unexpected record_daily_login status: $status',
              name: 'PointsService');
          return 0.0;
      }
    } catch (e) {
      AppLogger.log('Error checking daily streak: $e', name: 'PointsService');
      return 0.0;
    }
  }

  /// Award points (or deduct if negative)
  Future<void> awardPoints(
    String userId,
    double amount,
    String type, {
    String? referenceId,
    String? description,
  }) async {
    try {
      // Use the atomic RPC function to prevent race conditions
      await _client.rpc('award_points_atomic', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_transaction_type': type,
        'p_reference_id': referenceId,
        'p_description': description,
      });

      AppLogger.log('Awarded $amount points to $userId for $type (Atomically)',
          name: 'PointsService');
    } catch (e) {
      // No client-side fallback: computing a balance on the client and
      // writing it back is a race condition and a trust-the-client exploit.
      // Balance changes must only ever happen through the atomic
      // SECURITY DEFINER RPC. Surface the failure to the caller instead.
      AppLogger.log('award_points_atomic RPC failed, points NOT awarded: $e',
          name: 'PointsService');
      rethrow;
    }
  }

  /// Get the time of the last transaction of a specific type
  Future<DateTime?> getLastTransactionTime(String userId, String type) async {
    try {
      final response = await _client
          .from('point_transactions')
          .select('created_at')
          .eq('user_id', userId)
          .eq('transaction_type', type)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['created_at'] != null) {
        return DateTime.parse(response['created_at'] as String).toLocal();
      }
      return null;
    } catch (e) {
      AppLogger.log('Error getting last transaction time: $e', name: 'PointsService');
      return null;
    }
  }

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getPointTransactions(String userId) async {
    try {
      final response = await _client
          .from('point_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.log('Error getting transactions: $e', name: 'PointsService');
      return [];
    }
  }

  // NOTE: the old updateMapScore / updatePlayerScore / updateRankingScore /
  // updatePosterXP / logXpHistory methods are gone on purpose. They were
  // arbitrary-value writes to user_scores / xp_history, which are now
  // revoked server-side (20260705_validate_streaks_and_scores.sql). Score
  // changes only happen through the validated SECURITY DEFINER RPCs:
  // apply_battle_player_scores, apply_verification_ranking_scores and
  // recalculate_map_score below.

  /// Recalculate user XP (map_score) based on posts and votes.
  Future<void> recalculateUserXP(String userId) async {
    try {
      // Computed entirely server-side from map_posts rows (posts * post_xp +
      // vote_score * vote_xp); the client cannot influence the result.
      // Direct client writes to user_scores are revoked.
      final total = await _client.rpc('recalculate_map_score', params: {
        'p_user_id': userId,
      });

      AppLogger.log('Recalculated XP for $userId: $total',
          name: 'PointsService');
    } catch (e) {
      AppLogger.log('Error recalculating XP: $e', name: 'PointsService');
      throw Exception('Failed to recalculate XP: $e');
    }
  }
}
