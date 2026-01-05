import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../models/battle_trick.dart';
import '../models/user_scores.dart';
import 'battle_matchmaking_service.dart';
import 'battle_action_service.dart';
import 'battle_state_service.dart';
import 'battle_analytics_service.dart';
import 'battle_lobby_service.dart';

/// Facade for battle-related services.
/// Delegates to specialized services for implementation.
class BattleService {
  
  // ==================== STATE SERVICE DELEGATES ====================

  static Future<Battle?> createBattle({
    required String player1Id,
    required String player2Id,
    required GameMode gameMode,
    String? customLetters,
    int wagerAmount = 0,
    int betAmount = 0,
    bool isQuickfire = false,
  }) {
    return BattleStateService.createBattle(
      player1Id: player1Id,
      player2Id: player2Id,
      gameMode: gameMode,
      customLetters: customLetters,
      wagerAmount: wagerAmount,
      betAmount: betAmount,
      isQuickfire: isQuickfire,
    );
  }

  static Future<List<Battle>> getUserBattles(String userId) {
    return BattleStateService.getUserBattles(userId);
  }

  static Future<List<Battle>> getActiveBattles(String userId) {
    return BattleStateService.getActiveBattles(userId);
  }

  static Future<Battle?> getBattle(String battleId) {
    return BattleStateService.getBattle(battleId);
  }

  static Future<Battle?> assignLetter({
    required String battleId,
    required String playerId,
  }) {
    return BattleStateService.assignLetter(battleId: battleId, playerId: playerId);
  }

  static Future<Battle?> forfeitTurn({
    required String battleId,
    required String playerId,
  }) {
    return BattleStateService.forfeitTurn(battleId: battleId, playerId: playerId);
  }

  static Future<Battle?> completeBattle({
    required String battleId,
    required String winnerId,
  }) {
    return BattleStateService.completeBattle(battleId: battleId, winnerId: winnerId);
  }

  static Future<Battle?> switchTurn(String battleId) {
    return BattleStateService.switchTurn(battleId);
  }

  static Future<void> checkExpiredTurns(String userId) {
    return BattleStateService.checkExpiredTurns(userId);
  }

  static Future<Battle?> forfeitBattle({
    required String battleId,
    required String forfeitingUserId,
  }) {
    return BattleStateService.forfeitBattle(battleId: battleId, forfeitingUserId: forfeitingUserId);
  }

  static Future<List<BattleTrick>> getBattleTricks(String battleId) {
    return BattleStateService.getBattleTricks(battleId);
  }

  // ==================== ACTION SERVICE DELEGATES ====================

  static Future<String> uploadTrickVideo(
    File videoFile,
    String battleId,
    String playerId,
    String type,
  ) {
    return BattleActionService.uploadTrickVideo(videoFile, battleId, playerId, type);
  }

  static Future<Battle?> uploadSetTrick({
    required String battleId,
    required String videoUrl,
    String? trickName,
  }) {
    return BattleActionService.uploadSetTrick(battleId: battleId, videoUrl: videoUrl, trickName: trickName);
  }

  static Future<Battle?> uploadAttempt({
    required String battleId,
    required String videoUrl,
  }) {
    return BattleActionService.uploadAttempt(battleId: battleId, videoUrl: videoUrl);
  }

  static Future<void> submitRpsMove({
    required String battleId,
    required String userId,
    required String move,
  }) {
    return BattleActionService.submitRpsMove(battleId: battleId, userId: userId, move: move);
  }

  static Future<void> submitVote({
    required String battleId,
    required String userId,
    required String vote,
  }) {
    return BattleActionService.submitVote(battleId: battleId, userId: userId, vote: vote);
  }

  static Future<void> resolveVotes(String battleId) {
    return BattleActionService.resolveVotes(battleId);
  }

  static Future<void> acceptBet({
    required String battleId,
    required String opponentId,
    required int betAmount,
  }) {
    return BattleActionService.acceptBet(battleId: battleId, opponentId: opponentId, betAmount: betAmount);
  }

  // ==================== ANALYTICS SERVICE DELEGATES ====================

  static Future<void> updatePlayerScoreForBattle(Battle battle) {
    return BattleAnalyticsService.updatePlayerScoreForBattle(battle);
  }

  static Future<UserScores> getUserScores(String userId) {
    return BattleAnalyticsService.getUserScores(userId);
  }

  static Future<void> updatePlayerScore(String userId, double newScore) {
    return BattleAnalyticsService.updatePlayerScore(userId, newScore);
  }

  static Future<void> updateRankingScore(String userId, double adjustment) {
    return BattleAnalyticsService.updateRankingScore(userId, adjustment);
  }

  static Future<void> updateMapScore(String userId, double newScore) {
    return BattleAnalyticsService.updateMapScore(userId, newScore);
  }

  static Future<Map<String, dynamic>> getUserAnalytics(String userId) {
    return BattleAnalyticsService.getUserAnalytics(userId);
  }

  Future<List<Map<String, dynamic>>> getTopBattlePlayers({int limit = 10}) {
    return BattleAnalyticsService.getTopBattlePlayers(limit: limit);
  }

  // ==================== MATCHMAKING SERVICE DELEGATES ====================

  static Future<void> joinMatchmakingQueue({
    required GameMode gameMode,
    bool isQuickfire = true,
    int betAmount = 0,
  }) {
    return BattleMatchmakingService.joinMatchmakingQueue(
      gameMode: gameMode, 
      isQuickfire: isQuickfire, 
      betAmount: betAmount
    );
  }

  static Future<void> leaveMatchmakingQueue() {
    return BattleMatchmakingService.leaveMatchmakingQueue();
  }

  static Future<Map<String, dynamic>?> findMatch({
    required double myRankingScore,
    required String gameMode,
    required bool isQuickfire,
    int betAmount = 0,
    int expandedRange = 100,
  }) {
    return BattleMatchmakingService.findMatch(
      myRankingScore: myRankingScore, 
      gameMode: gameMode, 
      isQuickfire: isQuickfire, 
      betAmount: betAmount, 
      expandedRange: expandedRange
    );
  }

  static Future<Map<String, dynamic>?> getQueueEntry() {
    return BattleMatchmakingService.getQueueEntry();
  }

  static RealtimeChannel subscribeToQueueUpdates(
    String userId,
    Function(Map<String, dynamic>) onMatch,
  ) {
    return BattleMatchmakingService.subscribeToQueueUpdates(userId, onMatch);
  }

  static Future<Battle?> createBattleFromMatch({
    required String opponentId,
    required GameMode gameMode,
    bool isQuickfire = true,
    int betAmount = 0,
  }) {
    return BattleMatchmakingService.createBattleFromMatch(
      opponentId: opponentId, 
      gameMode: gameMode, 
      isQuickfire: isQuickfire, 
      betAmount: betAmount
    );
  }

  static Future<int> getQueueCount() {
    return BattleMatchmakingService.getQueueCount();
  }

  // ==================== LOBBY METHODS ====================

  static Future<String> createLobby() => BattleLobbyService.createLobby();

  static Future<String> joinLobby(String code) => BattleLobbyService.joinLobby(code);

  static Stream<Map<String, dynamic>> streamLobby(String lobbyId) => BattleLobbyService.streamLobby(lobbyId);

  static Stream<List<Map<String, dynamic>>> streamLobbyPlayers(String lobbyId) => BattleLobbyService.streamLobbyPlayers(lobbyId);

  static Stream<Map<String, dynamic>> streamLobbyEvents(String lobbyId) => BattleLobbyService.streamLobbyEvents(lobbyId);

  static Future<void> leaveLobby(String lobbyId) => BattleLobbyService.leaveLobby(lobbyId);

  static Future<void> updatePlayerLetters(String lobbyId, List<String> letters) => BattleLobbyService.updatePlayerLetters(lobbyId, letters);

  static Future<void> sendLobbyEvent(String lobbyId, String type, Map<String, dynamic> data) => BattleLobbyService.sendLobbyEvent(lobbyId, type, data);
}
