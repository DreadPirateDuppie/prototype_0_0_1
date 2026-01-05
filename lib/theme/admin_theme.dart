import 'package:flutter/material.dart';

class AdminTheme {
  static const primary = Color(0xFF0A0A0B);
  static const secondary = Color(0xFF141416);
  static const surface = Color(0xFF1C1C1E);
  static const accent = Color(0xFF00FF9D); // Matrix Green
  static const error = Color(0xFFFF4D4D);
  static const warning = Color(0xFFFFB347);
  static const success = Color(0xFF00FF9D);
  
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFEBEBF5);
  static const textMuted = Color(0xFF8E8E93);

  static BoxDecoration glassDecoration({Color? color, double opacity = 0.3}) {
    return BoxDecoration(
      color: (color ?? surface).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
