import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/battle.dart';
import '../providers/battle_provider.dart';
import '../screens/battle_detail_screen.dart';
import '../screens/battle_leaderboard_screen.dart';
import '../screens/create_battle_dialog.dart';
import '../screens/community_verification_screen.dart';
import '../screens/tutorial_battle_screen.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';

class VsTab extends StatefulWidget {
  const VsTab({super.key});

  @override
  State<VsTab> createState() => _VsTabState();
}

class _VsTabState extends State<VsTab> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoadingLeaderboard = true;

  // Matrix theme colors
  static const Color matrixGreen = Color(0xFF00FF41);

  @override
  void initState() {
    super.initState();
    _loadBattles();
    _loadLeaderboard();
  }

  Future<void> _loadBattles() async {
    if (_currentUser == null) return;

    // Use the BattleProvider to load battles
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

  Widget _buildBattleCard(Battle battle) {
    final isPlayer1 = battle.player1Id == _currentUser?.id;
    final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
    final opponentLetters = isPlayer1
        ? battle.player2Letters
        : battle.player1Letters;
    final isMyTurn = battle.currentTurnPlayerId == _currentUser?.id;
    
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    const matrixDark = Color(0xFF0A0A0A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BattleDetailScreen(battle: battle),
              ),
            );
            _loadBattles();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  matrixDark,
                  matrixBlack,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMyTurn ? matrixGreen : matrixGreen.withValues(alpha: 0.2),
                width: isMyTurn ? 2 : 1,
              ),
              boxShadow: [
                if (isMyTurn)
                  BoxShadow(
                    color: matrixGreen.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Game Mode Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            matrixGreen.withValues(alpha: 0.2),
                            matrixGreen.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: matrixGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _getGameModeDisplay(battle.gameMode),
                        style: const TextStyle(
                          color: matrixGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Status Badges
                    Row(
                      children: [
                        if (battle.betAmount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Color(0xFFFFD700),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${battle.betAmount}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (battle.turnDeadline != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTimerColor(battle).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getTimerColor(battle).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  battle.isQuickfire ? Icons.flash_on : Icons.timer_outlined,
                                  color: _getTimerColor(battle),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimeRemaining(battle.getRemainingTime()),
                                  style: TextStyle(
                                    color: _getTimerColor(battle),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Battle Progress
                Row(
                  children: [
                    // Your Score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOU',
                            style: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                myLetters,
                                style: const TextStyle(
                                  color: matrixGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' / ${battle.getGameLetters()}',
                                style: TextStyle(
                                  color: matrixGreen.withValues(alpha: 0.4),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // VS Divider
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: matrixGreen.withValues(alpha: 0.3),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    // Opponent Score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'OPPONENT',
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                opponentLetters,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' / ${battle.getGameLetters()}',
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Turn Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMyTurn
                          ? [
                              matrixGreen.withValues(alpha: 0.2),
                              matrixGreen.withValues(alpha: 0.1),
                            ]
                          : [
                              Colors.red.withValues(alpha: 0.2),
                              Colors.red.withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMyTurn 
                          ? matrixGreen.withValues(alpha: 0.4)
                          : Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isMyTurn ? matrixGreen : Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: (isMyTurn ? matrixGreen : Colors.red).withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isMyTurn ? 'YOUR TURN' : "OPPONENT'S TURN",
                        style: TextStyle(
                          color: isMyTurn ? matrixGreen : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (isMyTurn) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward,
                          color: matrixGreen,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    const matrixDark = Color(0xFF0A0A0A);
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with View All button
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: goldColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'TOP PLAYERS',
                style: TextStyle(
                  color: goldColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (_isLoadingLeaderboard)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: matrixGreen,
                    strokeWidth: 2,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BattleLeaderboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward,
                    size: 16,
                  ),
                  label: const Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: matrixGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Compact Leaderboard (Top 3 only)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  matrixDark,
                  matrixBlack,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: matrixGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: _isLoadingLeaderboard
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: matrixGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _leaderboard.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.sports_kabaddi,
                                color: matrixGreen.withValues(alpha: 0.3),
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No battles yet',
                                style: TextStyle(
                                  color: matrixGreen.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _leaderboard.length > 3 ? 3 : _leaderboard.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: matrixGreen.withValues(alpha: 0.1),
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final player = _leaderboard[index];
                          final rank = index + 1;
                          final isCurrentUser = player['user_id'] == _currentUser?.id;
                          
                          Color rankColor = matrixGreen;
                          if (rank == 1) rankColor = goldColor;
                          else if (rank == 2) rankColor = silverColor;
                          else if (rank == 3) rankColor = bronzeColor;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: isCurrentUser
                                ? BoxDecoration(
                                    color: matrixGreen.withValues(alpha: 0.1),
                                    border: Border(
                                      left: BorderSide(
                                        color: matrixGreen,
                                        width: 3,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              children: [
                                // Rank Badge
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        rankColor.withValues(alpha: 0.3),
                                        rankColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: rankColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: rankColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        color: rankColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Avatar
                                if (player['avatar_url'] != null)
                                  Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: matrixGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        player['avatar_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.person,
                                            color: matrixGreen.withValues(alpha: 0.5),
                                            size: 18,
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                // Username
                                Expanded(
                                  child: Text(
                                    player['username'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: isCurrentUser ? matrixGreen : Colors.white,
                                      fontSize: 13,
                                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Stats
                                Row(
                                  children: [
                                    Text(
                                      '${player['wins']}W',
                                      style: const TextStyle(
                                        color: matrixGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: matrixGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${player['win_percentage'].toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: matrixGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialBattleCard() {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    const matrixDark = Color(0xFF0A0A0A);
    const tutorialYellow = Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showTutorialBattle(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  matrixDark,
                  matrixBlack,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tutorialYellow.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tutorialYellow.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Tutorial Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tutorialYellow.withValues(alpha: 0.3),
                            tutorialYellow.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tutorialYellow.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Text(
                        'TUTORIAL',
                        style: TextStyle(
                          color: tutorialYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Learn icon
                    Icon(
                      Icons.school,
                      color: tutorialYellow,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Battle Progress
                Row(
                  children: [
                    // Your Score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOU',
                            style: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'SK',
                                style: TextStyle(
                                  color: matrixGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' / SKATE',
                                style: TextStyle(
                                  color: matrixGreen.withValues(alpha: 0.4),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // VS Divider
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: matrixGreen.withValues(alpha: 0.3),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    // Opponent Score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'OPPONENT',
                            style: TextStyle(
                              color: Colors.orange.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' / SKATE',
                                style: TextStyle(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Turn Indicator - Tutorial specific
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tutorialYellow.withValues(alpha: 0.25),
                        tutorialYellow.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tutorialYellow.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tutorialYellow,
                          boxShadow: [
                            BoxShadow(
                              color: tutorialYellow.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TAP TO LEARN',
                        style: TextStyle(
                          color: tutorialYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward,
                        color: tutorialYellow,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDisplay(String label, String letters, String total, bool isPlayer) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Column(
      crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$letters / $total',
          style: const TextStyle(
            color: matrixGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    
    return Consumer<BattleProvider>(
      builder: (context, battleProvider, child) {
        final battles = battleProvider.activeBattles;
        final isLoading = battleProvider.isLoading;
        
        // Show error if any
        if (battleProvider.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorHelper.showError(context, battleProvider.error ?? 'Unknown error');
            battleProvider.clearError();
          });
        }
        
        return Scaffold(
          backgroundColor: matrixBlack,
          appBar: AppBar(
            title: const Text(
              '> PUSHINN_',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
                letterSpacing: 2,
              ),
            ),
            centerTitle: true,
            backgroundColor: matrixBlack,
            foregroundColor: matrixGreen,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      matrixGreen.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.verified_user),
                tooltip: 'Community Verification',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CommunityVerificationScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              const AdBanner(),
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: matrixGreen,
                          strokeWidth: 3,
                        ),
                      )
                    : RefreshIndicator(
                        color: matrixGreen,
                        backgroundColor: matrixBlack,
                        onRefresh: () async {
                          await Future.wait([
                            _loadBattles(),
                            _loadLeaderboard(),
                          ]);
                        },
                        child: ListView.builder(
                          itemCount: battles.length + 2, // +1 for leaderboard, +1 for tutorial
                          itemBuilder: (context, index) {
                            // First item is the leaderboard
                            if (index == 0) {
                              return _buildLeaderboardSection();
                            }
                            // Second item is the tutorial battle
                            if (index == 1) {
                              return _buildTutorialBattleCard();
                            }
                            // Remaining items are real battles
                            return _buildBattleCard(battles[index - 2]);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Quick Match Button
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 32, right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: FloatingActionButton.extended(
                      heroTag: 'quick_match',
                      onPressed: _isQuickMatching ? null : _startQuickMatch,
                      backgroundColor: matrixBlack,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: const BorderSide(color: Colors.red, width: 3),
                      ),
                      label: _isQuickMatching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.red,
                              ),
                            )
                          : const Text(
                              'Quick Match',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                      icon: _isQuickMatching
                          ? null
                          : const Icon(
                              Icons.flash_on,
                              size: 24,
                            ),
                    ),
                  ),
                ),
                
                // New Battle Button
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8, right: 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: FloatingActionButton.extended(
                      heroTag: 'new_battle',
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => const CreateBattleDialog(),
                        );
                        if (result == true) {
                          _loadBattles();
                        }
                      },
                      backgroundColor: matrixBlack,
                      foregroundColor: matrixGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: const BorderSide(color: matrixGreen, width: 3),
                      ),
                      label: const Text(
                        'New Battle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_circle,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  bool _isQuickMatching = false;

  Future<void> _startQuickMatch() async {
    setState(() {
      _isQuickMatching = true;
    });

    try {
      // Try to find a mutual follower first, then any opponent
      final opponentId = await SupabaseService.getRandomOpponent(mutualOnly: false);

      if (!mounted) return;

      if (opponentId == null) {
        ErrorHelper.showError(context, 'No opponents found. Try again later!');
        return;
      }

      // Open create battle dialog with pre-filled opponent
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => CreateBattleDialog(
          prefilledOpponentId: opponentId,
          isQuickMatch: true,
        ),
      );

      if (result == true) {
        _loadBattles();
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error finding match: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isQuickMatching = false;
        });
      }
    }
  }

  // Helper to get timer color based on remaining time
  Color _getTimerColor(Battle battle) {
    final remaining = battle.getRemainingTime();
    if (remaining == null) return matrixGreen;
    if (remaining.inHours >= 12) return matrixGreen;
    if (remaining.inHours >= 1) return Colors.orange;
    return Colors.redAccent;
  }

  // Helper to format remaining time as mm:ss or hh:mm
  String _formatTimeRemaining(Duration? duration) {
    if (duration == null) return '';
    if (duration.inHours > 0) {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      return '${h}h ${m}m';
    }
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
