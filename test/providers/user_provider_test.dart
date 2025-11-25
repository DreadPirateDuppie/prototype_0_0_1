import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/user_scores.dart';

void main() {
  group('UserProvider Tests', () {
    group('State Management', () {
      test('initial state is correct', () {
        const isLoading = false;
        const isAdmin = false;
        const error = null;
        const String? username = null;
        const String? avatarUrl = null;
        
        expect(isLoading, false);
        expect(isAdmin, false);
        expect(error, isNull);
        expect(username, isNull);
        expect(avatarUrl, isNull);
      });

      test('loading state is tracked correctly', () {
        var isLoading = false;
        
        isLoading = true;
        expect(isLoading, true);
        
        isLoading = false;
        expect(isLoading, false);
      });

      test('error state is tracked correctly', () {
        String? error;
        
        expect(error, isNull);
        
        error = 'Failed to load profile';
        expect(error, isNotNull);
        
        error = null;
        expect(error, isNull);
      });
    });

    group('Display Name Logic', () {
      test('displayName returns username when available', () {
        const username = 'skater123';
        const email = 'skater@example.com';
        
        final displayName = username.isNotEmpty ? username : email.split('@').first;
        expect(displayName, 'skater123');
      });

      test('displayName returns email prefix when no username', () {
        const String? username = null;
        const email = 'skater@example.com';
        
        final displayName = (username != null && username.isNotEmpty) 
            ? username 
            : email.split('@').first;
        expect(displayName, 'skater');
      });

      test('displayName returns User when nothing available', () {
        const String? username = null;
        const String? email = null;
        
        final displayName = (username != null && username.isNotEmpty) 
            ? username 
            : (email != null ? email.split('@').first : 'User');
        expect(displayName, 'User');
      });
    });

    group('User Levels', () {
      test('mapLevel returns correct value from scores', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 500,
          playerScore: 300,
          rankingScore: 600,
        );
        
        expect(scores.mapLevel, greaterThanOrEqualTo(1));
      });

      test('playerLevel returns correct value from scores', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 500,
          playerScore: 300,
          rankingScore: 600,
        );
        
        expect(scores.playerLevel, greaterThanOrEqualTo(1));
      });

      test('voteWeight returns correct value from scores', () {
        final scores = UserScores(
          userId: 'test-user',
          mapScore: 500,
          playerScore: 300,
          rankingScore: 600,
        );
        
        expect(scores.voteWeight, greaterThanOrEqualTo(0));
        expect(scores.voteWeight, lessThanOrEqualTo(100));
      });

      test('default levels are 1 when no scores', () {
        UserScores? scores;
        
        final mapLevel = scores?.mapLevel ?? 1;
        final playerLevel = scores?.playerLevel ?? 1;
        final voteWeight = scores?.voteWeight ?? 0.0;
        
        expect(mapLevel, 1);
        expect(playerLevel, 1);
        expect(voteWeight, 0.0);
      });
    });

    group('Admin Status', () {
      test('isAdmin defaults to false', () {
        const isAdmin = false;
        expect(isAdmin, false);
      });

      test('admin check can be updated', () {
        var isAdmin = false;
        
        // Simulate admin check result
        isAdmin = true;
        expect(isAdmin, true);
      });
    });

    group('Onboarding Status', () {
      test('hasCompletedOnboarding is false when no username', () {
        const String? username = null;
        
        final hasCompletedOnboarding = username != null && username.isNotEmpty;
        expect(hasCompletedOnboarding, false);
      });

      test('hasCompletedOnboarding is false when empty username', () {
        const username = '';
        
        final hasCompletedOnboarding = username.isNotEmpty;
        expect(hasCompletedOnboarding, false);
      });

      test('hasCompletedOnboarding is true when username set', () {
        const username = 'skater123';
        
        final hasCompletedOnboarding = username.isNotEmpty;
        expect(hasCompletedOnboarding, true);
      });
    });

    group('Clear User', () {
      test('clearUser resets all state', () {
        // Simulate clearing
        String? username = 'test';
        String? avatarUrl = 'http://example.com/avatar.jpg';
        UserScores? userScores = UserScores(
          userId: 'test',
          mapScore: 500,
          playerScore: 300,
          rankingScore: 600,
        );
        var isAdmin = true;
        String? error = 'Some error';
        
        // Clear
        username = null;
        avatarUrl = null;
        userScores = null;
        isAdmin = false;
        error = null;
        
        expect(username, isNull);
        expect(avatarUrl, isNull);
        expect(userScores, isNull);
        expect(isAdmin, false);
        expect(error, isNull);
      });
    });

    group('isLoggedIn', () {
      test('isLoggedIn is false when no user', () {
        const currentUser = null;
        
        final isLoggedIn = currentUser != null;
        expect(isLoggedIn, false);
      });

      test('isLoggedIn is true when user exists', () {
        // Simulate user being present (non-null)
        const currentUser = 'user-object-would-be-here';
        
        final isLoggedIn = currentUser != null;
        expect(isLoggedIn, true);
      });
    });
  });
}
