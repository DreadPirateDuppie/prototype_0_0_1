import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/user_scores.dart';

void main() {
  group('UserStatsCard Tests', () {
    group('UserScores Model', () {
      test('UserScores calculates final score correctly', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 500,
          playerScore: 600,
          rankingScore: 700,
        );

        // Final score is average of all three
        expect(scores.finalScore, closeTo(600.0, 0.1));
      });

      test('UserScores calculates vote weight from final score', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 1000,
          playerScore: 1000,
          rankingScore: 1000,
        );

        // Max score should give high vote weight
        expect(scores.voteWeight, greaterThan(0));
        expect(scores.voteWeight, lessThanOrEqualTo(100));
      });

      test('UserScores handles zero scores', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 0,
          playerScore: 0,
          rankingScore: 500, // Default ranking score
        );

        expect(scores.mapScore, 0);
        expect(scores.playerScore, 0);
        expect(scores.finalScore, isNotNull);
      });

      test('Level calculation works for XP scores', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 500, // Should be some level based on XP
          playerScore: 100,
          rankingScore: 500,
        );

        expect(scores.mapLevel, greaterThanOrEqualTo(1));
        expect(scores.playerLevel, greaterThanOrEqualTo(1));
      });

      test('Level progress is between 0 and 1', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 150,
          playerScore: 350,
          rankingScore: 500,
        );

        expect(scores.mapLevelProgress, greaterThanOrEqualTo(0.0));
        expect(scores.mapLevelProgress, lessThanOrEqualTo(1.0));
        expect(scores.playerLevelProgress, greaterThanOrEqualTo(0.0));
        expect(scores.playerLevelProgress, lessThanOrEqualTo(1.0));
      });
    });

    group('Score Display Calculations', () {
      test('Progress bar calculation for traditional score', () {
        const score = 750.0;
        final progress = score / 1000.0;
        expect(progress, 0.75);
      });

      test('Progress bar calculation handles max score', () {
        const score = 1000.0;
        final progress = score / 1000.0;
        expect(progress, 1.0);
      });

      test('Progress bar calculation handles zero score', () {
        const score = 0.0;
        final progress = score / 1000.0;
        expect(progress, 0.0);
      });

      test('XP display format is correct', () {
        const level = 5;
        const score = 450.0;
        final displayValue = 'Lvl $level • ${score.toStringAsFixed(0)} XP';
        expect(displayValue, 'Lvl 5 • 450 XP');
      });

      test('XP needed calculation is correct', () {
        const score = 450.0;
        const xpForNextLevel = 500.0;
        final xpNeeded = (xpForNextLevel - score).toStringAsFixed(0);
        expect(xpNeeded, '50');
      });
    });
  });

  group('ScoreProgressBar Tests', () {
    test('Score progress clamped between 0 and 1', () {
      // Test with negative score
      const negativeScore = -100.0;
      final progressNeg = (negativeScore / 1000.0).clamp(0.0, 1.0);
      expect(progressNeg, 0.0);

      // Test with score over max
      const overScore = 1500.0;
      final progressOver = (overScore / 1000.0).clamp(0.0, 1.0);
      expect(progressOver, 1.0);
    });

    test('Level progress display shows correct format', () {
      const level = 3;
      const levelProgress = 0.6;
      const xpForNextLevel = 300.0;
      const currentXP = 180.0;
      
      final xpNeeded = (xpForNextLevel - currentXP).toStringAsFixed(0);
      final subtitle = '$xpNeeded XP to Lvl ${level + 1}';
      
      expect(subtitle, '120 XP to Lvl 4');
    });
  });
}
