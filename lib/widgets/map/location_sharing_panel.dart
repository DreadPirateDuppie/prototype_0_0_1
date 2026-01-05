import 'package:flutter/material.dart';

class LocationSharingPanel extends StatelessWidget {
  final bool isSharingLocation;
  final Function(bool) onToggleSharing;
  final VoidCallback onOpenSettings;

  const LocationSharingPanel({
    super.key,
    required this.isSharingLocation,
    required this.onToggleSharing,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSharingLocation ? Icons.visibility : Icons.visibility_off,
          size: 16,
          color: isSharingLocation ? const Color(0xFF00FF41) : Colors.grey.shade500,
        ),
        const SizedBox(width: 8),
        Text(
          isSharingLocation ? 'Visible' : 'Hidden',
          style: TextStyle(
            color: isSharingLocation ? const Color(0xFF00FF41) : Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 20,
          width: 36,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              value: isSharingLocation,
              onChanged: onToggleSharing,
              activeThumbColor: const Color(0xFF00FF41),
              activeTrackColor: const Color(0xFF00FF41).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey.shade600,
              inactiveTrackColor: Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onOpenSettings,
          child: Icon(
            Icons.settings_outlined,
            size: 16,
            color: const Color(0xFF00FF41).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
