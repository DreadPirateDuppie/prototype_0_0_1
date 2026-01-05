import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';

class AdminDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const AdminDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: AdminTheme.accent, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AdminTheme.textSecondary)),
      ],
    );
  }
}
