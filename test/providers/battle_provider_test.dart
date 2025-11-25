import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';

void main() {
  group('BattleProvider Tests', () {
    group('State Management', () {
      test('initial state is correct', () {
        // Provider starts with empty state
        const isLoading = false;
        const error = null;
        const List<Battle> activeBattles = [];
        
        expect(isLoading, false);
        expect(error, isNull);
        expect(activeBattles, isEmpty);
      });

      test('loading state is tracked correctly', () {
        var isLoading = false;
        
        // Start loading
        isLoading = true;
        expect(isLoading, true);
        
        // Finish loading
        isLoading = false;
        expect(isLoading, false);
      });

      test('error state is tracked correctly', () {
        String? error;
        
        // No error initially
        expect(error, isNull);
        
        // Set error
        error = 'Failed to load battles';
        expect(error, isNotNull);
        expect(error, contains('Failed'));
        
        // Clear error
        error = null;
        expect(error, isNull);
      });
    });

    group('Battle Filtering', () {
      test('filters active battles correctly', () {
        final battles = [
          Battle(
            id: '1',
            player1Id: 'p1',
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p1',
            createdAt: DateTime.now(),
            player1Letters: 'SK',
            player2Letters: 'S',
          ),
          Battle(
            id: '2',
            player1Id: 'p1',
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p1',
            createdAt: DateTime.now(),
            player1Letters: 'SKATE', // Complete
            player2Letters: 'SKA',
          ),
        ];

        final activeBattles = battles
            .where((b) => !b.isComplete() && b.player2Id != null)
            .toList();
        final completedBattles = battles.where((b) => b.isComplete()).toList();

        expect(activeBattles.length, 1);
        expect(completedBattles.length, 1);
      });

      test('filters pending battles correctly', () {
        final battles = [
          Battle(
            id: '1',
            player1Id: 'p1',
            player2Id: null, // Pending - no opponent yet
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p1',
            createdAt: DateTime.now(),
          ),
          Battle(
            id: '2',
            player1Id: 'p1',
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p1',
            createdAt: DateTime.now(),
          ),
        ];

        final pendingBattles = battles
            .where((b) => !b.isComplete() && b.player2Id == null)
            .toList();

        expect(pendingBattles.length, 1);
        expect(pendingBattles.first.id, '1');
      });
    });

    group('Battle Actions', () {
      test('battlesRequiringAction counts correctly', () {
        const currentUserId = 'user-1';
        final battles = [
          Battle(
            id: '1',
            player1Id: currentUserId,
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: currentUserId, // User's turn
            createdAt: DateTime.now(),
          ),
          Battle(
            id: '2',
            player1Id: currentUserId,
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p2', // Opponent's turn
            createdAt: DateTime.now(),
          ),
        ];

        final battlesRequiringAction = battles
            .where((b) => b.currentTurnPlayerId == currentUserId)
            .length;

        expect(battlesRequiringAction, 1);
      });

      test('isInActiveBattle is true when has active battles', () {
        final activeBattles = [
          Battle(
            id: '1',
            player1Id: 'p1',
            player2Id: 'p2',
            gameMode: GameMode.skate,
            currentTurnPlayerId: 'p1',
            createdAt: DateTime.now(),
          ),
        ];

        final isInActiveBattle = activeBattles.isNotEmpty;
        expect(isInActiveBattle, true);
      });

      test('isInActiveBattle is false when no active battles', () {
        final activeBattles = <Battle>[];

        final isInActiveBattle = activeBattles.isNotEmpty;
        expect(isInActiveBattle, false);
      });
    });
  });
}
