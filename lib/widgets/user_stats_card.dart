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
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Color(0xFF001a00),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: matrixGreen,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: _buildExpandedContent(scores),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
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
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            color: matrixGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'STATS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: matrixGreen,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 4),
          if (widget.onInfoPressed != null)
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                size: 18,
                color: matrixGreen,
              ),
              onPressed: widget.onInfoPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Learn about stats',
            ),
          const Spacer(),
          Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: matrixGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(UserScores scores) {
    return Column(
      children: [
        const SizedBox(height: 16),
        ScoreProgressBar(
          label: 'Spotter Lvl',
          score: scores.mapScore,
          color: Colors.green.shade600,
          subtitle: 'XP from map contributions',
          isXP: true,
          level: scores.mapLevel,
          levelProgress: scores.mapLevelProgress,
          xpForNextLevel: scores.mapXPForNextLevel,
        ),
        const SizedBox(height: 12),
        ScoreProgressBar(
          label: 'VS Lvl',
          score: scores.playerScore,
          color: Colors.blue.shade600,
          subtitle: 'XP from battle performance',
          isXP: true,
          level: scores.playerLevel,
          levelProgress: scores.playerLevelProgress,
          xpForNextLevel: scores.playerXPForNextLevel,
        ),
        const SizedBox(height: 12),
        ScoreProgressBar(
          label: 'Ranking Score',
          score: scores.rankingScore,
          color: Colors.orange.shade300,
          subtitle: 'Voting accuracy (500-1000)',
        ),
        const SizedBox(height: 16),
        _buildFinalScoreRow(scores),
      ],
    );
  }

  Widget _buildFinalScoreRow(UserScores scores) {
    const matrixGreen = Color(0xFF00FF41);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7), // Adjusted for dark theme
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: matrixGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Final Score',
                style: TextStyle(
                  fontSize: 12,
                  color: matrixGreen.withValues(alpha: 0.8), // Adjusted color
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                scores.finalScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: matrixGreen,
                ),
              ),
            ],
          ),
          Container(
            height: 40,
            width: 1,
            color: matrixGreen.withValues(alpha: 0.3), // Adjusted color
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vote Weight',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(scores.voteWeight * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
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
      displayValue = 'Lvl $level • ${score.toStringAsFixed(0)} XP';
      final xpNeeded = (xpForNextLevel! - score).toStringAsFixed(0);
      progressSubtitle = '$xpNeeded XP to Lvl ${level! + 1}';
    } else {
      progress = score / 1000.0;
      displayValue = score.toStringAsFixed(0);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        if (progressSubtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            progressSubtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );
  }
}
