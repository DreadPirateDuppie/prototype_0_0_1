import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/theme_config.dart';

class LeaderboardCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardCard({
    super.key,
    required this.player,
    required this.rank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.white;
    final glowColor = isCurrentUser ? ThemeColors.matrixGreen : rankColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowColor.withValues(alpha: isCurrentUser ? 0.5 : 0.2),
              width: 1,
            ),
            boxShadow: [
              if (isCurrentUser || rank <= 3)
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Row(
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rankColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    if (rank <= 3)
                      BoxShadow(
                        color: rankColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundImage: player['avatar_url'] != null
                      ? NetworkImage(player['avatar_url'])
                      : null,
                  backgroundColor: Colors.black,
                  radius: 19,
                  child: player['avatar_url'] == null
                      ? Text(
                          (player['username'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: glowColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              
              // Username & Score
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player['username'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 14,
                          color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(player['player_score'] as num?)?.toStringAsFixed(0) ?? '0'} PTS',
                          style: TextStyle(
                            color: ThemeColors.matrixGreen.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Win Rate or Status
              if (rank <= 3)
                Icon(
                  Icons.local_fire_department,
                  color: rankColor.withValues(alpha: 0.8),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
