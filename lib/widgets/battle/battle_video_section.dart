import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/battle_detail_provider.dart';
import '../../config/theme_config.dart';
import '../video_player_widget.dart';

class BattleVideoSection extends StatelessWidget {
  const BattleVideoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        final battle = provider.battle;
        if (battle == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              child: battle.setTrickVideoUrl != null
                  ? VideoPlayerWidget(videoUrl: battle.setTrickVideoUrl!)
                  : Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ThemeColors.surfaceDark,
                            ThemeColors.backgroundDark,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 48,
                                color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'NO VIDEO YET',
                              style: AppTextStyles.caption.copyWith(
                                color: ThemeColors.textSecondary.withValues(alpha: 0.5),
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
