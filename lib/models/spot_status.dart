/// The four user-reported "Live Intelligence" payloads (Status Engine /
/// "Eyes on the Street"), plus the implicit CLEAR state a spot reverts to
/// once its most recent report has expired past the 4-hour TTL.
enum SpotStatusType {
  securityActive,
  wet,
  lockedOff,
  sessionAlive,
  clear;

  /// The exact wire string used by `report_spot_status` / `spot_current_status`.
  String get wireValue {
    switch (this) {
      case SpotStatusType.securityActive:
        return 'SECURITY_ACTIVE';
      case SpotStatusType.wet:
        return 'WET';
      case SpotStatusType.lockedOff:
        return 'LOCKED_OFF';
      case SpotStatusType.sessionAlive:
        return 'SESSION_ALIVE';
      case SpotStatusType.clear:
        return 'CLEAR';
    }
  }

  static SpotStatusType fromWire(String? value) {
    switch (value) {
      case 'SECURITY_ACTIVE':
        return SpotStatusType.securityActive;
      case 'WET':
        return SpotStatusType.wet;
      case 'LOCKED_OFF':
        return SpotStatusType.lockedOff;
      case 'SESSION_ALIVE':
        return SpotStatusType.sessionAlive;
      default:
        return SpotStatusType.clear;
    }
  }

  /// Short label for Quick-Report chips / status banners.
  String get label {
    switch (this) {
      case SpotStatusType.securityActive:
        return 'Security Active';
      case SpotStatusType.wet:
        return 'Wet';
      case SpotStatusType.lockedOff:
        return 'Locked Off';
      case SpotStatusType.sessionAlive:
        return 'Session Alive';
      case SpotStatusType.clear:
        return 'Clear';
    }
  }

  /// Only these two payloads trigger the haptic + "Heads Up" notification
  /// pipeline (spec section "Live Intelligence API").
  bool get isTacticalAlert =>
      this == SpotStatusType.securityActive || this == SpotStatusType.lockedOff;
}

/// Live state of one spot's user-reported condition, as returned by the
/// `spot_current_status` Supabase view. A spot with no current row is
/// implicitly [SpotStatusType.clear] — see [SpotStatus.clearFor].
class SpotStatus {
  final String spotId;
  final SpotStatusType statusType;
  final String? reportedBy;
  final DateTime? reportedAt;
  final DateTime? expiresAt;

  const SpotStatus({
    required this.spotId,
    required this.statusType,
    this.reportedBy,
    this.reportedAt,
    this.expiresAt,
  });

  factory SpotStatus.clearFor(String spotId) => SpotStatus(
        spotId: spotId,
        statusType: SpotStatusType.clear,
      );

  bool get isClear => statusType == SpotStatusType.clear;

  factory SpotStatus.fromMap(Map<String, dynamic> map) {
    return SpotStatus(
      spotId: map['spot_id'] as String,
      statusType: SpotStatusType.fromWire(map['status_type'] as String?),
      reportedBy: map['reported_by'] as String?,
      reportedAt: map['reported_at'] != null
          ? DateTime.tryParse(map['reported_at'].toString())
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
    );
  }
}
