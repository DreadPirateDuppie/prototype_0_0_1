import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/spot_status.dart';

void main() {
  group('SpotStatusType', () {
    test('wireValue round-trips through fromWire', () {
      for (final type in SpotStatusType.values) {
        expect(SpotStatusType.fromWire(type.wireValue), type);
      }
    });

    test('fromWire defaults unknown/null values to clear', () {
      expect(SpotStatusType.fromWire(null), SpotStatusType.clear);
      expect(SpotStatusType.fromWire('NOT_A_STATUS'), SpotStatusType.clear);
    });

    test('only SECURITY_ACTIVE and LOCKED_OFF are tactical alerts', () {
      expect(SpotStatusType.securityActive.isTacticalAlert, isTrue);
      expect(SpotStatusType.lockedOff.isTacticalAlert, isTrue);
      expect(SpotStatusType.wet.isTacticalAlert, isFalse);
      expect(SpotStatusType.sessionAlive.isTacticalAlert, isFalse);
      expect(SpotStatusType.clear.isTacticalAlert, isFalse);
    });
  });

  group('SpotStatus', () {
    test('clearFor produces an implicit CLEAR status with no timestamps', () {
      final status = SpotStatus.clearFor('spot-1');
      expect(status.spotId, 'spot-1');
      expect(status.isClear, isTrue);
      expect(status.reportedAt, isNull);
      expect(status.expiresAt, isNull);
    });

    test('fromMap parses a spot_current_status row', () {
      final status = SpotStatus.fromMap({
        'spot_id': 'spot-1',
        'status_type': 'SECURITY_ACTIVE',
        'reported_by': 'user-1',
        'reported_at': '2026-07-07T12:00:00.000Z',
        'expires_at': '2026-07-07T16:00:00.000Z',
      });

      expect(status.spotId, 'spot-1');
      expect(status.statusType, SpotStatusType.securityActive);
      expect(status.isClear, isFalse);
      expect(status.reportedBy, 'user-1');
      expect(status.reportedAt, DateTime.parse('2026-07-07T12:00:00.000Z'));
      expect(status.expiresAt, DateTime.parse('2026-07-07T16:00:00.000Z'));
    });
  });
}
