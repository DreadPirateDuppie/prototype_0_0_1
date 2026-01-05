import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class EmptyBattleState extends StatelessWidget {
  const EmptyBattleState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_kabaddi_outlined,
            color: ThemeColors.textSecondary.withValues(alpha: 0.2),
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'NO ACTIVE BATTLES',
            style: TextStyle(
              color: ThemeColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new battle or join the queue to play!',
            style: TextStyle(
              color: ThemeColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
