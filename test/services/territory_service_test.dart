import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/territory_service.dart';

void main() {
  group('TerritoryService', () {
    group('instantiation', () {
      test('can be created without client', () {
        final service = TerritoryService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = TerritoryService(client: null);
        expect(service, isNotNull);
      });
    });

    group('capture mechanic constants (server-side mirrors)', () {
      // These mirror the tunable placeholders in territory_config
      // (supabase/migrations/20260706_territorial_capture.sql). The server is
      // authoritative; these tests document the intended default balance.
      const baseDefense = 100.0;
      const clipWeight = 10.0;
      const spotWeight = 25.0;

      test('a fresh borough needs 10 rival clips to become capturable', () {
        expect(baseDefense / clipWeight, 10);
      });

      test('a fresh borough needs 4 rival spot discoveries to flip', () {
        expect(baseDefense / spotWeight, 4);
      });

      test('spot discovery outweighs a clip upload', () {
        expect(spotWeight, greaterThan(clipWeight));
      });

      test('capture flips when destabilization reaches the threshold', () {
        const destabilization = clipWeight * 10;
        expect(destabilization >= baseDefense, isTrue);
      });
    });
  });
}
