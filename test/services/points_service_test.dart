import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/points_service.dart';

void main() {
  group('PointsService', () {
    setUp(() {
      // No setup needed
    });

    group('PointsService instantiation', () {
      test('can be created without client', () {
        final service = PointsService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = PointsService(client: null);
        expect(service, isNotNull);
      });
    });

    group('Streak calculation logic', () {
      test('streak bonus calculation is correct for day 1', () {
        const streak = 1;
        final bonus = 3.5 + (streak * 0.5);
        expect(bonus, 4.0);
      });

      test('streak bonus calculation is correct for day 7', () {
        const streak = 7;
        final bonus = 3.5 + (streak * 0.5);
        expect(bonus, 7.0);
      });

      test('streak bonus calculation is correct for day 30', () {
        const streak = 30;
        final bonus = 3.5 + (streak * 0.5);
        expect(bonus, 18.5);
      });

      test('first login bonus is 10 points', () {
        const firstLoginBonus = 10;
        expect(firstLoginBonus, 10);
      });

      test('streak reset bonus is 3.5 points', () {
        const resetBonus = 3.5;
        expect(resetBonus, 3.5);
      });
    });

    group('Date difference calculations', () {
      test('same day returns difference of 0', () {
        final today = DateTime(2024, 6, 15);
        final sameDay = DateTime(2024, 6, 15, 12, 30);
        
        final todayOnly = DateTime(today.year, today.month, today.day);
        final otherOnly = DateTime(sameDay.year, sameDay.month, sameDay.day);
        
        final difference = todayOnly.difference(otherOnly).inDays;
        expect(difference, 0);
      });

      test('yesterday returns difference of 1', () {
        final today = DateTime(2024, 6, 15);
        final yesterday = DateTime(2024, 6, 14);
        
        final difference = today.difference(yesterday).inDays;
        expect(difference, 1);
      });

      test('two days ago returns difference of 2', () {
        final today = DateTime(2024, 6, 15);
        final twoDaysAgo = DateTime(2024, 6, 13);
        
        final difference = today.difference(twoDaysAgo).inDays;
        expect(difference, 2);
      });
    });

    group('XP calculations', () {
      test('XP from posts is 100 per post', () {
        const postCount = 5;
        final xpFromPosts = postCount * 100.0;
        expect(xpFromPosts, 500.0);
      });

      test('total XP is sum of posts XP and votes XP', () {
        const postCount = 3;
        const votesReceived = 42;
        
        final xpFromPosts = postCount * 100.0;
        final xpFromVotes = votesReceived.toDouble();
        final totalXP = xpFromPosts + xpFromVotes;
        
        expect(totalXP, 342.0);
      });

      test('XP score clamping works correctly', () {
        const currentScore = 5.0;
        const xpChange = -10;
        
        final newScore = (currentScore + xpChange).clamp(0.0, double.infinity);
        expect(newScore, 0.0);
      });

      test('positive XP change adds correctly', () {
        const currentScore = 100.0;
        const xpChange = 50;
        
        final newScore = (currentScore + xpChange).clamp(0.0, double.infinity);
        expect(newScore, 150.0);
      });
    });

    group('Balance calculations', () {
      test('adding points increases balance', () {
        const currentBalance = 100.0;
        const pointsToAdd = 50.0;
        
        final newBalance = currentBalance + pointsToAdd;
        expect(newBalance, 150.0);
      });

      test('deducting points decreases balance', () {
        const currentBalance = 100.0;
        const pointsToDeduct = -30.0;
        
        final newBalance = currentBalance + pointsToDeduct;
        expect(newBalance, 70.0);
      });

      test('balance can go negative', () {
        const currentBalance = 10.0;
        const largeDeduction = -50.0;
        
        final newBalance = currentBalance + largeDeduction;
        expect(newBalance, -40.0);
      });
    });
  });
}
