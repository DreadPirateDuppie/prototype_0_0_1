import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../config/service_locator.dart';

/// Service responsible for points, wallets, and streak operations
class PointsService {
  final SupabaseClient? _injectedClient;

  /// Creates a PointsService with optional dependency injection
  PointsService({SupabaseClient? client}) : _injectedClient = client;

  /// Gets the Supabase client, using injected client or falling back to getIt
  SupabaseClient get _client =>
      _injectedClient ?? getIt<SupabaseClient>();

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

  /// Check and update daily streak
  Future<void> checkDailyStreak(String userId) async {
    try {
      final streakData = await getUserStreak(userId);
      final currentStreak = streakData['current_streak'] as int;
      final longestStreak = streakData['longest_streak'] as int;
      final lastLoginStr = streakData['last_login_date'] as String?;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // If never logged in before
      if (lastLoginStr == null) {
        await _updateStreak(userId, 1, 1, today);
        await awardPoints(userId, 10, 'daily_login',
            description: 'First login bonus');
        return;
      }

      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDate =
          DateTime(lastLogin.year, lastLogin.month, lastLogin.day);

      final difference = today.difference(lastLoginDate).inDays;

      if (difference == 0) {
        // Already logged in today, do nothing
        return;
      } else if (difference == 1) {
        // Logged in yesterday, increment streak
        final newStreak = currentStreak + 1;
        final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
        await _updateStreak(userId, newStreak, newLongest, today);

        // Calculate bonus: Base 3.5 + (Streak * 0.5)
        final bonus = 3.5 + (newStreak * 0.5);
        await awardPoints(userId, bonus, 'daily_login',
            description: 'Daily streak: $newStreak days');
      } else {
        // Missed a day (or more), reset streak
        await _updateStreak(userId, 1, longestStreak, today);
        await awardPoints(userId, 3.5, 'daily_login',
            description: 'Daily login (streak reset)');
      }
    } catch (e) {
      developer.log('Error checking daily streak: $e', name: 'PointsService');
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

  /// Update user map score (XP)
  Future<void> updateMapScore(String userId, double newScore) async {
    try {
      // Get existing scores
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': newScore.clamp(0.0, double.infinity),
        'player_score': response?['player_score'] ?? 100.0,
        'ranking_score': response?['ranking_score'] ?? 0.0,
      });
    } catch (e) {
      developer.log('Error updating map score: $e', name: 'PointsService');
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

      // XP from posts (100 XP per post)
      double xpFromPosts = postCount * 100.0;

      // XP from upvotes
      double xpFromVotes = 0;
      for (var post in posts) {
        xpFromVotes += (post['likes'] as num? ?? 0).toDouble();
      }

      final totalMapScore = xpFromPosts + xpFromVotes;

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': totalMapScore,
      });

      developer.log(
          'Recalculated XP for $userId: $totalMapScore ($postCount posts)',
          name: 'PointsService');
    } catch (e) {
      developer.log('Error recalculating XP: $e', name: 'PointsService');
      throw Exception('Failed to recalculate XP: $e');
    }
  }
}
