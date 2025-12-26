import 'package:flutter/material.dart';
import '../models/battle.dart';
import '../utils/duration_utils.dart';
import '../config/theme_config.dart';

/// A reusable battle header widget showing players, scores, and turn info
class BattleHeader extends StatelessWidget {
  final Battle battle;
  final bool isPlayer1;
  final bool isMyTurn;
  final String? player1Name;
  final String? player2Name;
  final VoidCallback? onPlayerTap;
  
  static const Color matrixGreen = Color(0xFF00FF41);

  const BattleHeader({
    super.key,
    required this.battle,
    required this.isPlayer1,
    required this.isMyTurn,
    this.player1Name,
    this.player2Name,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ThemeColors.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: matrixGreen.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPlayersRow(context),
          const SizedBox(height: 24),
          _buildLettersRow(context),
          const SizedBox(height: 20),
          _buildTurnIndicator(context),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildPlayerInfo(
            context,
            player1Name ?? 'PLAYER 1',
            isPlayer1,
            battle.currentTurnPlayerId == battle.player1Id,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: matrixGreen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(
              color: matrixGreen.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            'VS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: matrixGreen.withValues(alpha: 0.8),
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: _buildPlayerInfo(
            context,
            player2Name ?? 'PLAYER 2',
            !isPlayer1,
            battle.currentTurnPlayerId == battle.player2Id,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerInfo(
    BuildContext context,
    String name,
    bool isCurrentUser,
    bool isCurrentTurn,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentTurn ? matrixGreen : Colors.grey.withValues(alpha: 0.15),
                  width: isCurrentTurn ? 1.5 : 1,
                ),
                boxShadow: isCurrentTurn
                    ? [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: ThemeColors.surfaceDark,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: isCurrentUser 
                      ? matrixGreen.withValues(alpha: 0.05) 
                      : Colors.grey.withValues(alpha: 0.05),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isCurrentUser ? matrixGreen : Colors.grey.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            if (isCurrentUser)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: matrixGreen,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xs),
                    boxShadow: [
                      BoxShadow(
                        color: matrixGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isCurrentUser ? matrixGreen : ThemeColors.textSecondary.withValues(alpha: 0.6),
            fontFamily: 'monospace',
            letterSpacing: 1.5,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLettersRow(BuildContext context) {
    final gameLetters = battle.getGameLetters();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLetterDisplay(battle.player1Letters, gameLetters, true),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 12,
          width: 1,
          color: ThemeColors.textSecondary.withValues(alpha: 0.1),
        ),
        _buildLetterDisplay(battle.player2Letters, gameLetters, false),
      ],
    );
  }

  Widget _buildLetterDisplay(String earnedLetters, String gameLetters, bool isLeft) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(gameLetters.length, (index) {
        final hasLetter = index < earnedLetters.length;
        final letter = gameLetters[index];
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: hasLetter 
                ? Colors.red.withValues(alpha: 0.1) 
                : ThemeColors.surfaceDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(
              color: hasLetter ? Colors.red.withValues(alpha: 0.6) : matrixGreen.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: hasLetter ? [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ] : null,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: hasLetter ? Colors.red : matrixGreen.withValues(alpha: 0.1),
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTurnIndicator(BuildContext context) {
    final remainingTime = battle.getRemainingTime();
    final timeText = remainingTime != null 
        ? DurationUtils.formatShort(remainingTime) 
        : 'NO DEADLINE';
    
    final Color turnColor = isMyTurn ? matrixGreen : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: turnColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(
          color: turnColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: turnColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: turnColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            (isMyTurn ? 'YOUR TURN' : 'OPPONENT\'S TURN').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: turnColor,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 12,
            width: 1,
            color: turnColor.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: turnColor.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            timeText.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: turnColor.withValues(alpha: 0.8),
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget displaying game mode and bet information
class BattleInfoBadges extends StatelessWidget {
  final Battle battle;
  
  static const Color matrixGreen = Color(0xFF00FF41);

  const BattleInfoBadges({
    super.key,
    required this.battle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildBadge(
          icon: Icons.sports_esports,
          label: battle.gameMode.toString().split('.').last.toUpperCase(),
          color: matrixGreen,
        ),
        if (battle.isQuickfire)
          _buildBadge(
            icon: Icons.flash_on,
            label: 'QUICKFIRE',
            color: Colors.orange,
          ),
        if (battle.betAmount > 0)
          _buildBadge(
            icon: Icons.monetization_on,
            label: '${battle.betAmount} PTS',
            color: Colors.amber,
          ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
