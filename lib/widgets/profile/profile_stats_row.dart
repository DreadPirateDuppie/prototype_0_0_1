import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileStatsRow extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final double points;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStatsRow({
    super.key,
    required this.followersCount,
    required this.followingCount,
    required this.points,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF00FF41);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Glassmorphism Container
          ClipRRect(
            borderRadius: BorderRadius.circular(2), // Sharper corners for HUD look
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(
                    color: neonGreen.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Followers', followersCount.toString(), onFollowersTap),
                    _buildDivider(),
                    _buildStatItem('Following', followingCount.toString(), onFollowingTap),
                    _buildDivider(),
                    _buildStatItem('Points', points.toStringAsFixed(0), null),
                  ],
                ),
              ),
            ),
          ),
          // Technical corner flourishes
          Positioned(
            top: 0,
            left: 0,
            child: _buildCorner(neonGreen),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: _buildCorner(neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color, width: 2),
          left: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, VoidCallback? onTap) {
    const neonGreen = Color(0xFF00FF41);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: neonGreen.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
