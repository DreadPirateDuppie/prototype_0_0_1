import 'package:flutter/material.dart';
import '../models/battle.dart';
import '../utils/duration_utils.dart';

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            matrixGreen.withValues(alpha: 0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: matrixGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildPlayersRow(context),
          const SizedBox(height: 16),
          _buildLettersRow(context),
          const SizedBox(height: 12),
          _buildTurnIndicator(context),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPlayerInfo(
          context,
          player1Name ?? 'Player 1',
          isPlayer1,
          battle.currentTurnPlayerId == battle.player1Id,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: matrixGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: matrixGreen, width: 1),
          ),
          child: Text(
            'VS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: matrixGreen,
              fontFamily: 'monospace',
            ),
          ),
        ),
        _buildPlayerInfo(
          context,
          player2Name ?? 'Player 2',
          !isPlayer1,
          battle.currentTurnPlayerId == battle.player2Id,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentTurn ? matrixGreen : Colors.grey,
                  width: isCurrentTurn ? 3 : 1,
                ),
                boxShadow: isCurrentTurn
                    ? [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: isCurrentUser 
                    ? matrixGreen.withValues(alpha: 0.2) 
                    : Colors.grey.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser ? matrixGreen : Colors.grey,
                  ),
                ),
              ),
            ),
            if (isCurrentUser)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: matrixGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCurrentUser ? matrixGreen : Colors.grey,
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
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
        const SizedBox(width: 24),
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
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasLetter 
                ? Colors.red.withValues(alpha: 0.8) 
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: hasLetter ? Colors.red : Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: hasLetter ? Colors.white : Colors.grey,
              fontFamily: 'monospace',
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
        : 'No deadline';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isMyTurn 
            ? matrixGreen.withValues(alpha: 0.2) 
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyTurn ? matrixGreen : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMyTurn ? Icons.play_arrow : Icons.hourglass_empty,
            size: 16,
            color: isMyTurn ? matrixGreen : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            isMyTurn ? 'Your Turn' : 'Waiting for opponent',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMyTurn ? matrixGreen : Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 12,
                  color: matrixGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: matrixGreen,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
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
