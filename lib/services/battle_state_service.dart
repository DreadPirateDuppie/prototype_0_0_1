import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

import '../models/battle.dart';
import '../models/battle_trick.dart';
import 'battle_service.dart';
import 'supabase_service.dart';
import 'messaging_service.dart';
import 'notification_service.dart';
import 'error_types.dart';

class BattleStateService {
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
      // final turnDeadline = DateTime.now().add(timerDuration); // Unused

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
        turnDeadline: DateTime.now().add(timerDuration), // Initial deadline for RPS
        betAccepted: betAmount == 0, // Auto-accept if no bet
        setterId: null, // No setter initially for RPS
        attempterId: null, // No attempter initially for RPS
      );

      final response = await _client
          .from('battles')
          .insert(battle.toMap())
          .select()
          .single();

      final createdBattle = Battle.fromMap(response);

      // Send notification message
      try {
        final p1Name = await SupabaseService.getUserUsername(player1Id) ?? 'Someone';
        final conversationId = await MessagingService.getOrCreateDirectConversation(player2Id);
        if (conversationId != null) {
          await MessagingService.sendMessage(
            conversationId: conversationId,
            content: '$p1Name has challenged you to a battle! Tap to engage.',
          );
        }
      } catch (e) {
        // Ignore message failure
        AppLogger.log('Failed to send battle start notification: $e', name: 'BattleStateService');
      }

      return createdBattle;
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

  static Future<Battle?> forfeitTurn({
    required String battleId,
    required String playerId,
  }) async {
    try {
      // 1. Assign letter to the forfeiting player
      final battle = await assignLetter(battleId: battleId, playerId: playerId);
      if (battle == null || battle.isComplete()) return battle;

      // 2. Reset turn to Setter (since Attempter missed/skipped)
      // Calculate new deadline
      final Duration timerDuration = battle.isQuickfire
          ? const Duration(minutes: 4, seconds: 20)
          : const Duration(hours: 24);
      final newDeadline = DateTime.now().add(timerDuration);

      final response = await _client
          .from('battles')
          .update({
            'current_turn_player_id': battle.setterId,
            'turn_deadline': newDeadline.toIso8601String(),
            'set_trick_video_url': null,
            'attempt_video_url': null,
            'trick_name': null,
            'setter_vote': null,
            'attempter_vote': null,
            'verification_status': 'none',
          })
          .eq('id', battleId)
          .select()
          .single();

      // Cancel existing notification
      await NotificationService.cancelBattleNotification(battleId);
      
      // Schedule new notification for deadline
      await NotificationService.scheduleBattleTurnExpiryNotification(
        battleId, 
        newDeadline
      );

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to forfeit turn: $e');
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

      // Cancel existing notification
      await NotificationService.cancelBattleNotification(battleId);

      final battle = Battle.fromMap(response);

      // Update player scores
      await BattleService.updatePlayerScoreForBattle(battle);
      
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
      AppLogger.log('Checking expired turns for user: $userId', name: 'BattleStateService');
      final now = DateTime.now().toIso8601String();
      
      // Find active battles where deadline has passed and NOT in voting
      final response = await _client
          .from('battles')
          .select()
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .filter('winner_id', 'is', 'null')
          .lt('turn_deadline', now);
          // Removed verification_status filter to handle voting timeouts too

      final expiredBattles = (response as List).map((b) => Battle.fromMap(b)).toList();

      AppLogger.log('Found ${expiredBattles.length} expired battles', name: 'BattleStateService');

      for (final battle in expiredBattles) {
        AppLogger.log('Processing expired battle: ${battle.id}', name: 'BattleStateService');
        
        // Calculate new deadline
        final Duration timerDuration = battle.isQuickfire
            ? const Duration(minutes: 4, seconds: 20)
            : const Duration(hours: 24);
        final newDeadline = DateTime.now().add(timerDuration);

        // 1. RPS PHASE TIMEOUT (No setter assigned yet)
        if (battle.setterId == null) {
          AppLogger.log('RPS Timeout', name: 'BattleStateService');
          if (battle.player1RpsMove != null && battle.player2RpsMove == null) {
            // Player 1 moved, Player 2 didn't -> Player 1 wins RPS
            await _client.from('battles').update({
              'setter_id': battle.player1Id,
              'attempter_id': battle.player2Id,
              'current_turn_player_id': battle.player1Id,
              'turn_deadline': newDeadline.toIso8601String(),
            }).eq('id', battle.id!);
            
            // Schedule notification for new deadline
            await NotificationService.scheduleBattleTurnExpiryNotification(
              battle.id!, 
              newDeadline
            );
          } else if (battle.player2RpsMove != null && battle.player1RpsMove == null) {
            // Player 2 moved, Player 1 didn't -> Player 2 wins RPS
            await _client.from('battles').update({
              'setter_id': battle.player2Id,
              'attempter_id': battle.player1Id,
              'current_turn_player_id': battle.player2Id,
              'turn_deadline': newDeadline.toIso8601String(),
            }).eq('id', battle.id!);

            // Schedule notification for new deadline
            await NotificationService.scheduleBattleTurnExpiryNotification(
              battle.id!, 
              newDeadline
            );
          } else {
            // Neither moved -> Randomly assign winner
            final random = Random();
            final player1Wins = random.nextBool();
            
            if (player1Wins) {
              // Player 1 wins RPS
              await _client.from('battles').update({
                'setter_id': battle.player1Id,
                'attempter_id': battle.player2Id,
                'current_turn_player_id': battle.player1Id,
                'turn_deadline': newDeadline.toIso8601String(),
              }).eq('id', battle.id!);

              // Schedule notification for new deadline
              await NotificationService.scheduleBattleTurnExpiryNotification(
                battle.id!, 
                newDeadline
              );
            } else {
              // Player 2 wins RPS
              await _client.from('battles').update({
                'setter_id': battle.player2Id,
                'attempter_id': battle.player1Id,
                'current_turn_player_id': battle.player2Id,
                'turn_deadline': newDeadline.toIso8601String(),
              }).eq('id', battle.id!);

              // Schedule notification for new deadline
              await NotificationService.scheduleBattleTurnExpiryNotification(
                battle.id!, 
                newDeadline
              );
            }
          }
          continue;
        }

        // 2. ACTIVE BATTLE TIMEOUT
        final isSetter = battle.currentTurnPlayerId == battle.setterId;
        AppLogger.log('Active Battle Timeout. Is Setter Turn: $isSetter', name: 'BattleStateService');
        
        if (isSetter) {
          // SETTER TIMEOUT: Failed to upload trick
          // - Assign letter to Setter
          // - Swap roles: Attempter becomes new Setter
          AppLogger.log('Assigning letter to SETTER: ${battle.setterId}', name: 'BattleStateService');
          
          await assignLetter(
            battleId: battle.id!,
            playerId: battle.setterId!,
          );

          // Check if battle ended from letter assignment
          final updatedBattle = await getBattle(battle.id!);
          if (updatedBattle != null && !updatedBattle.isComplete()) {
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
              'setter_vote': null,
              'attempter_vote': null,
              'verification_status': 'none', // Reset status
            }).eq('id', battle.id!);

            // Schedule notification for new deadline
            await NotificationService.scheduleBattleTurnExpiryNotification(
              battle.id!, 
              newDeadline
            );
          }
        } else {
          // ATTEMPTER TIMEOUT: Failed to upload attempt
          // - Assign letter to Attempter
          // - Setter keeps control
          AppLogger.log('Assigning letter to attempter: ${battle.attempterId}', name: 'BattleStateService');
          await assignLetter(
            battleId: battle.id!,
            playerId: battle.attempterId!,
          );
          
          // Check if battle ended from letter assignment
          final updatedBattle = await getBattle(battle.id!);
          if (updatedBattle != null && !updatedBattle.isComplete()) {
            // Reset for next trick (Setter sets again)
            await _client.from('battles').update({
              'current_turn_player_id': battle.setterId,
              'turn_deadline': newDeadline.toIso8601String(),
              'set_trick_video_url': null,
              'attempt_video_url': null,
              'trick_name': null,
              'setter_vote': null,
              'attempter_vote': null,
              'verification_status': 'none',
            }).eq('id', battle.id!);

            // Schedule notification for new deadline
            await NotificationService.scheduleBattleTurnExpiryNotification(
              battle.id!, 
              newDeadline
            );
          }
        }

        // 3. VOTING PHASE TIMEOUT
        if (battle.verificationStatus == VerificationStatus.quickFireVoting) {
          AppLogger.log('Voting Timeout', name: 'BattleStateService');
          if (battle.setterVote != null && battle.attempterVote == null) {
            await _client.from('battles').update({'attempter_vote': battle.setterVote}).eq('id', battle.id!);
            await BattleService.resolveVotes(battle.id!);
          } else if (battle.attempterVote != null && battle.setterVote == null) {
            await _client.from('battles').update({'setter_vote': battle.attempterVote}).eq('id', battle.id!);
            await BattleService.resolveVotes(battle.id!);
          } else {
            // Neither voted - default to missed
            await _client.from('battles').update({
              'setter_vote': 'missed',
              'attempter_vote': 'missed'
            }).eq('id', battle.id!);
            await BattleService.resolveVotes(battle.id!);
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
}
