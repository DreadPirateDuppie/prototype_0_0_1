import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/battle_detail_provider.dart';
import '../../config/theme_config.dart';
import 'player_stats_column.dart';

class BattlePlayerVsSection extends StatelessWidget {
  const BattlePlayerVsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        final battle = provider.battle;
        if (battle == null) return const SizedBox.shrink();

        final myLetters = provider.isPlayer1
            ? battle.player1Letters
            : battle.player2Letters;
        final opponentLetters = provider.isPlayer1
            ? battle.player2Letters
            : battle.player1Letters;
        final targetLetters = battle.getGameLetters();

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ThemeColors.matrixGreen.withValues(alpha: 0.08),
                      ThemeColors.matrixGreen.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: PlayerStatsColumn(
                  title: 'YOU',
                  letters: myLetters,
                  targetLetters: targetLetters,
                  highlight: true,
                  primaryTextColor: ThemeColors.matrixGreen,
                  secondaryTextColor: ThemeColors.textSecondary,
                  progressBackgroundColor: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  progressValueColor: ThemeColors.matrixGreen,
                  name: provider.isPlayer1 ? provider.player1Name : provider.player2Name,
                  avatarUrl: provider.isPlayer1 ? provider.player1Avatar : provider.player2Avatar,
                  analytics: provider.isPlayer1 ? provider.player1Analytics : provider.player2Analytics,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    'VS',
                    style: AppTextStyles.heading3.copyWith(
                      color: ThemeColors.textSecondary.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withValues(alpha: 0.08),
                      Colors.red.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: PlayerStatsColumn(
                  title: 'OPP',
                  letters: opponentLetters,
                  targetLetters: targetLetters,
                  highlight: false,
                  primaryTextColor: Colors.red.withValues(alpha: 0.8),
                  secondaryTextColor: ThemeColors.textSecondary,
                  progressBackgroundColor: Colors.red.withValues(alpha: 0.1),
                  progressValueColor: Colors.red.withValues(alpha: 0.7),
                  name: provider.isPlayer1 ? provider.player2Name : provider.player1Name,
                  avatarUrl: provider.isPlayer1 ? provider.player2Avatar : provider.player1Avatar,
                  analytics: provider.isPlayer1 ? provider.player2Analytics : provider.player1Analytics,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
