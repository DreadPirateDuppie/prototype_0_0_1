import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_scores.dart';

/// A reusable widget for displaying user stats with expandable details
class UserStatsCard extends StatefulWidget {
  final UserScores scores;
  final bool initiallyExpanded;
  final VoidCallback? onInfoPressed;

  const UserStatsCard({
    super.key,
    required this.scores,
    this.initiallyExpanded = true,
    this.onInfoPressed,
  });

  @override
  State<UserStatsCard> createState() => _UserStatsCardState();
}

class _UserStatsCardState extends State<UserStatsCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    final scores = widget.scores;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: _isExpanded ? 16 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: matrixGreen.withValues(alpha: 0.2),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  matrixGreen.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildExpandedContent(scores),
                  crossFadeState: _isExpanded 
                      ? CrossFadeState.showSecond 
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const matrixGreen = Color(0xFF00FF41);
    
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: matrixGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: matrixGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'STATS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: matrixGreen,
                fontFamily: 'monospace',
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 4),
            if (widget.onInfoPressed != null)
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: matrixGreen.withValues(alpha: 0.5),
                ),
                onPressed: widget.onInfoPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Learn about stats',
              ),
            const Spacer(),
            Icon(
              _isExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              color: matrixGreen.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(UserScores scores) {
    return Column(
      children: [
        const SizedBox(height: 20),
        ScoreProgressBar(
          label: 'SPOTTER',
          score: scores.mapScore,
          color: const Color(0xFF00FF41),
          subtitle: 'Map contributions & upvotes',
          isXP: true,
          level: scores.mapLevel,
          levelProgress: scores.mapLevelProgress,
          xpForNextLevel: scores.mapXPForNextLevel,
        ),
        const SizedBox(height: 16),
        ScoreProgressBar(
          label: 'VERSUS',
          score: scores.playerScore,
          color: const Color(0xFF00E5FF),
          subtitle: 'Battle performance & wins',
          isXP: true,
          level: scores.playerLevel,
          levelProgress: scores.playerLevelProgress,
          xpForNextLevel: scores.playerXPForNextLevel,
        ),
        const SizedBox(height: 16),
        ScoreProgressBar(
          label: 'RANKING',
          score: scores.rankingScore,
          color: const Color(0xFFFFB300),
          subtitle: 'Voting accuracy & community trust',
        ),
        const SizedBox(height: 24),
        _buildFinalScoreRow(scores),
      ],
    );
  }

  Widget _buildFinalScoreRow(UserScores scores) {
    const matrixGreen = Color(0xFF00FF41);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OVERALL SCORE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      scores.finalScore.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: matrixGreen,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ 1000',
                      style: TextStyle(
                        fontSize: 12,
                        color: matrixGreen.withValues(alpha: 0.3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOTE WEIGHT',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(scores.voteWeight * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFB300),
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

/// A reusable score progress bar widget
class ScoreProgressBar extends StatelessWidget {
  final String label;
  final double score;
  final Color color;
  final String? subtitle;
  final bool isXP;
  final int? level;
  final double? levelProgress;
  final double? xpForNextLevel;

  const ScoreProgressBar({
    super.key,
    required this.label,
    required this.score,
    required this.color,
    this.subtitle,
    this.isXP = false,
    this.level,
    this.levelProgress,
    this.xpForNextLevel,
  });

  @override
  Widget build(BuildContext context) {
    final double progress;
    final String displayValue;
    String? progressSubtitle;
    
    if (isXP && level != null && levelProgress != null && xpForNextLevel != null) {
      progress = levelProgress!;
      displayValue = 'LVL $level';
      final xpNeeded = (xpForNextLevel! - score).toStringAsFixed(0);
      progressSubtitle = '$xpNeeded XP TO NEXT';
    } else {
      progress = score / 1000.0;
      displayValue = score.toStringAsFixed(0);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
                if (progressSubtitle != null) ...[
                  Text(
                    progressSubtitle,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              height: 4,
              width: (MediaQuery.of(context).size.width - 64) * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
