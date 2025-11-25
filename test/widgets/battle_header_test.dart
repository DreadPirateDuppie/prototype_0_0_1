import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';
import 'package:prototype_0_0_1/utils/duration_utils.dart';

void main() {
  group('BattleHeader Tests', () {
    group('Battle Model', () {
      test('getGameLetters returns SKATE for skate mode', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'SKATE');
      });

      test('getGameLetters returns SK8 for sk8 mode', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.sk8,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'SK8');
      });

      test('getGameLetters returns custom letters', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.custom,
          customLetters: 'FLIP',
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'FLIP');
      });
    });

    group('Turn Indicators', () {
      test('isMyTurn is true when current turn matches user', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'user-1',
          createdAt: DateTime.now(),
        );

        const currentUserId = 'user-1';
        final isMyTurn = battle.currentTurnPlayerId == currentUserId;
        expect(isMyTurn, true);
      });

      test('isMyTurn is false when current turn is opponent', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'user-2',
          createdAt: DateTime.now(),
        );

        const currentUserId = 'user-1';
        final isMyTurn = battle.currentTurnPlayerId == currentUserId;
        expect(isMyTurn, false);
      });
    });

    group('Letters Display', () {
      test('Letter display shows earned letters correctly', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'S',
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        expect(battle.player1Letters.length, 2);
        expect(battle.player2Letters.length, 1);
      });

      test('Game completion check works', () {
        final incompleteBattle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'SKA',
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        final completeBattle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          player1Letters: 'SKATE',
          player2Letters: 'SKA',
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        expect(incompleteBattle.isComplete(), false);
        expect(completeBattle.isComplete(), true);
      });
    });

    group('Timer Display', () {
      test('getRemainingTime returns null when no deadline', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          turnDeadline: null,
        );

        expect(battle.getRemainingTime(), null);
      });

      test('getRemainingTime returns Duration.zero when expired', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          turnDeadline: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(battle.getRemainingTime(), Duration.zero);
      });

      test('formatShort handles null duration', () {
        final result = DurationUtils.formatShort(null);
        expect(result, 'N/A');
      });

      test('formatShort handles zero duration', () {
        final result = DurationUtils.formatShort(Duration.zero);
        expect(result, 'Expired');
      });
    });

    group('Battle Info Badges', () {
      test('Quickfire badge logic', () {
        final quickfireBattle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          isQuickfire: true,
        );

        expect(quickfireBattle.isQuickfire, true);
      });

      test('Bet amount badge logic', () {
        final betBattle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          betAmount: 100,
        );

        expect(betBattle.betAmount, 100);
        expect(betBattle.betAmount > 0, true);
      });

      test('Game mode display', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        final modeLabel = battle.gameMode.toString().split('.').last.toUpperCase();
        expect(modeLabel, 'SKATE');
      });
    });
  });
}
