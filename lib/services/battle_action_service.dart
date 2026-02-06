import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../models/battle_trick.dart';
import 'battle_service.dart';
import 'supabase_service.dart';
import 'notification_service.dart';


class BattleActionService {
  static final SupabaseClient _client = Supabase.instance.client;

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
      final battle = await BattleService.getBattle(battleId);
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

      // Cancel existing notification
      await NotificationService.cancelBattleNotification(battleId);
      
      // Schedule new notification for deadline
      await NotificationService.scheduleBattleTurnExpiryNotification(
        battleId, 
        newDeadline
      );



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
      // Calculate deadline for voting
      final battle = await BattleService.getBattle(battleId);
      final isQuickfire = battle?.isQuickfire ?? false;
      final votingDeadline = isQuickfire 
          ? DateTime.now().add(const Duration(minutes: 4, seconds: 20))
          : DateTime.now().add(const Duration(hours: 24));

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
            'turn_deadline': votingDeadline.toIso8601String(),
          })
          .eq('id', battleId)
          .select()
          .single();

      // Cancel existing notification
      await NotificationService.cancelBattleNotification(battleId);
      
      // Schedule new notification for deadline
      await NotificationService.scheduleBattleTurnExpiryNotification(
        battleId, 
        votingDeadline
      );

      return Battle.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upload attempt: $e');
    }
  }

  // Submit RPS move
  static Future<void> submitRpsMove({
    required String battleId,
    required String userId,
    required String move, // 'rock', 'paper', 'scissors'
  }) async {
    try {
      final battle = await BattleService.getBattle(battleId);
      if (battle == null) return;

      final isPlayer1 = userId == battle.player1Id;
      final field = isPlayer1 ? 'player1_rps_move' : 'player2_rps_move';

      await _client.from('battles').update({
        field: move,
      }).eq('id', battleId);

      // Check if both have moved
      final updatedBattle = await BattleService.getBattle(battleId);
      if (updatedBattle != null &&
          updatedBattle.player1RpsMove != null &&
          updatedBattle.player2RpsMove != null) {
        await _resolveRps(updatedBattle);
      }
    } catch (e) {
      throw Exception('Failed to submit RPS move: $e');
    }
  }

  // Resolve RPS outcome
  static Future<void> _resolveRps(Battle battle) async {
    final p1Move = battle.player1RpsMove!;
    final p2Move = battle.player2RpsMove!;

    String? winnerId;

    if (p1Move == p2Move) {
      // Tie - Reset moves
      await _client.from('battles').update({
        'player1_rps_move': null,
        'player2_rps_move': null,
      }).eq('id', battle.id!);
      return;
    }

    // Determine winner
    if ((p1Move == 'rock' && p2Move == 'scissors') ||
        (p1Move == 'paper' && p2Move == 'rock') ||
        (p1Move == 'scissors' && p2Move == 'paper')) {
      winnerId = battle.player1Id;
    } else {
      winnerId = battle.player2Id;
    }

    final loserId = winnerId == battle.player1Id ? battle.player2Id : battle.player1Id;
    
    // Calculate new deadline
    final Duration timerDuration = battle.isQuickfire
        ? const Duration(minutes: 4, seconds: 20)
        : const Duration(hours: 24);
    final newDeadline = DateTime.now().add(timerDuration);

    // Winner becomes Setter, Loser becomes Attempter
    // Winner gets the first turn
    await _client.from('battles').update({
      'setter_id': winnerId,
      'attempter_id': loserId,
      'current_turn_player_id': winnerId,
      'turn_deadline': newDeadline.toIso8601String(),
    }).eq('id', battle.id!);

    // Cancel RPS notification if any
    await NotificationService.cancelBattleNotification(battle.id!);
    
    // Schedule new notification for deadline
    await NotificationService.scheduleBattleTurnExpiryNotification(
      battle.id!, 
      newDeadline
    );
  }

  // Submit vote
  static Future<void> submitVote({
    required String battleId,
    required String userId,
    required String vote, // 'landed' or 'missed'
  }) async {
    try {
      final battle = await BattleService.getBattle(battleId);
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

  // Resolve votes
  static Future<void> resolveVotes(String battleId) async {
    try {
      final battle = await BattleService.getBattle(battleId);
      if (battle == null) return;

      // Check if both voted
      if (battle.setterVote == null || battle.attempterVote == null) return;

      // Check consensus
      if (battle.setterVote == battle.attempterVote) {
        final isLanded = battle.setterVote == 'landed';

        // ARCHIVE TRICK
        if (battle.setTrickVideoUrl != null && battle.attemptVideoUrl != null) {
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
        }

        // Calculate new deadline
        final Duration timerDuration = battle.isQuickfire
            ? const Duration(minutes: 4, seconds: 20)
            : const Duration(hours: 24);
        final newDeadline = DateTime.now().add(timerDuration);

        // Standard Logic for ALL modes (SKATE, SK8, Custom)
        // Rule: "Make it, Keep it" - Setter retains control unless they timeout (handled elsewhere)
        
        if (isLanded) {
          // Attempter landed it -> Setter KEEPS control
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

          // Cancel existing notification
          await NotificationService.cancelBattleNotification(battleId);
          
          // Schedule new notification for deadline
          await NotificationService.scheduleBattleTurnExpiryNotification(
            battleId, 
            newDeadline
          );


        } else {
          // Attempter missed -> They get a letter, Setter stays Setter
          await BattleService.assignLetter(battleId: battleId, playerId: battle.attempterId!);

          // Check if battle ended from letter assignment
          final updatedBattle = await BattleService.getBattle(battleId);
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

            // Cancel existing notification
            await NotificationService.cancelBattleNotification(battleId);
            
            // Schedule new notification for deadline
            await NotificationService.scheduleBattleTurnExpiryNotification(
              battleId, 
              newDeadline
            );
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
}
