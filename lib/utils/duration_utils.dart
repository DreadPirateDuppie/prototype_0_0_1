/// Utility class for formatting durations
class DurationUtils {
  /// Format duration in short form (e.g., "2h 30m", "5m 10s", "45s")
  static String formatShort(Duration? duration) {
    if (duration == null) return 'N/A';
    if (duration == Duration.zero || duration.isNegative) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Format duration in long form (e.g., "2 hours 30 minutes", "5 minutes 10 seconds")
  static String formatLong(Duration? duration) {
    if (duration == null) return 'Not available';
    if (duration == Duration.zero || duration.isNegative) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final parts = <String>[];

    if (hours > 0) {
      parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    }
    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (seconds > 0 && hours == 0) {
      parts.add('$seconds ${seconds == 1 ? 'second' : 'seconds'}');
    }

    return parts.isEmpty ? '0 seconds' : parts.join(' ');
  }

  /// Format deadline as relative time (e.g., "in 2 hours", "in 5 minutes")
  static String formatRelative(DateTime? deadline) {
    if (deadline == null) return 'No deadline';

    final now = DateTime.now();
    if (now.isAfter(deadline)) return 'Expired';

    final remaining = deadline.difference(now);
    return 'in ${formatShort(remaining)}';
  }

  /// Format duration as countdown timer (e.g., "02:30:45" or "05:30")
  static String formatCountdown(Duration? duration) {
    if (duration == null) return '--:--';
    if (duration == Duration.zero || duration.isNegative) return '00:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
