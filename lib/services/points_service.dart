import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
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
      developer.log('Error getting user points: $e', name: 'PointsService');
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
      developer.log('Error getting user streak: $e', name: 'PointsService');
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
      developer.log('Error fetching points config, using defaults: $e', name: 'PointsService');
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
      final streakData = await getUserStreak(userId);
      final currentStreak = streakData['current_streak'] as int;
      final longestStreak = streakData['longest_streak'] as int;
      final lastLoginStr = streakData['last_login_date'] as String?;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Load dynamic config
      final config = await _getPointsConfig();
      final baseDailyPoints = (config['base_daily_points'] ?? 3.5) as num;
      final streakMultiplier = (config['streak_bonus_multiplier'] ?? 0.5) as num;
      final firstLoginBonus = (config['first_login_bonus'] ?? 10.0) as num;

      // If never logged in before
      if (lastLoginStr == null) {
        await _updateStreak(userId, 1, 1, today);
        await awardPoints(userId, firstLoginBonus.toDouble(), 'daily_login',
            description: 'First login bonus');
        return firstLoginBonus.toDouble();
      }

      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDate =
          DateTime(lastLogin.year, lastLogin.month, lastLogin.day);

      final difference = today.difference(lastLoginDate).inDays;

      if (difference == 0) {
        // Already logged in today, do nothing
        return 0.0;
      } else if (difference == 1) {
        // Logged in yesterday, increment streak
        final newStreak = currentStreak + 1;
        final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
        await _updateStreak(userId, newStreak, newLongest, today);

        // Calculate bonus: Base + (Streak * Multiplier)
        final bonus = baseDailyPoints + (newStreak * streakMultiplier);
        await awardPoints(userId, bonus.toDouble(), 'daily_login',
            description: 'Daily streak: $newStreak days');
        return bonus.toDouble();
      } else {
        // Missed a day (or more), reset streak
        await _updateStreak(userId, 1, longestStreak, today);
        await awardPoints(userId, baseDailyPoints.toDouble(), 'daily_login',
            description: 'Daily login (streak reset)');
        return baseDailyPoints.toDouble();
      }
    } catch (e) {
      developer.log('Error checking daily streak: $e', name: 'PointsService');
      return 0.0;
    }
  }

  Future<void> _updateStreak(
      String userId, int streak, int longest, DateTime date) async {
    await _client.from('daily_streaks').upsert({
      'user_id': userId,
      'current_streak': streak,
      'longest_streak': longest,
      'last_login_date': date.toIso8601String().split('T')[0],
      'updated_at': DateTime.now().toIso8601String(),
    });
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
      // Update wallet balance
      final currentPoints = await getUserPoints(userId);
      final newBalance = currentPoints + amount;

      await _client.from('user_wallets').upsert({
        'user_id': userId,
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Log transaction
      await _client.from('point_transactions').insert({
        'user_id': userId,
        'amount': amount,
        'transaction_type': type,
        'reference_id': referenceId,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      developer.log('Awarded $amount points to $userId for $type',
          name: 'PointsService');
    } catch (e) {
      developer.log('Error awarding points: $e', name: 'PointsService');
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
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error getting transactions: $e', name: 'PointsService');
      return [];
    }
  }

  /// Log XP history
  Future<void> logXpHistory(
      String userId, double amount, String type, String reason) async {
    try {
      await _client.from('xp_history').insert({
        'user_id': userId,
        'score_type': type,
        'amount': amount,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log('Error logging XP history: $e', name: 'PointsService');
    }
  }

  /// Update map score (XP)
  Future<void> updateMapScore(String userId, double newScore, {String reason = 'Map score update'}) async {
    try {
      // Get existing scores
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final currentScore = (response?['map_score'] as num?)?.toDouble() ?? 0.0;
      final diff = newScore - currentScore;

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': newScore.clamp(0.0, double.infinity),
        'player_score': response?['player_score'] ?? 0.0,
        'ranking_score': response?['ranking_score'] ?? 500.0,
      });

      if (diff != 0) {
        await logXpHistory(userId, diff, 'map', reason);
      }
    } catch (e) {
      developer.log('Error updating map score: $e', name: 'PointsService');
    }
  }

  /// Update player score (XP)
  Future<void> updatePlayerScore(String userId, double newScore, {String reason = 'Player score update'}) async {
    try {
      // Get existing scores
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final currentScore = (response?['player_score'] as num?)?.toDouble() ?? 0.0;
      final diff = newScore - currentScore;

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': response?['map_score'] ?? 0.0,
        'player_score': newScore.clamp(0.0, double.infinity),
        'ranking_score': response?['ranking_score'] ?? 500.0,
      });

      if (diff != 0) {
        await logXpHistory(userId, diff, 'player', reason);
      }
    } catch (e) {
      developer.log('Error updating player score: $e', name: 'PointsService');
    }
  }

  /// Update ranking score
  Future<void> updateRankingScore(String userId, double newScore, {String reason = 'Ranking score update'}) async {
    try {
      // Get existing scores
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final currentScore = (response?['ranking_score'] as num?)?.toDouble() ?? 500.0;
      final diff = newScore - currentScore;

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': response?['map_score'] ?? 0.0,
        'player_score': response?['player_score'] ?? 0.0,
        'ranking_score': newScore.clamp(0.0, 1000.0),
      });

      if (diff != 0) {
        await logXpHistory(userId, diff, 'ranking', reason);
      }
    } catch (e) {
      developer.log('Error updating ranking score: $e', name: 'PointsService');
    }
  }

  /// Update poster XP based on votes
  Future<void> updatePosterXP(String userId, int xpChange) async {
    try {
      final response = await _client
          .from('user_scores')
          .select('map_score')
          .eq('user_id', userId)
          .maybeSingle();

      final currentScore = (response?['map_score'] as num?)?.toDouble() ?? 0.0;
      final newScore = (currentScore + xpChange).clamp(0.0, double.infinity);

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': newScore,
      });

      await logXpHistory(userId, xpChange.toDouble(), 'map', 'Post upvote/downvote');
    } catch (e) {
      developer.log('Error updating poster XP: $e', name: 'PointsService');
    }
  }

  /// Recalculate user XP based on posts and votes
  Future<void> recalculateUserXP(String userId) async {
    try {
      final postsResponse = await _client
          .from('map_posts')
          .select('id, likes')
          .eq('user_id', userId);

      final posts = (postsResponse as List).cast<Map<String, dynamic>>();
      final postCount = posts.length;

      // Load dynamic config
      final config = await _getPointsConfig();
      final postXp = (config['post_xp'] ?? 100.0) as num;
      final voteXp = (config['vote_xp'] ?? 1.0) as num;

      // XP from posts
      double xpFromPosts = postCount * postXp.toDouble();

      // XP from upvotes
      double xpFromVotes = 0;
      for (var post in posts) {
        xpFromVotes += (post['likes'] as num? ?? 0).toDouble() * voteXp.toDouble();
      }

      final totalMapScore = xpFromPosts + xpFromVotes;

      // Get current score to calculate diff
      final currentScoreResponse = await _client
          .from('user_scores')
          .select('map_score')
          .eq('user_id', userId)
          .maybeSingle();
      final currentScore = (currentScoreResponse?['map_score'] as num?)?.toDouble() ?? 0.0;
      final diff = totalMapScore - currentScore;

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': totalMapScore,
      });

      if (diff != 0) {
        await logXpHistory(userId, diff, 'map', 'XP Recalculation');
      }

      developer.log(
          'Recalculated XP for $userId: $totalMapScore ($postCount posts)',
          name: 'PointsService');
    } catch (e) {
      developer.log('Error recalculating XP: $e', name: 'PointsService');
      throw Exception('Failed to recalculate XP: $e');
    }
  }
}
