import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class PlayerStatsColumn extends StatelessWidget {
  final String title;
  final String letters;
  final String targetLetters;
  final bool highlight;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color progressBackgroundColor;
  final Color progressValueColor;
  final String? name;
  final String? avatarUrl;
  final Map<String, dynamic>? analytics;

  const PlayerStatsColumn({
    super.key,
    required this.title,
    required this.letters,
    required this.targetLetters,
    required this.highlight,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.progressBackgroundColor,
    required this.progressValueColor,
    this.name,
    this.avatarUrl,
    this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final wins = analytics?['wins'] ?? 0;
    final losses = analytics?['losses'] ?? 0;
    final favoriteTrick = analytics?['favoriteTrick'] ?? 'None';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryTextColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryTextColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: primaryTextColor.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(Icons.person, color: primaryTextColor.withValues(alpha: 0.5))
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          name?.toUpperCase() ?? 'UNKNOWN',
          style: AppTextStyles.caption.copyWith(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'W: $wins | L: $losses',
          style: AppTextStyles.caption.copyWith(
            color: secondaryTextColor,
            fontSize: 8,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'FAV: ${favoriteTrick.toUpperCase()}',
          style: AppTextStyles.caption.copyWith(
            color: secondaryTextColor.withValues(alpha: 0.7),
            fontSize: 7,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          letters.isEmpty ? '-' : letters.toUpperCase(),
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            fontFamily: 'monospace',
            shadows: highlight ? [
              Shadow(
                color: primaryTextColor.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ] : null,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: letters.length / targetLetters.length,
            backgroundColor: progressBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressValueColor),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}
