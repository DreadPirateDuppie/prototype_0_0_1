import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/user_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prototype_0_0_1/services/auth_service.dart';
import 'package:prototype_0_0_1/config/service_locator.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  group('UserService', () {
    late MockAuthService mockAuthService;

    setUp(() async {
      await setupServiceLocatorForTesting();
      mockAuthService = MockAuthService();
      // Unregister the lazy singleton registered by setupServiceLocatorForTesting if we want to provide a mock
      if (getIt.isRegistered<AuthService>()) {
        getIt.unregister<AuthService>();
      }
      getIt.registerSingleton<AuthService>(mockAuthService);
    });

    group('UserService instantiation', () {
      test('can be created without client', () {
        final service = UserService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = UserService(client: null);
        expect(service, isNotNull);
      });
    });

    group('Username validation helpers', () {
      test('normalizeUsername lowercases and trims', () {
        const username = '  TestUser  ';
        final normalized = UserService.normalizeUsername(username);
        expect(normalized, 'testuser');
      });

      test('normalizeUsername handles empty string', () {
        const username = '';
        final normalized = UserService.normalizeUsername(username);
        expect(normalized, '');
      });

      test('normalizeUsername preserves special characters', () {
        const username = 'test_user_123';
        final normalized = UserService.normalizeUsername(username);
        expect(normalized, 'test_user_123');
      });
    });

    group('Email parsing helpers', () {
      test('email prefix extraction works correctly', () {
        const email = 'testuser@example.com';
        final prefix = email.split('@').first;
        expect(prefix, 'testuser');
      });

      test('email with plus sign prefix works', () {
        const email = 'test+tag@example.com';
        final prefix = email.split('@').first;
        expect(prefix, 'test+tag');
      });

      test('email without domain returns full string', () {
        const invalidEmail = 'notanemail';
        final prefix = invalidEmail.split('@').first;
        expect(prefix, 'notanemail');
      });
    });
  });
}
