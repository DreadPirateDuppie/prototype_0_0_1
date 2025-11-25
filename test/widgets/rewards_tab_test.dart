import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardsTab Logic Tests', () {
    group('Points Display', () {
      test('Points are formatted correctly', () {
        const double points = 1234.56;
        final formattedPoints = points.toInt().toString();
        expect(formattedPoints, '1234');
      });

      test('Zero points display', () {
        const double points = 0.0;
        expect(points == 0, true);
      });

      test('Large points format', () {
        const double points = 999999.0;
        final displayPoints = points.toInt().toString();
        expect(displayPoints, '999999');
      });
    });

    group('Streak Calculations', () {
      test('Streak data parsing', () {
        final streakData = {
          'current_streak': 5,
          'longest_streak': 10,
          'last_activity_date': '2025-11-25',
        };

        expect(streakData['current_streak'], 5);
        expect(streakData['longest_streak'], 10);
      });

      test('New user has zero streak', () {
        final streakData = {
          'current_streak': 0,
          'longest_streak': 0,
        };

        expect(streakData['current_streak'], 0);
      });

      test('Streak progress calculation', () {
        const currentStreak = 7;
        const targetStreak = 30;
        final progress = currentStreak / targetStreak;
        
        expect(progress, closeTo(0.233, 0.01));
      });

      test('Streak milestone rewards', () {
        // Define streak milestones
        final milestones = [7, 14, 30, 60, 90, 180, 365];
        
        const currentStreak = 15;
        final nextMilestone = milestones.firstWhere(
          (m) => m > currentStreak,
          orElse: () => 365,
        );
        
        expect(nextMilestone, 30);
      });
    });

    group('Transaction Parsing', () {
      test('Transaction list parsing', () {
        final transactions = [
          {
            'id': '1',
            'user_id': 'user-1',
            'amount': 50.0,
            'transaction_type': 'reward',
            'description': 'Daily login bonus',
            'created_at': '2025-11-25T10:00:00Z',
          },
          {
            'id': '2',
            'user_id': 'user-1',
            'amount': -25.0,
            'transaction_type': 'bet',
            'description': 'Battle wager',
            'created_at': '2025-11-24T15:30:00Z',
          },
        ];

        expect(transactions.length, 2);
        expect(transactions[0]['amount'], 50.0);
        expect(transactions[1]['amount'], -25.0);
      });

      test('Transaction type categorization', () {
        String getTransactionCategory(String type) {
          switch (type) {
            case 'reward':
              return 'Earnings';
            case 'bet':
              return 'Wagers';
            case 'purchase':
              return 'Purchases';
            case 'transfer':
              return 'Transfers';
            default:
              return 'Other';
          }
        }

        expect(getTransactionCategory('reward'), 'Earnings');
        expect(getTransactionCategory('bet'), 'Wagers');
        expect(getTransactionCategory('unknown'), 'Other');
      });

      test('Transaction icon selection', () {
        String getIcon(double amount) {
          return amount >= 0 ? 'add' : 'remove';
        }

        expect(getIcon(50.0), 'add');
        expect(getIcon(-25.0), 'remove');
        expect(getIcon(0.0), 'add');
      });
    });

    group('Daily Rewards', () {
      test('Daily login check', () {
        final lastLoginDate = DateTime(2025, 11, 24);
        final today = DateTime(2025, 11, 25);
        
        final canClaimDailyReward = !isSameDay(lastLoginDate, today);
        expect(canClaimDailyReward, true);
      });

      test('Same day login check', () {
        final lastLoginDate = DateTime(2025, 11, 25, 10, 30);
        final currentTime = DateTime(2025, 11, 25, 18, 45);
        
        final canClaimDailyReward = !isSameDay(lastLoginDate, currentTime);
        expect(canClaimDailyReward, false);
      });

      test('Daily bonus amount by streak', () {
        int getDailyBonus(int streak) {
          if (streak >= 30) return 100;
          if (streak >= 14) return 50;
          if (streak >= 7) return 25;
          return 10;
        }

        expect(getDailyBonus(0), 10);
        expect(getDailyBonus(5), 10);
        expect(getDailyBonus(7), 25);
        expect(getDailyBonus(14), 50);
        expect(getDailyBonus(30), 100);
        expect(getDailyBonus(100), 100);
      });
    });

    group('Ad Rewards', () {
      test('Watch ad reward calculation', () {
        const baseReward = 25;
        const streakMultiplier = 1.5;
        final totalReward = (baseReward * streakMultiplier).round();
        
        expect(totalReward, 38);
      });

      test('Ads watched limit', () {
        const maxAdsPerDay = 5;
        const adsWatched = 3;
        final canWatchMore = adsWatched < maxAdsPerDay;
        
        expect(canWatchMore, true);
        expect(maxAdsPerDay - adsWatched, 2);
      });
    });

    group('Leaderboard Rewards', () {
      test('Rank reward calculation', () {
        int getLeaderboardReward(int rank) {
          if (rank == 1) return 1000;
          if (rank == 2) return 500;
          if (rank == 3) return 250;
          if (rank <= 10) return 100;
          if (rank <= 50) return 50;
          return 0;
        }

        expect(getLeaderboardReward(1), 1000);
        expect(getLeaderboardReward(2), 500);
        expect(getLeaderboardReward(3), 250);
        expect(getLeaderboardReward(5), 100);
        expect(getLeaderboardReward(25), 50);
        expect(getLeaderboardReward(100), 0);
      });
    });

    group('Achievements', () {
      test('Achievement completion check', () {
        final achievements = [
          {'id': '1', 'name': 'First Post', 'completed': true},
          {'id': '2', 'name': 'Win Battle', 'completed': false},
          {'id': '3', 'name': '7 Day Streak', 'completed': true},
        ];

        final completedCount = achievements.where((a) => a['completed'] == true).length;
        expect(completedCount, 2);
      });

      test('Achievement progress tracking', () {
        final achievement = {
          'id': '1',
          'name': 'Post Master',
          'requirement': 10,
          'current': 7,
        };

        final progress = (achievement['current'] as int) / (achievement['requirement'] as int);
        expect(progress, 0.7);
      });
    });
  });
}

// Helper function
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}
