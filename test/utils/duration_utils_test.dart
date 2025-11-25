import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/utils/duration_utils.dart';

void main() {
  group('DurationUtils', () {
    group('formatShort', () {
      test('returns N/A for null duration', () {
        expect(DurationUtils.formatShort(null), 'N/A');
      });

      test('returns Expired for zero duration', () {
        expect(DurationUtils.formatShort(Duration.zero), 'Expired');
      });

      test('returns Expired for negative duration', () {
        expect(DurationUtils.formatShort(const Duration(seconds: -10)), 'Expired');
      });

      test('formats hours and minutes correctly', () {
        expect(DurationUtils.formatShort(const Duration(hours: 2, minutes: 30)), '2h 30m');
        expect(DurationUtils.formatShort(const Duration(hours: 1, minutes: 5)), '1h 5m');
      });

      test('formats minutes and seconds correctly', () {
        expect(DurationUtils.formatShort(const Duration(minutes: 5, seconds: 30)), '5m 30s');
        expect(DurationUtils.formatShort(const Duration(minutes: 1, seconds: 0)), '1m 0s');
      });

      test('formats seconds only correctly', () {
        expect(DurationUtils.formatShort(const Duration(seconds: 45)), '45s');
        expect(DurationUtils.formatShort(const Duration(seconds: 1)), '1s');
      });
    });

    group('formatLong', () {
      test('returns Not available for null duration', () {
        expect(DurationUtils.formatLong(null), 'Not available');
      });

      test('returns Expired for zero duration', () {
        expect(DurationUtils.formatLong(Duration.zero), 'Expired');
      });

      test('returns Expired for negative duration', () {
        expect(DurationUtils.formatLong(const Duration(seconds: -10)), 'Expired');
      });

      test('formats singular hour correctly', () {
        expect(DurationUtils.formatLong(const Duration(hours: 1)), '1 hour');
      });

      test('formats plural hours correctly', () {
        expect(DurationUtils.formatLong(const Duration(hours: 2)), '2 hours');
      });

      test('formats singular minute correctly', () {
        expect(DurationUtils.formatLong(const Duration(minutes: 1)), '1 minute');
      });

      test('formats plural minutes correctly', () {
        expect(DurationUtils.formatLong(const Duration(minutes: 5)), '5 minutes');
      });

      test('formats hours and minutes together', () {
        expect(DurationUtils.formatLong(const Duration(hours: 2, minutes: 30)), '2 hours 30 minutes');
      });

      test('includes seconds when no hours', () {
        expect(DurationUtils.formatLong(const Duration(minutes: 5, seconds: 30)), '5 minutes 30 seconds');
      });

      test('excludes seconds when hours present', () {
        final result = DurationUtils.formatLong(const Duration(hours: 1, minutes: 30, seconds: 45));
        expect(result, '1 hour 30 minutes');
      });

      test('returns 0 seconds for empty duration parts', () {
        // This tests the edge case where duration might be non-zero but all parts are zero
        // In practice, Duration.zero is already handled, but this tests boundary
        final result = DurationUtils.formatLong(const Duration(milliseconds: 100));
        expect(result, '0 seconds'); // Less than 1 second rounds to 0
      });
    });

    group('formatRelative', () {
      test('returns No deadline for null deadline', () {
        expect(DurationUtils.formatRelative(null), 'No deadline');
      });

      test('returns Expired for past deadline', () {
        final pastDeadline = DateTime.now().subtract(const Duration(hours: 1));
        expect(DurationUtils.formatRelative(pastDeadline), 'Expired');
      });

      test('formats future deadline correctly', () {
        final futureDeadline = DateTime.now().add(const Duration(hours: 2, minutes: 30));
        final result = DurationUtils.formatRelative(futureDeadline);
        expect(result.startsWith('in '), true);
        expect(result.contains('h'), true);
      });
    });

    group('formatCountdown', () {
      test('returns --:-- for null duration', () {
        expect(DurationUtils.formatCountdown(null), '--:--');
      });

      test('returns 00:00 for zero duration', () {
        expect(DurationUtils.formatCountdown(Duration.zero), '00:00');
      });

      test('returns 00:00 for negative duration', () {
        expect(DurationUtils.formatCountdown(const Duration(seconds: -10)), '00:00');
      });

      test('formats minutes and seconds with padding', () {
        expect(DurationUtils.formatCountdown(const Duration(minutes: 5, seconds: 30)), '05:30');
        expect(DurationUtils.formatCountdown(const Duration(minutes: 1, seconds: 5)), '01:05');
      });

      test('formats with hours when present', () {
        expect(DurationUtils.formatCountdown(const Duration(hours: 1, minutes: 30, seconds: 45)), '01:30:45');
        expect(DurationUtils.formatCountdown(const Duration(hours: 12, minutes: 5, seconds: 3)), '12:05:03');
      });

      test('pads all components correctly', () {
        expect(DurationUtils.formatCountdown(const Duration(hours: 1, minutes: 1, seconds: 1)), '01:01:01');
      });
    });
  });
}
