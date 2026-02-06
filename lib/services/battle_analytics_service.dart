import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

import '../models/battle.dart';
import '../models/user_scores.dart';
import 'points_service.dart';

class BattleAnalyticsService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Update player score based on battle outcome
  static Future<void> updatePlayerScoreForBattle(Battle battle) async {
    try {
      final pointsService = PointsService();
      
      // Get current scores for both players
      final winner = await getUserScores(battle.winnerId!);
      final loser = await getUserScores(
        battle.player1Id == battle.winnerId
            ? battle.player2Id
            : battle.player1Id,
      );

      // Winner gains points
      final newWinnerScore = (winner.playerScore + 10).clamp(0.0, 1000.0);
      await pointsService.updatePlayerScore(
        battle.winnerId!, 
        newWinnerScore, 
        reason: 'Won battle ${battle.id}'
      );

      // Loser loses points based on letters collected
      final loserId = battle.player1Id == battle.winnerId
          ? battle.player2Id
          : battle.player1Id;
      final loserLetters = battle.player1Id == battle.winnerId
          ? battle.player2Letters
          : battle.player1Letters;

      // Fewer letters = better performance = less point loss
      final pointsLost = 5 + (loserLetters.length * 2);
      final newLoserScore = (loser.playerScore - pointsLost).clamp(0.0, 1000.0);
      await pointsService.updatePlayerScore(
        loserId, 
        newLoserScore, 
        reason: 'Lost battle ${battle.id}'
      );
    } catch (e) {
      // Silently fail score updates
      AppLogger.log('Failed to update battle scores: $e', name: 'BattleAnalyticsService');
    }
  }

  // Get user scores
  static Future<UserScores> getUserScores(String userId) async {
    try {
      final response = await _client
          .from('user_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // Fetch wallet balance separately
      final walletResponse = await _client
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      final points = (walletResponse?['balance'] as num?)?.toDouble() ?? 0.0;

      if (response != null) {
        final scoresMap = Map<String, dynamic>.from(response);
        scoresMap['points'] = points;
        return UserScores.fromMap(scoresMap);
      } else {
        // Return default scores if not found
        return UserScores(userId: userId, points: points);
      }
    } catch (e) {
      return UserScores(userId: userId);
    }
  }

  // Update player score
  static Future<void> updatePlayerScore(String userId, double newScore) async {
    await PointsService().updatePlayerScore(userId, newScore);
  }

  // Update ranking score
  static Future<void> updateRankingScore(String userId, double adjustment) async {
    final scores = await getUserScores(userId);
    final newScore = (scores.rankingScore + adjustment).clamp(0.0, 1000.0);
    await PointsService().updateRankingScore(userId, newScore);
  }

  // Update map score
  static Future<void> updateMapScore(String userId, double newScore) async {
    await PointsService().updateMapScore(userId, newScore);
  }

  // Get user analytics (W/L ratio, favorite trick)
  static Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    try {
      // 1. Get Win/Loss stats from battles table
      final battlesResponse = await _client
          .from('battles')
          .select('winner_id, player1_id, player2_id')
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .eq('status', 'completed');

      int wins = 0;
      int losses = 0;

      for (final battle in (battlesResponse as List)) {
        if (battle['winner_id'] == userId) {
          wins++;
        } else if (battle['winner_id'] != null) {
          losses++;
        }
      }

      // 2. Get Favorite Trick from battle_tricks table
      // We look for tricks where the user was the setter and the outcome was 'landed'
      final tricksResponse = await _client
          .from('battle_tricks')
          .select('trick_name')
          .eq('setter_id', userId)
          .eq('outcome', 'landed');

      String favoriteTrick = 'None';
      if ((tricksResponse as List).isNotEmpty) {
        final Map<String, int> trickCounts = {};
        for (final trick in tricksResponse) {
          final name = trick['trick_name'] as String;
          trickCounts[name] = (trickCounts[name] ?? 0) + 1;
        }

        favoriteTrick = trickCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      return {
        'wins': wins,
        'losses': losses,
        'favoriteTrick': favoriteTrick,
      };
    } catch (e) {
      AppLogger.log('Error fetching user analytics: $e', name: 'BattleAnalyticsService');
      return {
        'wins': 0,
        'losses': 0,
        'favoriteTrick': 'None',
      };
    }
  }

  /// Get top battle players with their win/loss statistics
  static Future<List<Map<String, dynamic>>> getTopBattlePlayers({int limit = 10}) async {
    try {
      final response = await _client.rpc('get_battle_leaderboard', params: {
        'limit_count': limit,
      });

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.log('Error fetching battle leaderboard: $e', name: 'BattleAnalyticsService');
      return [];
    }
  }
}
