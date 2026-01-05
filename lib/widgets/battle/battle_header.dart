import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/battle_detail_provider.dart';
import '../../models/battle.dart';
import '../../config/theme_config.dart';
import '../../screens/chat_screen.dart';

class BattleHeader extends StatelessWidget implements PreferredSizeWidget {
  const BattleHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        final battle = provider.battle;
        if (battle == null) return AppBar(title: const Text('Loading...'));

        return AppBar(
          title: Text(
            'VS',
            style: AppTextStyles.heading3.copyWith(
              color: ThemeColors.matrixGreen,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: ThemeColors.matrixGreen,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => _handleChat(context, provider),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(context, provider, value),
              icon: Icon(Icons.more_vert, color: ThemeColors.matrixGreen),
              color: ThemeColors.surfaceDark,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'forfeit_turn',
                  child: Row(
                    children: [
                      Icon(Icons.skip_next, color: Colors.orange.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Forfeit Turn',
                        style: AppTextStyles.body2.copyWith(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'forfeit',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.red.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Forfeit Match',
                        style: AppTextStyles.body2.copyWith(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ThemeColors.backgroundDark,
                  ThemeColors.backgroundDark.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    ThemeColors.matrixGreen.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleChat(BuildContext context, BattleDetailProvider provider) async {
    final conversationId = await provider.getOrCreateConversation();
    if (context.mounted && conversationId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversationId: conversationId),
        ),
      );
    }
  }

  void _handleMenuAction(BuildContext context, BattleDetailProvider provider, String action) async {
    if (action == 'forfeit') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Forfeit Match?'),
          content: const Text('Are you sure you want to forfeit? You will automatically lose this match.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Forfeit'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await provider.forfeitBattle();
        if (context.mounted) Navigator.pop(context);
      }
    } else if (action == 'forfeit_turn') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SKIP TRICK?'),
          content: const Text('Are you sure you want to skip this trick? You will receive a letter.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('SKIP'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await provider.forfeitTurn();
      }
    }
  }
}

class BattleInfoSection extends StatelessWidget {
  const BattleInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        final battle = provider.battle;
        if (battle == null) return const SizedBox.shrink();

        return Column(
          children: [
            if (battle.turnDeadline != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppBorderRadius.round),
                    border: Border.all(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TIME REMAINING: ${_formatDuration(battle.getRemainingTime())}',
                        style: AppTextStyles.caption.copyWith(
                          color: ThemeColors.matrixGreen,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'CURRENT TRICK',
                  style: AppTextStyles.caption.copyWith(
                    color: ThemeColors.textSecondary.withValues(alpha: 0.6),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  battle.trickName != null 
                      ? battle.trickName!.toUpperCase() 
                      : _currentTrickLabel(battle).toUpperCase(),
                  style: AppTextStyles.heading2.copyWith(
                    color: ThemeColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    color: ThemeColors.matrixGreen,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _buildInfoChip(
                    icon: Icons.sports_kabaddi,
                    label: _modeLabel(battle.gameMode).toUpperCase(),
                    color: ThemeColors.matrixGreen,
                  ),
                  _buildInfoChip(
                    icon: Icons.verified_user_outlined,
                    label: _verificationLabel(battle.verificationStatus).toUpperCase(),
                    color: battle.verificationStatus == VerificationStatus.pending 
                        ? Colors.red 
                        : ThemeColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    if (duration.inHours > 0) {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      return '${h}h ${m}m';
    }
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _currentTrickLabel(Battle battle) {
    if (battle.setTrickVideoUrl == null) {
      return 'Setting Trick';
    } else if (battle.attemptVideoUrl == null) {
      return 'Attempting Trick';
    } else {
      return 'Voting';
    }
  }

  String _modeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.skate: return 'S.K.A.T.E';
      case GameMode.sk8: return 'S.K.8';
      case GameMode.custom: return 'Custom';
    }
  }

  String _verificationLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending: return 'Pending';
      case VerificationStatus.quickFireVoting: return 'Voting';
      case VerificationStatus.communityVerification: return 'Community Review';
      case VerificationStatus.resolved: return 'Resolved';
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
