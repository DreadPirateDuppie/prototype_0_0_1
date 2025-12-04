import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:math';
import '../models/battle.dart';
import '../models/battle_trick.dart';
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

        // Randomly assign setter
      // Create battle record
      // Start with no setter/attempter for RPS
      final battle = Battle(
        player1Id: player1Id,
        player2Id: player2Id,
        gameMode: gameMode,
        customLetters: customLetters ?? '',
        createdAt: DateTime.now(),
        currentTurnPlayerId: '', // Empty string indicates waiting for RPS
        wagerAmount: wagerAmount,
        betAmount: betAmount,
        isQuickfire: isQuickfire,
        turnDeadline: DateTime.now().add(const Duration(hours: 24)), // Initial deadline for RPS
        betAccepted: betAmount == 0, // Auto-accept if no bet
        setterId: null, // No setter initially for RPS
        attempterId: null, // No attempter initially for RPS
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
    String? trickName,
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return null;

      // FIX: Do NOT swap roles here. The setter remains the setter until the trick is attempted.
      // The turn passes to the attempter (opponent) to try the trick.
      final nextTurnPlayerId = battle.attempterId;

      // Calculate new deadline
      final Duration timerDuration = battle.isQuickfire
          ? const Duration(minutes: 4, seconds: 20)
          : const Duration(hours: 24);
      final newDeadline = DateTime.now().add(timerDuration);

      final response = await _client
          .from('battles')
          .update({
            'set_trick_video_url': videoUrl,
            'trick_name': trickName,
            'current_turn_player_id': nextTurnPlayerId, // Pass turn to opponent
            'turn_deadline': newDeadline.toIso8601String(),
          })
          .eq('id', battleId)
          .select()
          .single();

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upload set trick: $e');
    }
  }

  // Upload attempt
  // Upload attempt
  static Future<Battle?> uploadAttempt({
    required String battleId,
    required String videoUrl,
  }) async {
    try {
      final response = await _client
          .from('battles')
          .update({
            'attempt_video_url': videoUrl,
            'verification_status': VerificationStatus.quickFireVoting
                .toString()
                .split('.')
                .last,
            // Reset votes for new round
            'setter_vote': null,
            'attempter_vote': null,
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
      
      // Find active battles where deadline has passed and NOT in voting
      final response = await _client
          .from('battles')
          .select()
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .isFilter('winner_id', null)
          .lt('turn_deadline', now)
          .eq('verification_status', VerificationStatus.pending.toString().split('.').last);

      final expiredBattles = (response as List).map((b) => Battle.fromMap(b)).toList();

      for (final battle in expiredBattles) {
        // Calculate new deadline
        final Duration timerDuration = battle.isQuickfire
            ? const Duration(minutes: 4, seconds: 20)
            : const Duration(hours: 24);
        final newDeadline = DateTime.now().add(timerDuration);

        // Check if timeout is for Setter or Attempter
        final isSetter = battle.currentTurnPlayerId == battle.setterId;
        
        if (isSetter) {
          // SETTER TIMEOUT: Failed to upload trick
          // - No letter assigned (they just lose their turn)
          // - Swap roles: Attempter becomes new Setter
          final newSetterId = battle.attempterId!;
          final newAttempterId = battle.setterId!;
          
          await _client.from('battles').update({
            'setter_id': newSetterId,
            'attempter_id': newAttempterId,
            'current_turn_player_id': newSetterId,
            'turn_deadline': newDeadline.toIso8601String(),
            'set_trick_video_url': null,
            'attempt_video_url': null,
            'trick_name': null,
          }).eq('id', battle.id!);
        } else {
          // ATTEMPTER TIMEOUT: Failed to upload attempt
          // - Assign letter to Attempter
          // - Setter keeps control
          await assignLetter(
            battleId: battle.id!,
            playerId: battle.attempterId!,
          );
          
          // Check if battle ended from letter assignment
          final updatedBattle = await getBattle(battle.id!);
          if (updatedBattle != null && !updatedBattle.isComplete()) {
            await _client.from('battles').update({
              'current_turn_player_id': battle.setterId,
              'turn_deadline': newDeadline.toIso8601String(),
              'set_trick_video_url': null,
              'attempt_video_url': null,
              'trick_name': null,
            }).eq('id', battle.id!);
          }
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

  // Submit vote
  static Future<void> submitVote({
    required String battleId,
    required String userId,
    required String vote, // 'landed' or 'missed'
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return;

      final isSetter = userId == battle.setterId;
      final field = isSetter ? 'setter_vote' : 'attempter_vote';

      await _client.from('battles').update({
        field: vote,
      }).eq('id', battleId);

      await resolveVotes(battleId);
    } catch (e) {
      throw Exception('Failed to submit vote: $e');
    }
  }

  // Get battle tricks history
  static Future<List<BattleTrick>> getBattleTricks(String battleId) async {
    try {
      final response = await _client
          .from('battle_tricks')
          .select()
          .eq('battle_id', battleId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((trick) => BattleTrick.fromMap(trick))
          .toList();
    } catch (e) {
      // If table doesn't exist or error, return empty list
      return [];
    }
  }

  // Resolve votes
  static Future<void> resolveVotes(String battleId) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) return;

      // Check if both voted
      if (battle.setterVote == null || battle.attempterVote == null) return;

      // Check consensus
      if (battle.setterVote == battle.attempterVote) {
        final isLanded = battle.setterVote == 'landed';

        // ARCHIVE TRICK
        if (battle.setTrickVideoUrl != null && battle.attemptVideoUrl != null) {
          try {
            final trick = BattleTrick(
              battleId: battleId,
              setterId: battle.setterId!,
              attempterId: battle.attempterId!,
              trickName: battle.trickName ?? 'Unnamed Trick',
              setTrickVideoUrl: battle.setTrickVideoUrl!,
              attemptVideoUrl: battle.attemptVideoUrl!,
              outcome: isLanded ? 'landed' : 'missed',
              lettersGiven: !isLanded ? (battle.gameMode == GameMode.skate ? 'SKATE' : 'SK8') : '', // Simplified logic, ideally calculate actual letter
              createdAt: DateTime.now(),
            );
            
            await _client.from('battle_tricks').insert(trick.toMap());
          } catch (e) {
            // Silently fail archiving if table doesn't exist
            debugPrint('Failed to archive trick: $e');
          }
        }

        // Calculate new deadline
        final Duration timerDuration = battle.isQuickfire
            ? const Duration(minutes: 4, seconds: 20)
            : const Duration(hours: 24);
        final newDeadline = DateTime.now().add(timerDuration);

        // For SKATE mode: Always switch roles after voting resolution
        if (battle.gameMode == GameMode.skate) {
          // Game of SKATE: Alternating roles
          final newSetterId = battle.attempterId!; // Attempter becomes new setter
          final newAttempterId = battle.setterId!; // Setter becomes new attempter

          if (isLanded) {
            // Attempter landed it - they become the new setter
            await _client.from('battles').update({
              'setter_id': newSetterId,
              'attempter_id': newAttempterId,
              'set_trick_video_url': null,
              'attempt_video_url': null,
              'setter_vote': null,
              'attempter_vote': null,
              'trick_name': null, // Clear trick name
              'verification_status': VerificationStatus.pending.toString().split('.').last,
              'current_turn_player_id': newSetterId, // New setter sets the next trick
              'turn_deadline': newDeadline.toIso8601String(),
            }).eq('id', battleId);
          } else {
            // Attempter missed - they get a letter, and become new setter
            await assignLetter(battleId: battleId, playerId: battle.attempterId!);

            // Check if battle ended from letter assignment
            final updatedBattle = await getBattle(battleId);
            if (updatedBattle != null && !updatedBattle.isComplete()) {
               await _client.from('battles').update({
                'setter_id': newSetterId,
                'attempter_id': newAttempterId,
                'set_trick_video_url': null,
                'attempt_video_url': null,
                'setter_vote': null,
                'attempter_vote': null,
                'trick_name': null, // Clear trick name
                'verification_status': VerificationStatus.pending.toString().split('.').last,
                'current_turn_player_id': newSetterId, // New setter sets the next trick
                'turn_deadline': newDeadline.toIso8601String(),
              }).eq('id', battleId);
            }
          }
        } else {
          // Original logic for SK8 and Custom modes
          if (isLanded) {
            // Attempter landed it -> Setter KEEPS control (Standard: "Make it, Keep it")
            await _client.from('battles').update({
              'set_trick_video_url': null,
              'attempt_video_url': null,
              'setter_vote': null,
              'attempter_vote': null,
              'trick_name': null, // Clear trick name
              'verification_status': VerificationStatus.pending.toString().split('.').last,
              'current_turn_player_id': battle.setterId, // Setter keeps control
              'turn_deadline': newDeadline.toIso8601String(),
            }).eq('id', battleId);
          } else {
            // Attempter missed -> They get a letter, Setter stays Setter
            await assignLetter(battleId: battleId, playerId: battle.attempterId!);

            // Check if battle ended from letter assignment
            final updatedBattle = await getBattle(battleId);
            if (updatedBattle != null && !updatedBattle.isComplete()) {
               await _client.from('battles').update({
                'set_trick_video_url': null,
                'attempt_video_url': null,
                'setter_vote': null,
                'attempter_vote': null,
                'trick_name': null, // Clear trick name
                'verification_status': VerificationStatus.pending.toString().split('.').last,
                'current_turn_player_id': battle.setterId, // Setter goes again
                'turn_deadline': newDeadline.toIso8601String(),
              }).eq('id', battleId);
            }
          }
        }
      } else {
        // Disagreement -> Community Verification
        await _client.from('battles').update({
          'verification_status': VerificationStatus.communityVerification.toString().split('.').last,
        }).eq('id', battleId);
      }
    } catch (e) {
      throw Exception('Failed to resolve votes: $e');
    }
  }
}
