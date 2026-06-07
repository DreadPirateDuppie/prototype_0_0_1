import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/battle.dart';
import 'battle_service.dart';
import 'supabase_service.dart';

class BattleMatchmakingService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Join the matchmaking queue for Quick Match
  static Future<void> joinMatchmakingQueue({
    required GameMode gameMode,
    bool isQuickfire = true,
    int wagerAmount = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final userScores = await BattleService.getUserScores(userId);
      
      // Verify user has enough points for wager
      if (wagerAmount > 0) {
        final balance = await SupabaseService.getUserPoints(userId);
        if (balance < wagerAmount) {
          throw Exception('Insufficient points for wager');
        }
      }
      
      // Upsert to queue (replace existing entry if any)
      await _client.from('matchmaking_queue').upsert({
        'user_id': userId,
        'game_mode': gameMode.toString().split('.').last,
        'is_quickfire': isQuickfire,
        'wager_amount': wagerAmount,
        'ranking_score': userScores.rankingScore,
        'status': 'waiting',
        'joined_at': DateTime.now().toIso8601String(),
        'matched_with': null,
        'battle_id': null,
      }, onConflict: 'user_id');
      
      AppLogger.log('Joined matchmaking queue with ranking: ${userScores.rankingScore}', name: 'BattleMatchmakingService');
    } catch (e) {
      AppLogger.log('Error joining matchmaking queue: $e', name: 'BattleMatchmakingService');
      rethrow;
    }
  }

  /// Leave the matchmaking queue
  static Future<void> leaveMatchmakingQueue() async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('matchmaking_queue').delete().eq('user_id', userId);
      AppLogger.log('Left matchmaking queue', name: 'BattleMatchmakingService');
    } catch (e) {
      AppLogger.log('Error leaving matchmaking queue: $e', name: 'BattleMatchmakingService');
    }
  }

  /// Find a match in the queue (skill-based)
  static Future<Map<String, dynamic>?> findMatch({
    required double myRankingScore,
    required String gameMode,
    required bool isQuickfire,
    int wagerAmount = 0,
    int expandedRange = 100,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      
      // Find opponents within ranking range who want similar wager, oldest first
      final results = await _client
          .from('matchmaking_queue')
          .select()
          .neq('user_id', userId)
          .eq('game_mode', gameMode)
          .eq('is_quickfire', isQuickfire)
          .eq('status', 'waiting')
          .gte('ranking_score', myRankingScore - expandedRange)
          .lte('ranking_score', myRankingScore + expandedRange)
          .order('joined_at', ascending: true)
          .limit(1);
      
      if (results.isNotEmpty) {
        final match = results.first;
        // Check wager compatibility - either both 0 or within 20% of each other
        final matchWager = match['wager_amount'] as int;
        final wagerCompatible = (wagerAmount == 0 && matchWager == 0) ||
            (wagerAmount > 0 && matchWager > 0 && 
             (matchWager - wagerAmount).abs() <= (wagerAmount * 0.2).round());
        
        if (wagerCompatible) {
          return match;
        }
      }
      return null;
    } catch (e) {
      AppLogger.log('Error finding match: $e', name: 'BattleMatchmakingService');
      return null;
    }
  }

  /// Get current queue entry for user
  static Future<Map<String, dynamic>?> getQueueEntry() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final result = await _client
          .from('matchmaking_queue')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Subscribe to queue changes for real-time match detection
  static RealtimeChannel subscribeToQueueUpdates(
    String userId,
    Function(Map<String, dynamic>) onMatch,
  ) {
    return _client
        .channel('matchmaking:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matchmaking_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord['status'] == 'matched') {
              onMatch(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  /// Create battle from a matched queue entry
  static Future<Battle?> createBattleFromMatch({
    required String opponentId,
    required GameMode gameMode,
    bool isQuickfire = true,
    int wagerAmount = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      
      // Update both queue entries to 'matched'
      await _client.from('matchmaking_queue').update({
        'status': 'matched',
        'matched_with': opponentId,
      }).eq('user_id', userId);
      
      await _client.from('matchmaking_queue').update({
        'status': 'matched',
        'matched_with': userId,
      }).eq('user_id', opponentId);
      
      // Create the battle
      final battle = await BattleService.createBattle(
        player1Id: userId,
        player2Id: opponentId,
        gameMode: gameMode,
        wagerAmount: wagerAmount,
        isQuickfire: isQuickfire,
      );
      
      // Update queue entries with battle ID
      if (battle != null) {
        await _client.from('matchmaking_queue').update({
          'battle_id': battle.id,
        }).or('user_id.eq.$userId,user_id.eq.$opponentId');
      }
      
      // Clean up queue entries after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _client.from('matchmaking_queue').delete().eq('user_id', userId);
        _client.from('matchmaking_queue').delete().eq('user_id', opponentId);
      });
      
      return battle;
    } catch (e) {
      AppLogger.log('Error creating battle from match: $e', name: 'BattleMatchmakingService');
      rethrow;
    }
  }

  /// Get count of players currently in queue
  static Future<int> getQueueCount() async {
    try {
      final result = await _client
          .from('matchmaking_queue')
          .select('id')
          .eq('status', 'waiting');
      return (result as List).length;
    } catch (e) {
      return 0;
    }
  }
}
