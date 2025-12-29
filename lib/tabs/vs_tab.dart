import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/battle.dart';
import '../providers/battle_provider.dart';
import '../screens/battle_leaderboard_screen.dart';
import '../screens/battle_detail_screen.dart';

import '../screens/battle_mode_selection_screen.dart';
import '../services/supabase_service.dart';
import '../config/theme_config.dart';
import '../widgets/leaderboard_card.dart';
import 'dart:async';

class VsTab extends StatefulWidget {
  const VsTab({super.key});

  @override
  State<VsTab> createState() => _VsTabState();
}

class _VsTabState extends State<VsTab> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoadingLeaderboard = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBattles();
    _loadLeaderboard();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check for expired battles
        final provider = context.read<BattleProvider>();
        final battles = provider.activeBattles;
        bool shouldRefresh = false;
        
        for (final battle in battles) {
          final remaining = battle.getRemainingTime();
          if (remaining != null && remaining.inSeconds <= 0) {
             shouldRefresh = true;
             break;
          }
        }

        if (shouldRefresh && !provider.isLoading) {
           _loadBattles();
        }

        setState(() {
          // Just trigger rebuild to update countdowns
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBattles() async {
    if (_currentUser == null) return;
    final provider = context.read<BattleProvider>();
    await provider.loadBattles(_currentUser.id);
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() => _isLoadingLeaderboard = true);
      final leaderboard = await SupabaseService.getTopBattlePlayers(limit: 10);
      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLeaderboard = false);
      }
    }
  }

  String _getGameModeDisplay(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return 'SKATE';
      case GameMode.sk8:
        return 'SK8';
      case GameMode.custom:
        return 'Custom';
    }
  }

  Color _getGameModeColor(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return const Color(0xFF00FF41);
      case GameMode.sk8:
        return const Color(0xFFFF6B35);
      case GameMode.custom:
        return const Color(0xFF7B68EE);
    }
  }

  Widget _buildBattleCard(Battle battle) {
    final isPlayer1 = battle.player1Id == _currentUser?.id;
    final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
    final opponentLetters = isPlayer1
        ? battle.player2Letters
        : battle.player1Letters;
    final isMyTurn = battle.currentTurnPlayerId == _currentUser?.id;
    final isCompleted = battle.status == BattleStatus.completed;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          if (isMyTurn)
            BoxShadow(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: -2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BattleDetailScreen(
                    battleId: battle.id!,
                  ),
                ),
              );
              if (result != null || mounted) {
                _loadBattles();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: ThemeColors.surfaceDark.withValues(alpha: 0.9),
                border: Border.all(
                  color: isMyTurn 
                      ? ThemeColors.matrixGreen.withValues(alpha: 0.3) 
                      : ThemeColors.matrixGreen.withValues(alpha: 0.08),
                  width: 0.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ThemeColors.surfaceDark,
                    ThemeColors.backgroundDark.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header with game mode and status
                  Row(
                    children: [
                      _buildGameModeChip(battle.gameMode),
                      const Spacer(),
                      _buildStatusIndicators(battle, isMyTurn, isCompleted),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Player comparison
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlayerSection(
                          'YOU',
                          myLetters,
                          true,
                          battle.getGameLetters(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          children: [
                            Text(
                              'VS',
                              style: TextStyle(
                                color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 30,
                              width: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    ThemeColors.matrixGreen.withValues(alpha: 0.2),
                                    ThemeColors.matrixGreen.withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildPlayerSection(
                          'OPPONENT',
                          opponentLetters,
                          false,
                          battle.getGameLetters(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Bottom action bar
                  _buildActionBar(isMyTurn, isCompleted, battle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeChip(GameMode mode) {
    final color = _getGameModeColor(mode);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getGameModeIcon(mode),
            color: color.withValues(alpha: 0.8),
            size: 12,
          ),
          const SizedBox(width: 8),
          Text(
            _getGameModeDisplay(mode),
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

  IconData _getGameModeIcon(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return Icons.sports_kabaddi_outlined;
      case GameMode.sk8:
        return Icons.sports_esports_outlined;
      case GameMode.custom:
        return Icons.tune_outlined;
    }
  }

  Widget _buildStatusIndicators(Battle battle, bool isMyTurn, bool isCompleted) {
    final widgets = <Widget>[];
    
    if (battle.betAmount > 0) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.stars_outlined,
                color: Color(0xFFFFD700),
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                '${battle.betAmount}',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (battle.turnDeadline != null && !isCompleted) {
      widgets.add(
        _buildTimerChip(battle),
      );
    }
    
    return Row(children: widgets);
  }

  Widget _buildTimerChip(Battle battle) {
    final remaining = battle.getRemainingTime();
    final color = _getTimerColor(remaining);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: color.withValues(alpha: 0.8),
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            _formatTimeRemaining(remaining).toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _getTimerColor(Duration? remaining) {
    if (remaining == null) return Colors.grey;
    if (remaining.inHours > 12) return ThemeColors.matrixGreen;
    if (remaining.inHours > 6) return Colors.orange;
    if (remaining.inMinutes > 30) return Colors.yellow;
    return Colors.red;
  }

  String _formatTimeRemaining(Duration? remaining) {
    if (remaining == null) return '--:--';
    if (remaining.inDays > 0) {
      return '${remaining.inDays}D ${remaining.inHours % 24}H ${remaining.inMinutes % 60}M';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}H ${remaining.inMinutes % 60}M ${remaining.inSeconds % 60}S';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}M ${remaining.inSeconds % 60}S';
    } else {
      return '${remaining.inSeconds}S';
    }
  }

  Widget _buildPlayerSection(String label, String letters, bool isCurrentUser, String maxLetters) {
    final textColor = isCurrentUser ? ThemeColors.matrixGreen : ThemeColors.textPrimary;
    
    return Column(
      crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: ThemeColors.textSecondary.withValues(alpha: 0.5),
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              letters.isEmpty ? '-' : letters.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontFamily: 'monospace',
                shadows: isCurrentUser ? [
                  Shadow(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ] : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/$maxLetters',
              style: TextStyle(
                color: ThemeColors.textSecondary.withValues(alpha: 0.3),
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBar(bool isMyTurn, bool isCompleted, Battle battle) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isCompleted) {
      statusColor = ThemeColors.battleCompleted;
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle_outline;
    } else if (battle.setterId == null) {
      // RPS Stage
      statusColor = ThemeColors.matrixGreen;
      statusText = 'RPS BATTLE';
      statusIcon = Icons.sports_kabaddi_outlined;
    } else if (isMyTurn) {
      statusColor = ThemeColors.matrixGreen;
      statusText = 'YOUR TURN';
      statusIcon = Icons.play_circle_outline;
    } else {
      statusColor = Colors.orange;
      statusText = "OPPONENT'S TURN";
      statusIcon = Icons.pause_circle_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            statusIcon,
            color: statusColor.withValues(alpha: 0.8),
            size: 14,
          ),
          const SizedBox(width: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (isMyTurn) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: statusColor.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark.withValues(alpha: 0.9),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              width: 0.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFD700).withValues(alpha: 0.03),
                ThemeColors.surfaceDark,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'TOP PLAYERS',
                    style: TextStyle(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  _buildViewAllButton(),
                ],
              ),
              const SizedBox(height: 24),
              
              // Leaderboard content
              _isLoadingLeaderboard
                  ? _buildLoadingState()
                  : _leaderboard.isEmpty
                      ? _buildEmptyState()
                      : _buildLeaderboardList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllButton() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BattleLeaderboardScreen(),
          ),
        );
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VIEW ALL',
            style: TextStyle(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: ThemeColors.matrixGreen.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_kabaddi_outlined,
            color: ThemeColors.textSecondary.withValues(alpha: 0.2),
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'NO BATTLES YET',
            style: TextStyle(
              color: ThemeColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leaderboard.length > 3 ? 3 : _leaderboard.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final player = _leaderboard[index];
        final rank = index + 1;
        final isCurrentUser = player['user_id'] == _currentUser?.id;
        
        return LeaderboardCard(
          player: player,
          rank: rank,
          isCurrentUser: isCurrentUser,
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<BattleProvider>(
      builder: (context, battleProvider, child) {
        final battles = battleProvider.activeBattles;
        final isLoading = battleProvider.isLoading;
        
        return Scaffold(
          backgroundColor: ThemeColors.backgroundDark,
          appBar: AppBar(
            title: Text(
              '> PUSHINN_',
              style: AppTextStyles.heading2.copyWith(
                color: ThemeColors.matrixGreen,
                letterSpacing: 2,
              ),
            ),
            centerTitle: true,
            backgroundColor: ThemeColors.backgroundDark,
            foregroundColor: ThemeColors.matrixGreen,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      ThemeColors.matrixGreen.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: ThemeColors.matrixGreen,
                    strokeWidth: 3,
                  ),
                )
              : RefreshIndicator(
                  color: ThemeColors.matrixGreen,
                  backgroundColor: ThemeColors.backgroundDark,
                  onRefresh: () async {
                    await Future.wait([
                      _loadBattles(),
                      _loadLeaderboard(),
                    ]);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: battles.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildLeaderboardSection();
                      }
                      
                      if (index <= battles.length) {
                        return _buildBattleCard(battles[index - 1]);
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BattleModeSelectionScreen(),
                              ),
                            );
                            if (result == true) {
                              _loadBattles();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('NEW GAME'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColors.matrixGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            textStyle: AppTextStyles.button.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
      },
    );
  }
}
