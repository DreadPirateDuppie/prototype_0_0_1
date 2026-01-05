import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BattleService Analytics Logic', () {
    test('Favorite trick calculation logic', () {
      final tricks = [
        {'trick_name': 'Kickflip'},
        {'trick_name': 'Heelflip'},
        {'trick_name': 'Kickflip'},
        {'trick_name': 'Tre Flip'},
        {'trick_name': 'Kickflip'},
      ];

      final Map<String, int> trickCounts = {};
      for (final trick in tricks) {
        final name = trick['trick_name'] as String;
        trickCounts[name] = (trickCounts[name] ?? 0) + 1;
      }

      final favoriteTrick = trickCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      expect(favoriteTrick, 'Kickflip');
    });

    test('Win/Loss calculation logic', () {
      final userId = 'user-1';
      final battles = [
        {'winner_id': 'user-1', 'player1_id': 'user-1', 'player2_id': 'user-2'},
        {'winner_id': 'user-2', 'player1_id': 'user-1', 'player2_id': 'user-2'},
        {'winner_id': 'user-1', 'player1_id': 'user-3', 'player2_id': 'user-1'},
      ];

      int wins = 0;
      int losses = 0;

      for (final battle in battles) {
        if (battle['winner_id'] == userId) {
          wins++;
        } else if (battle['winner_id'] != null) {
          losses++;
        }
      }

      expect(wins, 2);
      expect(losses, 1);
    });
  });
}
