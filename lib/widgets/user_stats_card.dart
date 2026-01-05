import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_scores.dart';
import '../config/theme_config.dart';

class UserStatsCard extends StatefulWidget {
  final UserScores scores;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final bool initiallyExpanded;
  final bool showDetailedStats;
  final VoidCallback? onInfoPressed;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onPostsTap;

  const UserStatsCard({
    super.key,
    required this.scores,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.initiallyExpanded = false,
    this.showDetailedStats = true,
    this.onInfoPressed,
    this.onFollowersTap,
    this.onFollowingTap,
    this.onPostsTap,
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
    const matrixGreen = ThemeColors.matrixGreen;
    final scores = widget.scores;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildSocialStats(),
          if (widget.showDetailedStats) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: matrixGreen.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Corner Brackets
                      Positioned(top: 0, left: 0, child: _buildCorner(matrixGreen, true, true)),
                      Positioned(top: 0, right: 0, child: _buildCorner(matrixGreen, true, false)),
                      Positioned(bottom: 0, left: 0, child: _buildCorner(matrixGreen, false, true)),
                      Positioned(bottom: 0, right: 0, child: _buildCorner(matrixGreen, false, false)),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 12),
                            _buildMainStats(scores),
                            
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: _buildExpandedContent(scores),
                              crossFadeState: _isExpanded 
                                  ? CrossFadeState.showSecond 
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                            ),
                            
                            const SizedBox(height: 8),
                            _buildExpandToggle(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorner(Color color, bool isTop, bool isLeft) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: 2) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: 2) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '[USER_ANALYTICS]',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        if (widget.onInfoPressed != null)
          IconButton(
            icon: Icon(Icons.help_outline, color: ThemeColors.matrixGreen.withValues(alpha: 0.5), size: 14),
            onPressed: widget.onInfoPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildSocialStats() {
    return Row(
      children: [
        _buildSocialItem('POSTS', widget.postCount, widget.onPostsTap),
        const SizedBox(width: 8),
        _buildSocialItem('FOLLOWERS', widget.followersCount, widget.onFollowersTap),
        const SizedBox(width: 8),
        _buildSocialItem('FOLLOWING', widget.followingCount, widget.onFollowingTap),
      ],
    );
  }

  Widget _buildSocialItem(String label, int value, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontFamily: 'monospace',
                  fontSize: 7,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainStats(UserScores scores) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
        border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCoreStat('SCORE', scores.finalScore.toStringAsFixed(1), 'PTS'),
          _buildCoreStat('VOTE_W', '${(scores.voteWeight * 100).toStringAsFixed(0)}', '%'),
        ],
      ),
    );
  }

  Widget _buildCoreStat(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: ThemeColors.matrixGreen,
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                fontFamily: 'monospace',
                fontSize: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandToggle() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isExpanded ? 'CLOSE_DETAILS' : 'EXPAND_PROTOCOLS',
              style: TextStyle(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
                fontFamily: 'monospace',
                fontSize: 8,
                letterSpacing: 2,
              ),
            ),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
              size: 12,
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
        _buildProgressBar(
          'SPOTTER',
          scores.mapScore,
          Colors.blueAccent,
          'LVL ${scores.mapLevel}',
          scores.mapLevelProgress,
        ),
        const SizedBox(height: 12),
        _buildProgressBar(
          'VERSUS',
          scores.playerScore,
          Colors.redAccent,
          'LVL ${scores.playerLevel}',
          scores.playerLevelProgress,
        ),
        const SizedBox(height: 12),
        _buildProgressBar(
          'RANKING',
          scores.rankingScore,
          ThemeColors.matrixGreen,
          scores.rankingScore.toStringAsFixed(0),
          scores.rankingScore / 1000.0,
        ),
      ],
    );
  }

  Widget _buildProgressBar(String label, double score, Color color, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 2,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 2,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
