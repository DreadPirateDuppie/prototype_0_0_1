class UserPoints {
  final String userId;
  final int points;
  final DateTime? lastSpinDate;

  UserPoints({
    required this.userId,
    required this.points,
    this.lastSpinDate,
  });

  factory UserPoints.fromMap(Map<String, dynamic> map) {
    return UserPoints(
      userId: map['user_id'] as String,
      points: map['points'] as int? ?? 0,
      lastSpinDate: map['last_spin_date'] != null
          ? DateTime.parse(map['last_spin_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'points': points,
      'last_spin_date': lastSpinDate?.toIso8601String(),
    };
  }

  bool canSpinToday() {
    if (lastSpinDate == null) return true;
    
    final now = DateTime.now();
    final lastSpin = lastSpinDate!;
    
    // Check if last spin was on a different day
    return now.year != lastSpin.year ||
        now.month != lastSpin.month ||
        now.day != lastSpin.day;
  }
}
