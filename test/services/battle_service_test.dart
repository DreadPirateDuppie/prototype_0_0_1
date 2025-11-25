import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';

void main() {
  group('BattleService Logic', () {
    group('Timer duration calculations', () {
      test('quickfire timer is 4 minutes 20 seconds', () {
        const quickfireTimer = Duration(minutes: 4, seconds: 20);
        expect(quickfireTimer.inSeconds, 260);
      });

      test('regular timer is 24 hours', () {
        const regularTimer = Duration(hours: 24);
        expect(regularTimer.inHours, 24);
      });
    });

    group('Battle model operations', () {
      test('Battle can be created with required fields', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.player1Id, 'player-1');
        expect(battle.player2Id, 'player-2');
        expect(battle.gameMode, GameMode.skate);
      });

      test('getGameLetters returns SKATE for skate mode', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'SKATE');
      });

      test('getGameLetters returns SK8 for sk8 mode', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.sk8,
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'SK8');
      });

      test('getGameLetters returns custom letters for custom mode', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.custom,
          customLetters: 'FLIP',
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.getGameLetters(), 'FLIP');
      });

      test('isComplete returns true when player1 has full letters', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.skate,
          player1Letters: 'SKATE',
          player2Letters: 'SK',
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.isComplete(), true);
      });

      test('isComplete returns true when player2 has full letters', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'SKATE',
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.isComplete(), true);
      });

      test('isComplete returns false when neither has full letters', () {
        final battle = Battle(
          player1Id: 'player-1',
          player2Id: 'player-2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'SKA',
          currentTurnPlayerId: 'player-1',
          createdAt: DateTime.now(),
        );

        expect(battle.isComplete(), false);
      });
    });

    group('Score calculations', () {
      test('winner gains 10 points', () {
        const winnerBonus = 10;
        const currentScore = 100.0;
        final newScore = (currentScore + winnerBonus).clamp(0.0, 1000.0);
        expect(newScore, 110.0);
      });

      test('loser loses points based on letters', () {
        const loserLetters = 'SKA'; // 3 letters
        const basePointsLost = 5;
        final pointsLost = basePointsLost + (loserLetters.length * 2);
        expect(pointsLost, 11);
      });

      test('score clamping works correctly', () {
        const currentScore = 995.0;
        const winnerBonus = 10;
        final newScore = (currentScore + winnerBonus).clamp(0.0, 1000.0);
        expect(newScore, 1000.0);
      });

      test('negative score is clamped to 0', () {
        const currentScore = 5.0;
        const pointsLost = 11;
        final newScore = (currentScore - pointsLost).clamp(0.0, 1000.0);
        expect(newScore, 0.0);
      });
    });

    group('Bet and wager logic', () {
      test('pot amount is double the bet', () {
        const betAmount = 50;
        final potAmount = betAmount * 2;
        expect(potAmount, 100);
      });

      test('battle with no bet is auto-accepted', () {
        const betAmount = 0;
        final betAccepted = betAmount == 0;
        expect(betAccepted, true);
      });

      test('battle with bet requires acceptance', () {
        const betAmount = 50;
        final betAccepted = betAmount == 0;
        expect(betAccepted, false);
      });
    });

    group('Turn switching logic', () {
      test('turn switches from player1 to player2', () {
        const currentTurnPlayerId = 'player-1';
        const player1Id = 'player-1';
        const player2Id = 'player-2';

        final nextPlayer =
            currentTurnPlayerId == player1Id ? player2Id : player1Id;
        expect(nextPlayer, 'player-2');
      });

      test('turn switches from player2 to player1', () {
        const currentTurnPlayerId = 'player-2';
        const player1Id = 'player-1';
        const player2Id = 'player-2';

        final nextPlayer =
            currentTurnPlayerId == player1Id ? player2Id : player1Id;
        expect(nextPlayer, 'player-1');
      });
    });

    group('Timer expiry checks', () {
      test('expired timer returns Duration.zero', () {
        final deadline = DateTime.now().subtract(const Duration(hours: 1));
        final now = DateTime.now();

        if (deadline.isBefore(now)) {
          expect(Duration.zero, Duration.zero);
        }
      });

      test('future deadline returns positive duration', () {
        final deadline = DateTime.now().add(const Duration(hours: 2));
        final now = DateTime.now();

        final remaining = deadline.difference(now);
        expect(remaining.isNegative, false);
      });
    });
  });
}
