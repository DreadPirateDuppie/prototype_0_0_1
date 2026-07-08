import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/nbd_service.dart';

void main() {
  group('NbdService', () {
    group('instantiation', () {
      test('can be created without client', () {
        final service = NbdService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = NbdService(client: null);
        expect(service, isNotNull);
      });
    });

    group('review pipeline constants (server-side mirrors)', () {
      // These mirror the tunable placeholders in points_config
      // (supabase/migrations/20260708_nbd_registry.sql). The server is
      // authoritative; these tests document the intended default balance.
      const bountyPoints = 250.0;
      const approvalsRequired = 3;
      const rejectionsRequired = 3;

      test('approval threshold requires a multi-veteran panel', () {
        expect(approvalsRequired, greaterThanOrEqualTo(3));
      });

      test('rejection threshold matches approval threshold (symmetric jury)',
          () {
        expect(rejectionsRequired, approvalsRequired);
      });

      test('bounty meaningfully outweighs a routine post reward (100 xp)', () {
        expect(bountyPoints, greaterThan(100));
      });
    });
  });
}
