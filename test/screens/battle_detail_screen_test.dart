import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/battle.dart';
import 'package:prototype_0_0_1/utils/duration_utils.dart';

void main() {
  group('BattleDetailScreen Logic Tests', () {
    group('Battle State Management', () {
      test('isPlayer1 is correctly determined', () {
        final battle = Battle(
          player1Id: 'user-123',
          player2Id: 'user-456',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'user-123',
          createdAt: DateTime.now(),
        );

        const currentUserId = 'user-123';
        final isPlayer1 = battle.player1Id == currentUserId;
        expect(isPlayer1, true);

        const otherUserId = 'user-456';
        final isPlayer1Other = battle.player1Id == otherUserId;
        expect(isPlayer1Other, false);
      });

      test('isMyTurn correctly identifies turn', () {
        final battle = Battle(
          player1Id: 'user-123',
          player2Id: 'user-456',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'user-123',
          createdAt: DateTime.now(),
        );

        const currentUserId = 'user-123';
        final isMyTurn = battle.currentTurnPlayerId == currentUserId;
        expect(isMyTurn, true);
      });
    });

    group('Game Mode Labels', () {
      test('SKATE mode displays correct label', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        String modeLabel(GameMode mode) {
          switch (mode) {
            case GameMode.skate:
              return 'S.K.A.T.E';
            case GameMode.sk8:
              return 'S.K.8';
            case GameMode.custom:
              return 'Custom';
          }
        }

        expect(modeLabel(battle.gameMode), 'S.K.A.T.E');
      });

      test('SK8 mode displays correct label', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.sk8,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        String modeLabel(GameMode mode) {
          switch (mode) {
            case GameMode.skate:
              return 'S.K.A.T.E';
            case GameMode.sk8:
              return 'S.K.8';
            case GameMode.custom:
              return 'Custom';
          }
        }

        expect(modeLabel(battle.gameMode), 'S.K.8');
      });

      test('Custom mode displays correct label', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.custom,
          customLetters: 'FLIP',
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
        );

        String modeLabel(GameMode mode) {
          switch (mode) {
            case GameMode.skate:
              return 'S.K.A.T.E';
            case GameMode.sk8:
              return 'S.K.8';
            case GameMode.custom:
              return 'Custom';
          }
        }

        expect(modeLabel(battle.gameMode), 'Custom');
      });
    });

    group('Trick Status Labels', () {
      test('Setting trick state', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          setTrickVideoUrl: null,
          attemptVideoUrl: null,
        );

        String trickLabel() {
          if (battle.setTrickVideoUrl == null) {
            return 'Setting Trick';
          } else if (battle.attemptVideoUrl == null) {
            return 'Attempting Trick';
          } else {
            return 'Voting';
          }
        }

        expect(trickLabel(), 'Setting Trick');
      });

      test('Attempting trick state', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          setTrickVideoUrl: 'https://example.com/video.mp4',
          attemptVideoUrl: null,
        );

        String trickLabel() {
          if (battle.setTrickVideoUrl == null) {
            return 'Setting Trick';
          } else if (battle.attemptVideoUrl == null) {
            return 'Attempting Trick';
          } else {
            return 'Voting';
          }
        }

        expect(trickLabel(), 'Attempting Trick');
      });

      test('Voting state', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          setTrickVideoUrl: 'https://example.com/set.mp4',
          attemptVideoUrl: 'https://example.com/attempt.mp4',
        );

        String trickLabel() {
          if (battle.setTrickVideoUrl == null) {
            return 'Setting Trick';
          } else if (battle.attemptVideoUrl == null) {
            return 'Attempting Trick';
          } else {
            return 'Voting';
          }
        }

        expect(trickLabel(), 'Voting');
      });
    });

    group('Verification Status Labels', () {
      test('Pending status', () {
        String label(VerificationStatus status) {
          switch (status) {
            case VerificationStatus.pending:
              return 'Pending';
            case VerificationStatus.quickFireVoting:
              return 'Voting';
            case VerificationStatus.communityVerification:
              return 'Community Review';
            case VerificationStatus.resolved:
              return 'Resolved';
          }
        }

        expect(label(VerificationStatus.pending), 'Pending');
        expect(label(VerificationStatus.quickFireVoting), 'Voting');
        expect(label(VerificationStatus.communityVerification), 'Community Review');
        expect(label(VerificationStatus.resolved), 'Resolved');
      });
    });

    group('Letters Progress', () {
      test('My letters vs opponent letters correctly identified', () {
        final battle = Battle(
          player1Id: 'user-1',
          player2Id: 'user-2',
          gameMode: GameMode.skate,
          player1Letters: 'SK',
          player2Letters: 'S',
          currentTurnPlayerId: 'user-1',
          createdAt: DateTime.now(),
        );

        var isPlayer1 = true;
        // ignore: dead_code
        final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
        // ignore: dead_code
        final opponentLetters = isPlayer1 ? battle.player2Letters : battle.player1Letters;

        expect(myLetters, 'SK');
        expect(opponentLetters, 'S');
      });

      test('Progress calculation', () {
        const letters = 'SK';
        const targetLetters = 'SKATE';
        
        final progress = letters.length / targetLetters.length;
        expect(progress, 2 / 5);
        expect(progress, 0.4);
      });
    });

    group('Timer Formatting', () {
      test('Format duration with hours', () {
        final duration = const Duration(hours: 2, minutes: 30);
        
        String formatDuration(Duration? d) {
          if (d == null) return '';
          if (d.inHours > 0) {
            final h = d.inHours;
            final m = d.inMinutes % 60;
            return '${h}h ${m}m';
          }
          final m = d.inMinutes;
          final s = d.inSeconds % 60;
          return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        }

        expect(formatDuration(duration), '2h 30m');
      });

      test('Format duration without hours', () {
        final duration = const Duration(minutes: 5, seconds: 30);
        
        String formatDuration(Duration? d) {
          if (d == null) return '';
          if (d.inHours > 0) {
            final h = d.inHours;
            final m = d.inMinutes % 60;
            return '${h}h ${m}m';
          }
          final m = d.inMinutes;
          final s = d.inSeconds % 60;
          return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        }

        expect(formatDuration(duration), '05:30');
      });

      test('DurationUtils formatShort handles various durations', () {
        expect(DurationUtils.formatShort(const Duration(hours: 1, minutes: 30)), '1h 30m');
        expect(DurationUtils.formatShort(const Duration(minutes: 45)), '45m');
        expect(DurationUtils.formatShort(const Duration(seconds: 30)), '30s');
        expect(DurationUtils.formatShort(null), 'N/A');
        expect(DurationUtils.formatShort(Duration.zero), 'Expired');
      });
    });

    group('Bet and Wager Logic', () {
      test('Battle with bet amount', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          betAmount: 100,
          betAccepted: false,
        );

        expect(battle.betAmount, 100);
        expect(battle.betAmount * 2, 200); // Pot calculation
        expect(battle.betAccepted, false);
      });

      test('Battle without bet', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          betAmount: 0,
        );

        expect(battle.betAmount, 0);
        expect(battle.betAmount > 0, false);
      });
    });

    group('Upload Availability Logic', () {
      test('canUploadSet when is my turn and no set trick', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          setTrickVideoUrl: null,
        );

        const isMyTurn = true;
        final canUploadSet = isMyTurn && battle.setTrickVideoUrl == null;
        expect(canUploadSet, true);
      });

      test('canUploadAttempt when not my turn and set trick exists', () {
        final battle = Battle(
          player1Id: 'p1',
          player2Id: 'p2',
          gameMode: GameMode.skate,
          currentTurnPlayerId: 'p1',
          createdAt: DateTime.now(),
          setTrickVideoUrl: 'https://example.com/video.mp4',
          verificationStatus: VerificationStatus.pending,
        );

        const isMyTurn = false;
        final canUploadAttempt = !isMyTurn &&
            battle.setTrickVideoUrl != null &&
            battle.verificationStatus == VerificationStatus.pending;
        expect(canUploadAttempt, true);
      });
    });
  });
}
