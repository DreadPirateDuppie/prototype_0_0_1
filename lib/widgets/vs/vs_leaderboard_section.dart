import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../screens/battle_leaderboard_screen.dart';
import '../leaderboard_card.dart';

class VsLeaderboardSection extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final bool isLoading;
  final String? currentUserId;

  const VsLeaderboardSection({
    super.key,
    required this.leaderboard,
    this.isLoading = false,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark.withValues(alpha: 0.9),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              width: 0.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFD700).withValues(alpha: 0.03),
                ThemeColors.surfaceDark,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'TOP PLAYERS',
                    style: TextStyle(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  _buildViewAllButton(context),
                ],
              ),
              const SizedBox(height: 24),
              
              // Leaderboard content
              isLoading
                  ? _buildLoadingState()
                  : leaderboard.isEmpty
                      ? _buildEmptyState()
                      : _buildLeaderboardList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BattleLeaderboardScreen(),
          ),
        );
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VIEW ALL',
            style: TextStyle(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: ThemeColors.matrixGreen.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_kabaddi_outlined,
            color: ThemeColors.textSecondary.withValues(alpha: 0.2),
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'NO BATTLES YET',
            style: TextStyle(
              color: ThemeColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaderboard.length > 3 ? 3 : leaderboard.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final player = leaderboard[index];
        final rank = index + 1;
        final isCurrentUser = player['user_id'] == currentUserId;
        
        return LeaderboardCard(
          player: player,
          rank: rank,
          isCurrentUser: isCurrentUser,
        );
      },
    );
  }
}
