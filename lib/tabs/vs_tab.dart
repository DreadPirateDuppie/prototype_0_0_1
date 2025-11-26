import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/battle.dart';
import '../providers/battle_provider.dart';
import '../screens/battle_detail_screen.dart';
import '../screens/create_battle_dialog.dart';
import '../screens/community_verification_screen.dart';
import '../screens/tutorial_battle_screen.dart';
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
    const matrixSurface = Color(0xFF0D0D0D);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: matrixSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyTurn ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
          width: isMyTurn ? 2 : 1,
        ),
        boxShadow: [
          if (isMyTurn)
            BoxShadow(
              color: matrixGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 0,
            ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Status Indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: matrixBlack,
                    border: Border.all(
                      color: isMyTurn ? matrixGreen : matrixGreen.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      if (isMyTurn)
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  child: Icon(
                    isMyTurn ? Icons.play_arrow : Icons.pause,
                    color: isMyTurn ? matrixGreen : matrixGreen.withValues(alpha: 0.5),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Battle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game Mode
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: matrixGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: matrixGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _getGameModeDisplay(battle.gameMode),
                          style: const TextStyle(
                            color: matrixGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Scores
                      Row(
                        children: [
                          Expanded(
                            child: _buildScoreDisplay(
                              'YOU',
                              myLetters,
                              battle.getGameLetters(),
                              true,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  matrixGreen.withValues(alpha: 0.1),
                                  matrixGreen.withValues(alpha: 0.5),
                                  matrixGreen.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildScoreDisplay(
                              'OPP',
                              opponentLetters,
                              battle.getGameLetters(),
                              false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Turn Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMyTurn 
                              ? matrixGreen.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMyTurn ? matrixGreen : Colors.orange,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isMyTurn ? matrixGreen : Colors.orange).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMyTurn ? 'YOUR TURN' : "OPPONENT'S TURN",
                              style: TextStyle(
                                color: isMyTurn ? matrixGreen : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Bet and Timer Row
                      Row(
                        children: [
                          // Bet indicator
                          if (battle.betAmount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.monetization_on,
                                    color: Color(0xFFFFD700),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${battle.betAmount * 2} PTS',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Timer indicator
                          if (battle.turnDeadline != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getTimerColor(battle).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getTimerColor(battle),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    battle.isQuickfire ? Icons.flash_on : Icons.timer,
                                    color: _getTimerColor(battle),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatTimeRemaining(battle.getRemainingTime()),
                                    style: TextStyle(
                                      color: _getTimerColor(battle),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: matrixGreen.withValues(alpha: 0.5),
                  size: 20,
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
    const matrixSurface = Color(0xFF0D0D0D);
    const tutorialYellow = Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: matrixSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tutorialYellow.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: tutorialYellow.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showTutorialBattle(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Tutorial indicator icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: matrixBlack,
                    border: Border.all(
                      color: tutorialYellow,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tutorialYellow.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.school,
                    color: tutorialYellow,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Battle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tutorial badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tutorialYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tutorialYellow,
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
                      const SizedBox(height: 12),
                      // Scores
                      Row(
                        children: [
                          Expanded(
                            child: _buildScoreDisplay(
                              'YOU',
                              'SK',
                              'SKATE',
                              true,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  matrixGreen.withValues(alpha: 0.1),
                                  matrixGreen.withValues(alpha: 0.5),
                                  matrixGreen.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildScoreDisplay(
                              'OPP',
                              'S',
                              'SKATE',
                              false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Your turn indicator
                      Row(
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
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'YOUR TURN',
                            style: TextStyle(
                              color: tutorialYellow,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: tutorialYellow.withValues(alpha: 0.6),
                  size: 20,
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
          floatingActionButton: Container(
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
              label: const Text('New Battle'),
              icon: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
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
