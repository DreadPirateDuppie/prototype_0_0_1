import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

import '../models/battle.dart';
import '../models/user_scores.dart';

class BattleAnalyticsService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Update player scores based on battle outcome
  static Future<void> updatePlayerScoreForBattle(Battle battle) async {
    try {
      // Both players' scores are computed and applied server-side by the
      // SECURITY DEFINER RPC (winner +10, loser -(5 + 2 * letters), read
      // from the battles row) and applied at most once per battle. Direct
      // client writes to user_scores are revoked, so the old read-modify-
      // write upserts would fail anyway.
      await _client.rpc('apply_battle_player_scores', params: {
        'p_battle_id': battle.id,
      });
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

  // NOTE: updatePlayerScore / updateRankingScore / updateMapScore are gone:
  // arbitrary-value score setters cannot be validated server-side and direct
  // client writes to user_scores are revoked. Battle scores go through
  // apply_battle_player_scores (above), voter ranking through
  // apply_verification_ranking_scores (VerificationService).

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
