import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/battle.dart';
import '../../config/theme_config.dart';

class RpsSelectionGrid extends StatelessWidget {
  final Battle battle;
  final Function(String) onMoveSelected;
  final VoidCallback onForfeit;

  const RpsSelectionGrid({
    super.key,
    required this.battle,
    required this.onMoveSelected,
    required this.onForfeit,
  });

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final isPlayer1 = userId == battle.player1Id;
    final myMove = isPlayer1 ? battle.player1RpsMove : battle.player2RpsMove;
    final hasMoved = myMove != null;

    if (hasMoved) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: ThemeColors.matrixGreen,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'WAITING FOR OPPONENT',
                style: AppTextStyles.heading3.copyWith(
                  color: ThemeColors.matrixGreen,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'YOU CHOSE: ${myMove.toUpperCase()}',
                  style: AppTextStyles.body2.copyWith(
                    color: ThemeColors.matrixGreen,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_kabaddi_outlined,
              size: 48,
              color: ThemeColors.matrixGreen.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'ROCK PAPER SCISSORS',
            style: AppTextStyles.heading3.copyWith(
              color: ThemeColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'WINNER SETS THE FIRST TRICK',
            style: AppTextStyles.caption.copyWith(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton.icon(
            onPressed: onForfeit,
            icon: const Icon(Icons.flag_outlined, size: 14, color: Colors.red),
            label: Text(
              'FORFEIT MATCH',
              style: AppTextStyles.caption.copyWith(
                color: Colors.red.withValues(alpha: 0.7),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRpsButton(
                  'rock',
                  Icons.circle_outlined,
                  'ROCK',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildRpsButton(
                  'paper',
                  Icons.article_outlined,
                  'PAPER',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildRpsButton(
                  'scissors',
                  Icons.content_cut_outlined,
                  'SCISSORS',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRpsButton(String move, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeColors.backgroundDark,
              border: Border.all(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onMoveSelected(move),
                customBorder: const CircleBorder(),
                splashColor: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                highlightColor: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    icon,
                    size: 32,
                    color: ThemeColors.matrixGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: ThemeColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
