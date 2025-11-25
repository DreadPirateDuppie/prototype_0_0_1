import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';

void main() {
  group('VsTab Logic Tests', () {
    group('Game Mode Display', () {
      test('SKATE mode label', () {
        String getGameModeDisplay(GameMode mode) {
          switch (mode) {
            case GameMode.skate:
              return 'SKATE';
            case GameMode.sk8:
              return 'SK8';
            case GameMode.custom:
              return 'Custom';
          }
        }

        expect(getGameModeDisplay(GameMode.skate), 'SKATE');
        expect(getGameModeDisplay(GameMode.sk8), 'SK8');
        expect(getGameModeDisplay(GameMode.custom), 'Custom');
      });
    });

    group('Battle Filtering', () {
      late List<Battle> battles;

      setUp(() {
        battles = [
          Battle(
            id: '1',
            player1Id: 'user-1',
            player2Id: 'user-2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            createdAt: DateTime.now(),
            status: 'active',
          ),
          Battle(
            id: '2',
            player1Id: 'user-1',
            player2Id: 'user-3',
            gameMode: GameMode.sk8,
            currentTurnPlayerId: 'user-3',
            createdAt: DateTime.now(),
            status: 'completed',
            winnerId: 'user-1',
          ),
          Battle(
            id: '3',
            player1Id: 'user-2',
            player2Id: 'user-1',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-2',
            createdAt: DateTime.now(),
            status: 'pending',
          ),
        ];
      });

      test('Filter active battles', () {
        final activeBattles = battles.where((b) => b.status == 'active').toList();
        expect(activeBattles.length, 1);
        expect(activeBattles.first.id, '1');
      });

      test('Filter completed battles', () {
        final completedBattles = battles.where((b) => b.status == 'completed').toList();
        expect(completedBattles.length, 1);
        expect(completedBattles.first.winnerId, 'user-1');
      });

      test('Filter pending battles', () {
        final pendingBattles = battles.where((b) => b.status == 'pending').toList();
        expect(pendingBattles.length, 1);
      });

      test('Filter my turn battles', () {
        const currentUserId = 'user-1';
        final myTurnBattles = battles.where(
          (b) => b.currentTurnPlayerId == currentUserId && b.status == 'active',
        ).toList();
        expect(myTurnBattles.length, 1);
      });
    });

    group('Battle Card Logic', () {
      test('isPlayer1 determination', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'user-1',
          createdAt: DateTime.now(),
        );

        const currentUserId = 'user-1';
        final isPlayer1 = battle.player1Id == currentUserId;
        expect(isPlayer1, true);
      });

      test('My letters vs opponent letters as player 1', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'S',
          currentTurnPlayerId: 'user-1',
          createdAt: DateTime.now(),
        );

        const isPlayer1 = true;
        final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
        final opponentLetters = isPlayer1 ? battle.player2Letters : battle.player1Letters;

        expect(myLetters, 'SK');
        expect(opponentLetters, 'S');
      });

      test('My letters vs opponent letters as player 2', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'S',
          currentTurnPlayerId: 'user-1',
          createdAt: DateTime.now(),
        );

        const isPlayer1 = false; // currentUserId = 'user-2'
        final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
        final opponentLetters = isPlayer1 ? battle.player2Letters : battle.player1Letters;

        expect(myLetters, 'S');
        expect(opponentLetters, 'SK');
      });

      test('Is my turn check', () {
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

        const otherUserId = 'user-2';
        final isOthersTurn = battle.currentTurnPlayerId == otherUserId;
        expect(isOthersTurn, false);
      });
    });

    group('Battle Status Display', () {
      test('Active battle status', () {
        String getStatusLabel(String status) {
          switch (status) {
            case 'active':
              return 'In Progress';
            case 'pending':
              return 'Waiting';
            case 'completed':
              return 'Finished';
            default:
              return 'Unknown';
          }
        }

        expect(getStatusLabel('active'), 'In Progress');
        expect(getStatusLabel('pending'), 'Waiting');
        expect(getStatusLabel('completed'), 'Finished');
      });

      test('Turn indicator text', () {
        String getTurnText(bool isMyTurn) {
          return isMyTurn ? 'Your Turn!' : 'Waiting...';
        }

        expect(getTurnText(true), 'Your Turn!');
        expect(getTurnText(false), 'Waiting...');
      });
    });

    group('Battle Sorting', () {
      test('Sort by my turn first', () {
        final battles = [
          Battle(
            id: '1',
            player1Id: 'user-1',
            player2Id: 'user-2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-2',
            createdAt: DateTime.now(),
          ),
          Battle(
            id: '2',
            player1Id: 'user-1',
            player2Id: 'user-3',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            createdAt: DateTime.now(),
          ),
        ];

        const currentUserId = 'user-1';
        
        // Sort: my turn battles first
        battles.sort((a, b) {
          final aIsMyTurn = a.currentTurnPlayerId == currentUserId;
          final bIsMyTurn = b.currentTurnPlayerId == currentUserId;
          if (aIsMyTurn && !bIsMyTurn) return -1;
          if (!aIsMyTurn && bIsMyTurn) return 1;
          return 0;
        });

        expect(battles.first.id, '2'); // My turn battle first
        expect(battles.first.currentTurnPlayerId, currentUserId);
      });

      test('Sort by most recent', () {
        final battles = [
          Battle(
            id: '1',
            player1Id: 'user-1',
            player2Id: 'user-2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            createdAt: DateTime(2025, 11, 20),
          ),
          Battle(
            id: '2',
            player1Id: 'user-1',
            player2Id: 'user-3',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            createdAt: DateTime(2025, 11, 25),
          ),
        ];

        // Sort by most recent
        battles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        expect(battles.first.id, '2');
      });
    });

    group('Actions Count', () {
      test('Count battles requiring action', () {
        final battles = [
          Battle(
            id: '1',
            player1Id: 'user-1',
            player2Id: 'user-2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            status: 'active',
            createdAt: DateTime.now(),
          ),
          Battle(
            id: '2',
            player1Id: 'user-1',
            player2Id: 'user-3',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-3',
            status: 'active',
            createdAt: DateTime.now(),
          ),
          Battle(
            id: '3',
            player1Id: 'user-4',
            player2Id: 'user-1',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'user-1',
            status: 'active',
            createdAt: DateTime.now(),
          ),
        ];

        const currentUserId = 'user-1';
        final actionsRequired = battles.where(
          (b) => b.currentTurnPlayerId == currentUserId && b.status == 'active',
        ).length;

        expect(actionsRequired, 2);
      });
    });

    group('Empty States', () {
      test('No battles message', () {
        final battles = <Battle>[];
        
        expect(battles.isEmpty, true);
        
        String getEmptyMessage(bool hasAnyBattles) {
          return hasAnyBattles 
              ? 'No battles match your filter' 
              : 'Start your first S.K.A.T.E battle!';
        }

        expect(getEmptyMessage(false), 'Start your first S.K.A.T.E battle!');
      });
    });

    group('Quickfire and Bet Badges', () {
      test('Quickfire battle badge', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          isQuickfire: true,
        );

        expect(battle.isQuickfire, true);
      });

      test('Bet amount badge', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          betAmount: 100,
        );

        expect(battle.betAmount > 0, true);
        expect(battle.betAmount, 100);
      });
    });
  });
}
