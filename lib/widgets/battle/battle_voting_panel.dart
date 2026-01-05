import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/battle.dart';
import '../../config/theme_config.dart';

class BattleVotingPanel extends StatelessWidget {
  final Battle battle;
  final Function(String) onVote;

  const BattleVotingPanel({
    super.key,
    required this.battle,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final isParticipant = battle.player1Id == userId || battle.player2Id == userId;
    if (!isParticipant) return const SizedBox.shrink();

    final isSetter = userId == battle.setterId;
    final myVote = isSetter ? battle.setterVote : battle.attempterVote;
    final hasVoted = myVote != null;

    if (hasVoted) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: ThemeColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: ThemeColors.matrixGreen,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'VOTE SUBMITTED',
              style: AppTextStyles.heading3.copyWith(
                color: ThemeColors.matrixGreen,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Waiting for opponent...',
              style: AppTextStyles.body1.copyWith(
                color: ThemeColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '> VOTE ON ATTEMPT_',
            style: AppTextStyles.heading2.copyWith(
              color: ThemeColors.matrixGreen,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onVote('missed'),
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('MISSED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    foregroundColor: Colors.red,
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onVote('landed'),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('LANDED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                    foregroundColor: ThemeColors.matrixGreen,
                    side: BorderSide(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
