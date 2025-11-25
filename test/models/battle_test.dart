import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';

void main() {
  group('Battle Model', () {
    test('getGameLetters() returns SKATE for skate mode', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.getGameLetters(), 'SKATE');
    });

    test('getGameLetters() returns SK8 for sk8 mode', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.sk8,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.getGameLetters(), 'SK8');
    });

    test('getGameLetters() returns custom letters for custom mode', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.custom,
        customLetters: 'KICKFLIP',
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.getGameLetters(), 'KICKFLIP');
    });

    test('isComplete() returns true when player1 has full letters', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        player1Letters: 'SKATE',
        player2Letters: 'SKA',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.isComplete(), true);
    });

    test('isComplete() returns true when player2 has full letters', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        player1Letters: 'SK',
        player2Letters: 'SKATE',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.isComplete(), true);
    });

    test('isComplete() returns false when neither player has full letters', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        player1Letters: 'SKA',
        player2Letters: 'SK',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(battle.isComplete(), false);
    });

    test('getRemainingTime() returns null when no deadline set', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        turnDeadline: null,
      );

      expect(battle.getRemainingTime(), null);
    });

    test('getRemainingTime() returns Duration.zero when deadline passed', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        turnDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(battle.getRemainingTime(), Duration.zero);
    });

    test('isTimerExpired() returns false when no deadline', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        turnDeadline: null,
      );

      expect(battle.isTimerExpired(), false);
    });

    test('isTimerExpired() returns true when deadline passed', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        turnDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(battle.isTimerExpired(), true);
    });

    test('getTimerDuration() returns 4:20 for quickfire', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        isQuickfire: true,
      );

      expect(battle.getTimerDuration(), const Duration(minutes: 4, seconds: 20));
    });

    test('getTimerDuration() returns 24 hours for regular battle', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
        isQuickfire: false,
      );

      expect(battle.getTimerDuration(), const Duration(hours: 24));
    });

    test('toMap() serializes battle correctly', () {
      final now = DateTime.now();
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        player1Letters: 'SK',
        player2Letters: 'S',
        currentTurnPlayerId: 'user-1',
        createdAt: now,
        wagerAmount: 100,
        betAmount: 50,
        isQuickfire: true,
      );

      final map = battle.toMap();

      expect(map['player1_id'], 'user-1');
      expect(map['player2_id'], 'user-2');
      expect(map['game_mode'], 'skate');
      expect(map['player1_letters'], 'SK');
      expect(map['player2_letters'], 'S');
      expect(map['wager_amount'], 100);
      expect(map['bet_amount'], 50);
      expect(map['is_quickfire'], true);
    });

    test('fromMap() creates valid Battle from map', () {
      final now = DateTime.now();
      final map = {
        'id': 'battle-123',
        'player1_id': 'user-1',
        'player2_id': 'user-2',
        'game_mode': 'skate',
        'player1_letters': 'SKA',
        'player2_letters': 'SK',
        'current_turn_player_id': 'user-2',
        'created_at': now.toIso8601String(),
        'wager_amount': 200,
        'bet_amount': 100,
        'is_quickfire': false,
        'bet_accepted': true,
      };

      final battle = Battle.fromMap(map);

      expect(battle.id, 'battle-123');
      expect(battle.player1Id, 'user-1');
      expect(battle.player2Id, 'user-2');
      expect(battle.gameMode, GameMode.skate);
      expect(battle.player1Letters, 'SKA');
      expect(battle.player2Letters, 'SK');
      expect(battle.wagerAmount, 200);
      expect(battle.betAmount, 100);
      expect(battle.betAccepted, true);
    });

    test('copyWith() creates new instance with updated values', () {
      final battle = Battle(
        player1Id: 'user-1',
        player2Id: 'user-2',
        gameMode: GameMode.skate,
        player1Letters: 'SK',
        currentTurnPlayerId: 'user-1',
        createdAt: DateTime.now(),
      );

      final updated = battle.copyWith(
        player1Letters: 'SKA',
        currentTurnPlayerId: 'user-2',
      );

      expect(updated.player1Letters, 'SKA');
      expect(updated.currentTurnPlayerId, 'user-2');
      expect(updated.player1Id, 'user-1'); // unchanged
      expect(updated.gameMode, GameMode.skate); // unchanged
    });
  });
}
