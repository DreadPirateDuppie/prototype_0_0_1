import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/battle.dart';
import '../models/user_scores.dart';
import 'supabase_service.dart';
import 'error_types.dart';

class BattleService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Create a new battle
    static Future<Battle?> createBattle({
    required String player1Id,
    required String player2Id,
    required GameMode gameMode,
    String? customLetters,
    int wagerAmount = 0,
    int betAmount = 0,
    bool isQuickfire = false,
  }) async {
    try {
      // Check if player has enough points for bet
      if (betAmount > 0) {
        final balance = await SupabaseService.getUserPoints(player1Id);
        if (balance < betAmount) {
          throw Exception('Insufficient points for bet');
        }
        
        // Deduct bet from player 1 (player 2 must match to accept)
        await SupabaseService.awardPoints(
          player1Id, 
          -betAmount.toDouble(), 
          'bet_entry', 
          description: 'Bet for battle vs $player2Id'
        );
      }

      // Calculate turn deadline
      final Duration timerDuration = isQuickfire 
          ? const Duration(minutes: 4, seconds: 20)
          : const Duration(hours: 24);
      final turnDeadline = DateTime.now().add(timerDuration);

      final battle = Battle(
        player1Id: player1Id,
        player2Id: player2Id,
        gameMode: gameMode,
        customLetters: customLetters ?? '',
        createdAt: DateTime.now(),
        currentTurnPlayerId: player1Id,
        wagerAmount: wagerAmount,
        betAmount: betAmount,
        isQuickfire: isQuickfire,
        turnDeadline: turnDeadline,
        betAccepted: betAmount == 0, // Auto-accept if no bet
      );

      final response = await _client
          .from('battles')
          .insert(battle.toMap())
          .select()
          .single();

      return Battle.fromMap(response);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error while creating battle',
        originalError: e,
      );
    } on PostgrestException catch (e) {
      throw AppServerException(
        'Database error: ${e.message}',
        userMessage: 'Unable to create battle. Please try again.',
        originalError: e,
      );
    } catch (e) {
      if (e.toString().contains('Insufficient points')) {
        throw AppValidationException(
          'Insufficient points for bet',
          userMessage: 'You don\'t have enough points for this bet.',
          originalError: e,
        );
      }
      throw AppServerException(
        'Failed to create battle: $e',
        userMessage: 'Unable to create battle. Please try again later.',
        originalError: e,
      );
    }
  }
  // Opponent accepts bet
  static Future<void> acceptBet({
    required String battleId,
    required String opponentId,
    required int betAmount,
  }) async {
    try {
      // Verify opponent has enough points
      final balance = await SupabaseService.getUserPoints(opponentId);
      if (balance < betAmount) {
        throw Exception('Opponent has insufficient points for bet');
      }
      // Deduct bet from opponent
      await SupabaseService.awardPoints(
        opponentId,
        -betAmount.toDouble(),
        'bet_entry',
        description: 'Bet match for battle $battleId',
      );
      // Update battle to mark bet accepted
      await _client.from('battles').update({
        'bet_accepted': true,
      }).eq('id', battleId);
    } catch (e) {
      throw Exception('Failed to accept bet: $e');
    }
  }


  // Get all battles for a user
  static Future<List<Battle>> getUserBattles(String userId) async {
    try {
      // Check for expired turns first
      await checkExpiredTurns(userId);

      final response = await _client
          .from('battles')
          .select()
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List)
          .map((battle) => Battle.fromMap(battle))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get active battles for a user (not completed)
  static Future<List<Battle>> getActiveBattles(String userId) async {
    try {
      final response = await _client
          .from('battles')
          .select()
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .filter('winner_id', 'is', 'null')
          .order('created_at', ascending: false);

      return (response as List)
          .map((battle) => Battle.fromMap(battle))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get a specific battle
  static Future<Battle?> getBattle(String battleId) async {
    try {
      final response = await _client
          .from('battles')
          .select()
          .eq('id', battleId)
          .single();

      return Battle.fromMap(response);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error while fetching battle',
        originalError: e,
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw AppNotFoundException(
          'Battle not found',
          userMessage: 'This battle no longer exists.',
          originalError: e,
        );
      }
      throw AppServerException(
        'Database error: ${e.message}',
        userMessage: 'Unable to load battle details.',
        originalError: e,
      );
    } catch (e) {
      throw AppServerException(
        'Failed to fetch battle: $e',
        userMessage: 'Unable to load battle. Please try again.',
        originalError: e,
      );
    }
  }

  // Upload trick video to storage
  static Future<String> uploadTrickVideo(
    File videoFile,
    String battleId,
    String playerId,
    String type, // 'set' or 'attempt'
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${type}_${battleId}_${playerId}_$timestamp.mp4';

      final bytes = await videoFile.readAsBytes();
      await _client.storage
          .from('battle_videos')
          .uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );

      final publicUrl = _client.storage
          .from('battle_videos')
          .getPublicUrl(filename);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  // Upload set trick
  static Future<Battle?> uploadSetTrick({
    required String battleId,
    required String videoUrl,
  }) async {
    try {
      final response = await _client
          .from('battles')
          .update({'set_trick_video_url': videoUrl})
          .eq('id', battleId)
          .select()
          .single();

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upload set trick: $e');
    }
  }

  // Upload attempt
  static Future<Battle?> uploadAttempt({
    required String battleId,
    required String videoUrl,
  }) async {
    try {
      // Get current battle state
      final battle = await getBattle(battleId);
      if (battle == null) return null;

      // Determine who is attempting (the person who is NOT the current turn holder)
      final attempterId = battle.currentTurnPlayerId == battle.player1Id
          ? battle.player2Id
          : battle.player1Id;

      // Switch turn to the attempter (they set the next trick)
      final nextPlayer = attempterId;

      // Calculate new deadline
      final Duration timerDuration = battle.isQuickfire
          ? const Duration(minutes: 4, seconds: 20)
          : const Duration(hours: 24);
      final newDeadline = DateTime.now().add(timerDuration);

      // Clear videos and switch turn (no letter assignment yet - only on timer expiry)
      final response = await _client
          .from('battles')
          .update({
            'set_trick_video_url': null,
            'attempt_video_url': null,
            'current_turn_player_id': nextPlayer,
            'verification_status': VerificationStatus.pending
                .toString()
                .split('.')
                .last,
            'turn_deadline': newDeadline.toIso8601String(),
          })
          .eq('id', battleId)
          .select()
          .single();

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upload attempt: $e');
    }
  }

  // Assign letter to player
  static Future<Battle?> assignLetter({
    required String battleId,
    required String playerId,
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return null;

      final targetLetters = battle.getGameLetters();
      String updatedLetters;

      if (battle.player1Id == playerId) {
        final currentLetters = battle.player1Letters;
        final nextIndex = currentLetters.length;
        if (nextIndex < targetLetters.length) {
          updatedLetters = currentLetters + targetLetters[nextIndex];

          final response = await _client
              .from('battles')
              .update({'player1_letters': updatedLetters})
              .eq('id', battleId)
              .select()
              .single();

          final updatedBattle = Battle.fromMap(response);

          // Check if game is complete
          if (updatedBattle.isComplete()) {
            await completeBattle(
              battleId: battleId,
              winnerId: battle.player2Id, // Other player wins
            );
          }

          return updatedBattle;
        }
      } else if (battle.player2Id == playerId) {
        final currentLetters = battle.player2Letters;
        final nextIndex = currentLetters.length;
        if (nextIndex < targetLetters.length) {
          updatedLetters = currentLetters + targetLetters[nextIndex];

          final response = await _client
              .from('battles')
              .update({'player2_letters': updatedLetters})
              .eq('id', battleId)
              .select()
              .single();

          final updatedBattle = Battle.fromMap(response);

          // Check if game is complete
          if (updatedBattle.isComplete()) {
            await completeBattle(
              battleId: battleId,
              winnerId: battle.player1Id, // Other player wins
            );
          }

          return updatedBattle;
        }
      }

      return battle;
    } catch (e) {
      throw Exception('Failed to assign letter: $e');
    }
  }

  // Complete battle
  static Future<Battle?> completeBattle({
    required String battleId,
    required String winnerId,
  }) async {
    try {
      final response = await _client
          .from('battles')
          .update({
            'winner_id': winnerId,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', battleId)
          .select()
          .single();

      final battle = Battle.fromMap(response);

      // Update player scores
      await updatePlayerScoreForBattle(battle);
      
      // Handle Wager Payout
      if (battle.betAmount > 0) {
        // Winner gets their bet back (no doubling)
        await SupabaseService.awardPoints(
          winnerId,
          battle.betAmount.toDouble(),
          'battle_win', 
          referenceId: battleId, 
          description: 'Won battle wager'
        );
      }

      return battle;
    } catch (e) {
      throw Exception('Failed to complete battle: $e');
    }
  }

  // Update player score based on battle outcome
  static Future<void> updatePlayerScoreForBattle(Battle battle) async {
    try {
      // Get current scores for both players
      final winner = await getUserScores(battle.winnerId!);
      final loser = await getUserScores(
        battle.player1Id == battle.winnerId
            ? battle.player2Id
            : battle.player1Id,
      );

      // Winner gains points
      final newWinnerScore = (winner.playerScore + 10).clamp(0.0, 1000.0);
      await updatePlayerScore(battle.winnerId!, newWinnerScore);

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
      await updatePlayerScore(loserId, newLoserScore);
    } catch (e) {
      // Silently fail score updates
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

      if (response != null) {
        return UserScores.fromMap(response);
      } else {
        // Return default scores if not found
        return UserScores(userId: userId);
      }
    } catch (e) {
      return UserScores(userId: userId);
    }
  }

  // Update player score
  static Future<void> updatePlayerScore(String userId, double newScore) async {
    try {
      final scores = await getUserScores(userId);
      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': scores.mapScore,
        'player_score': newScore.clamp(0.0, 1000.0),
        'ranking_score': scores.rankingScore,
      });
    } catch (e) {
      throw Exception('Failed to update player score: $e');
    }
  }

  // Update ranking score
  static Future<void> updateRankingScore(String userId, int adjustment) async {
    try {
      final scores = await getUserScores(userId);
      final newScore = (scores.rankingScore + adjustment).clamp(0.0, 1000.0);

      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': scores.mapScore,
        'player_score': scores.playerScore,
        'ranking_score': newScore,
      });
    } catch (e) {
      throw Exception('Failed to update ranking score: $e');
    }
  }

  // Update map score
  static Future<void> updateMapScore(String userId, double newScore) async {
    try {
      final scores = await getUserScores(userId);
      await _client.from('user_scores').upsert({
        'user_id': userId,
        'map_score': newScore.clamp(0.0, 1000.0),
        'player_score': scores.playerScore,
        'ranking_score': scores.rankingScore,
      });
    } catch (e) {
      throw Exception('Failed to update map score: $e');
    }
  }

  // Switch turn to next player
  static Future<Battle?> switchTurn(String battleId) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return null;

      final nextPlayer = battle.currentTurnPlayerId == battle.player1Id
          ? battle.player2Id
          : battle.player1Id;

      // Calculate new deadline
      final Duration timerDuration = battle.isQuickfire
          ? const Duration(minutes: 4, seconds: 20)
          : const Duration(hours: 24);
      final newDeadline = DateTime.now().add(timerDuration);

      final response = await _client
          .from('battles')
          .update({
            'current_turn_player_id': nextPlayer,
            'verification_status': VerificationStatus.pending
                .toString()
                .split('.')
                .last,
            'turn_deadline': newDeadline.toIso8601String(),
          })
          .eq('id', battleId)
          .select()
          .single();

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to switch turn: $e');
    }
  }

  // Check for expired turns and auto-assign letters
  static Future<void> checkExpiredTurns(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      // Find active battles where deadline has passed
      final response = await _client
          .from('battles')
          .select()
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .isFilter('winner_id', null)
          .lt('turn_deadline', now);

      final expiredBattles = (response as List).map((b) => Battle.fromMap(b)).toList();

      for (final battle in expiredBattles) {
        // Only process if it's THIS user's turn (or maybe any turn? 
        // If I check for my own expired turns, I assign myself a letter.
        // If I check for opponent's expired turns, I assign THEM a letter.
        // Since we query all battles involving the user, we can handle both.)
        
        // Assign letter to current turn player (who missed the deadline)
        await assignLetter(
          battleId: battle.id!,
          playerId: battle.currentTurnPlayerId,
        );
        
        // Switch turn to keep game moving (and reset timer)
        // Note: assignLetter might have ended the game. Check if it's still active.
        final updatedBattle = await getBattle(battle.id!);
        if (updatedBattle != null && !updatedBattle.isComplete()) {
           await switchTurn(battle.id!);
        }
      }
    } catch (e) {
      // Silently fail to avoid blocking UI
      debugPrint('Error checking expired turns: $e');
    }
  }
  // Forfeit battle
  static Future<Battle?> forfeitBattle({
    required String battleId,
    required String forfeitingUserId,
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return null;

      // Determine winner (the other player)
      final winnerId = battle.player1Id == forfeitingUserId
          ? battle.player2Id
          : battle.player1Id;

      // Complete battle with the other player as winner
      // This handles score updates and wager payouts
      return await completeBattle(
        battleId: battleId,
        winnerId: winnerId,
      );
    } catch (e) {
      throw Exception('Failed to forfeit battle: $e');
    }
  }
}
