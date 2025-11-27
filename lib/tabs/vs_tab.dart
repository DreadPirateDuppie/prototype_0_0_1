import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/battle.dart';
import '../providers/battle_provider.dart';
import '../screens/battle_detail_screen.dart';
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

  // Matrix theme colors
  static const Color matrixGreen = Color(0xFF00FF41);

  @override
  void initState() {
    super.initState();
    _loadBattles();
  }

  Future<void> _loadBattles() async {
    if (_currentUser == null) return;

    // Use the BattleProvider to load battles
    final provider = context.read<BattleProvider>();
    await provider.loadBattles(_currentUser.id);
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
                              Text(
                                opponentLetters,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' / ${battle.getGameLetters()}',
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
                              Colors.orange.withValues(alpha: 0.2),
                              Colors.orange.withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMyTurn 
                          ? matrixGreen.withValues(alpha: 0.4)
                          : Colors.orange.withValues(alpha: 0.4),
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
                          color: isMyTurn ? matrixGreen : Colors.orange,
                          boxShadow: [
                            BoxShadow(
                              color: (isMyTurn ? matrixGreen : Colors.orange).withValues(alpha: 0.6),
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
                          color: isMyTurn ? matrixGreen : Colors.orange,
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
              'VS BATTLES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
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
                        onRefresh: _loadBattles,
                        child: ListView.builder(
                          itemCount: battles.length + 1, // +1 for tutorial
                          itemBuilder: (context, index) {
                            // First item is the tutorial battle
                            if (index == 0) {
                              return _buildTutorialBattleCard();
                            }
                            // Remaining items are real battles
                            return _buildBattleCard(battles[index - 1]);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Quick Match Button
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  heroTag: 'quick_match',
                  onPressed: _isQuickMatching ? null : _startQuickMatch,
                  backgroundColor: matrixBlack,
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.blue, width: 1),
                  ),
                  label: _isQuickMatching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : const Text('Quick Match'),
                  icon: _isQuickMatching ? null : const Icon(Icons.flash_on),
                ),
              ),
              
              // New Battle Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: matrixGreen.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
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
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: matrixGreen, width: 2),
                  ),
                  label: const Text('New Battle'),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
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
