import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../models/verification.dart';
import 'battle_service.dart';

class VerificationService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Create a verification attempt
  static Future<VerificationAttempt?> createVerificationAttempt({
    required String battleId,
    required String attemptingPlayerId,
    required String attemptVideoUrl,
  }) async {
    try {
      final attempt = VerificationAttempt(
        battleId: battleId,
        attemptingPlayerId: attemptingPlayerId,
        attemptVideoUrl: attemptVideoUrl,
        createdAt: DateTime.now(),
      );

      final response = await _client
          .from('verification_attempts')
          .insert(attempt.toMap())
          .select()
          .single();

      return VerificationAttempt.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create verification attempt: $e');
    }
  }

  // Create Quick-Fire vote session
  static Future<QuickFireVote?> createQuickFireVote({
    required String attemptId,
    required String player1Id,
    required String player2Id,
  }) async {
    try {
      final quickFireVote = QuickFireVote(
        attemptId: attemptId,
        player1Id: player1Id,
        player2Id: player2Id,
        createdAt: DateTime.now(),
      );

      final response = await _client
          .from('quick_fire_votes')
          .insert(quickFireVote.toMap())
          .select()
          .single();

      return QuickFireVote.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create Quick-Fire vote: $e');
    }
  }

  // Submit Quick-Fire vote
  static Future<QuickFireVote?> submitQuickFireVote({
    required String attemptId,
    required String playerId,
    required VoteType vote,
  }) async {
    try {
      // Get existing Quick-Fire vote
      final response = await _client
          .from('quick_fire_votes')
          .select()
          .eq('attempt_id', attemptId)
          .single();

      final quickFireVote = QuickFireVote.fromMap(response);

      // Update with player's vote
      Map<String, dynamic> updates = {};
      if (quickFireVote.player1Id == playerId) {
        updates['player1_vote'] = vote.toString().split('.').last;
      } else if (quickFireVote.player2Id == playerId) {
        updates['player2_vote'] = vote.toString().split('.').last;
      }

      final updatedResponse = await _client
          .from('quick_fire_votes')
          .update(updates)
          .eq('attempt_id', attemptId)
          .select()
          .single();

      final updatedVote = QuickFireVote.fromMap(updatedResponse);

      // Process result if both players have voted
      if (updatedVote.bothPlayersVoted) {
        await processQuickFireResult(attemptId, updatedVote);
      }

      return updatedVote;
    } catch (e) {
      throw Exception('Failed to submit Quick-Fire vote: $e');
    }
  }

  // Process Quick-Fire result
  static Future<void> processQuickFireResult(
    String attemptId,
    QuickFireVote quickFireVote,
  ) async {
    try {
      final attempt = await getVerificationAttempt(attemptId);
      if (attempt == null) return;

      if (quickFireVote.needsRebate) {
        // Rebate - mark for retry
        await _client
            .from('verification_attempts')
            .update({
              'status': VerificationStatus.pending.toString().split('.').last,
              'result': VoteType.rebate.toString().split('.').last,
            })
            .eq('id', attemptId);
      } else if (quickFireVote.playersAgree) {
        // Players agree - resolve immediately
        await resolveAttempt(
          attemptId: attemptId,
          result: quickFireVote.agreedVote!,
        );
      } else if (quickFireVote.needsCommunityVerification) {
        // Disagreement - escalate to community
        await _client
            .from('verification_attempts')
            .update({
              'status': VerificationStatus.communityVerification
                  .toString()
                  .split('.')
                  .last,
            })
            .eq('id', attemptId);
      }
    } catch (e) {
      throw Exception('Failed to process Quick-Fire result: $e');
    }
  }

  // Submit community vote
  static Future<Vote?> submitCommunityVote({
    required String attemptId,
    required String userId,
    required VoteType voteType,
  }) async {
    try {
      // Get user's vote weight
      final scores = await BattleService.getUserScores(userId);
      final voteWeight = scores.voteWeight;

      // Check if user already voted
      final existingVote = await _client
          .from('community_votes')
          .select()
          .eq('attempt_id', attemptId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingVote != null) {
        // Update existing vote
        final response = await _client
            .from('community_votes')
            .update({
              'vote_type': voteType.toString().split('.').last,
              'vote_weight': voteWeight,
            })
            .eq('attempt_id', attemptId)
            .eq('user_id', userId)
            .select()
            .single();

        return Vote.fromMap(response);
      } else {
        // Create new vote
        final vote = Vote(
          attemptId: attemptId,
          userId: userId,
          voteType: voteType,
          voteWeight: voteWeight,
          createdAt: DateTime.now(),
        );

        final response = await _client
            .from('community_votes')
            .insert(vote.toMap())
            .select()
            .single();

        return Vote.fromMap(response);
      }
    } catch (e) {
      throw Exception('Failed to submit community vote: $e');
    }
  }

  // Get votes for an attempt
  static Future<List<Vote>> getVotesForAttempt(String attemptId) async {
    try {
      final response = await _client
          .from('community_votes')
          .select()
          .eq('attempt_id', attemptId)
          .order('created_at', ascending: false);

      return (response as List).map((vote) => Vote.fromMap(vote)).toList();
    } catch (e) {
      return [];
    }
  }

  // Calculate weighted vote result
  static Future<VoteType?> calculateWeightedResult(String attemptId) async {
    try {
      final votes = await getVotesForAttempt(attemptId);
      if (votes.isEmpty) return null;

      double landWeight = 0;
      double noLandWeight = 0;
      double rebateWeight = 0;

      for (var vote in votes) {
        switch (vote.voteType) {
          case VoteType.land:
            landWeight += vote.voteWeight;
            break;
          case VoteType.noLand:
            noLandWeight += vote.voteWeight;
            break;
          case VoteType.rebate:
            rebateWeight += vote.voteWeight;
            break;
        }
      }

      // Determine winner
      if (landWeight > noLandWeight && landWeight > rebateWeight) {
        return VoteType.land;
      } else if (noLandWeight > landWeight && noLandWeight > rebateWeight) {
        return VoteType.noLand;
      } else if (rebateWeight > landWeight && rebateWeight > noLandWeight) {
        return VoteType.rebate;
      }

      // Tie - default to no land
      return VoteType.noLand;
    } catch (e) {
      return null;
    }
  }

  // Resolve verification attempt
  static Future<void> resolveAttempt({
    required String attemptId,
    required VoteType result,
  }) async {
    try {
      final attempt = await getVerificationAttempt(attemptId);
      if (attempt == null) return;

      // Update attempt status
      await _client
          .from('verification_attempts')
          .update({
            'status': VerificationStatus.resolved.toString().split('.').last,
            'result': result.toString().split('.').last,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', attemptId);

      // Process result
      if (result == VoteType.noLand) {
        // Failed attempt - assign letter
        await BattleService.assignLetter(
          battleId: attempt.battleId,
          playerId: attempt.attemptingPlayerId,
        );
      } else if (result == VoteType.land) {
        // Successful attempt - switch turn
        await BattleService.switchTurn(attempt.battleId);
      }
      // Rebate - no action, player can retry

      // Update ranking scores for community voters
      if (attempt.status == VerificationStatus.communityVerification) {
        await updateRankingScores(attemptId, result);
      }
    } catch (e) {
      throw Exception('Failed to resolve attempt: $e');
    }
  }

  // Update ranking scores based on voting accuracy
  static Future<void> updateRankingScores(
    String attemptId,
    VoteType majorityResult,
  ) async {
    try {
      final votes = await getVotesForAttempt(attemptId);

      for (var vote in votes) {
        if (vote.voteType == VoteType.rebate) {
          // Rebate votes don't affect ranking
          continue;
        }

        if (vote.voteType == majorityResult) {
          // Voted with majority - increase score
          await BattleService.updateRankingScore(vote.userId, 1);
        } else {
          // Voted against majority - decrease score
          await BattleService.updateRankingScore(vote.userId, -1);
        }
      }

      // Check for repeat trolling (future enhancement)
      // Would need to track consecutive wrong votes
    } catch (e) {
      // Silently fail ranking updates
    }
  }

  // Get verification attempt
  static Future<VerificationAttempt?> getVerificationAttempt(
    String attemptId,
  ) async {
    try {
      final response = await _client
          .from('verification_attempts')
          .select()
          .eq('id', attemptId)
          .single();

      return VerificationAttempt.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  // Get community verification queue
  static Future<List<VerificationAttempt>>
  getCommunityVerificationQueue() async {
    try {
      final response = await _client
          .from('verification_attempts')
          .select()
          .eq(
            'status',
            VerificationStatus.communityVerification.toString().split('.').last,
          )
          .order('created_at', ascending: true);

      return (response as List)
          .map((attempt) => VerificationAttempt.fromMap(attempt))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get Quick-Fire vote for attempt
  static Future<QuickFireVote?> getQuickFireVote(String attemptId) async {
    try {
      final response = await _client
          .from('quick_fire_votes')
          .select()
          .eq('attempt_id', attemptId)
          .maybeSingle();

      if (response != null) {
        return QuickFireVote.fromMap(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
