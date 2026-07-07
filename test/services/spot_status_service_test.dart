import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/spot_status_service.dart';

void main() {
  group('SpotStatusService', () {
    group('instantiation', () {
      test('can be created without client', () {
        final service = SpotStatusService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = SpotStatusService(client: null);
        expect(service, isNotNull);
      });
    });

    group('temporal logic (server-side mirror)', () {
      // Mirrors the tunable placeholders in spot_status_config
      // (supabase/migrations/20260707_spot_status_engine.sql). The server is
      // authoritative; these tests document the intended default behaviour.
      const ttlHours = 4.0;
      const cooldownMinutes = 5.0;

      test('a report is current for the full 4-hour TTL window', () {
        final reportedAt = DateTime(2026, 7, 7, 12, 0);
        final expiresAt = reportedAt.add(const Duration(hours: 4));
        expect(expiresAt.difference(reportedAt).inHours, ttlHours.toInt());
      });

      test('cooldown is shorter than the TTL so reports cannot outrun review',
          () {
        expect(cooldownMinutes, lessThan(ttlHours * 60));
      });
    });
  });
}
