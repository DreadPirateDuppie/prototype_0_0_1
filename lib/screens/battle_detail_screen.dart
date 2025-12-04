import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/battle.dart';
import '../models/battle_trick.dart';
import '../services/battle_service.dart';
import '../utils/error_helper.dart';
import '../widgets/video_player_widget.dart';

class BattleDetailScreen extends StatefulWidget {
  final String? battleId;
  final Battle? battle;
  final bool tutorialMode;
  final String? tutorialUserId;

  const BattleDetailScreen({
    super.key, 
    this.battleId,
    this.battle,
    this.tutorialMode = false,
    this.tutorialUserId,
  });

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  late Battle _battle;
  bool _isLoading = true;
  bool _isTutorial = false;
  bool _isPlayer1 = false;
  bool _isMyTurn = false;

  // Matrix green color for consistent theming
  static const Color matrixGreen = Color(0xFF00FF41);

  @override
  void initState() {
    super.initState();
    _isTutorial = widget.tutorialMode;
    _loadBattle();
  }

  Future<void> _loadBattle() async {
    if (widget.battle != null) {
      _initBattle(widget.battle!);
      return;
    }

    if (widget.battleId == null) {
      if (mounted) {
        ErrorHelper.showError(context, 'Battle ID is required');
        Navigator.pop(context);
      }
      return;
    }

    try {
      final battle = await BattleService.getBattle(widget.battleId!);
      if (battle != null) {
        _initBattle(battle);
      } else {
        if (mounted) {
          ErrorHelper.showError(context, 'Battle not found');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error loading battle: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _initBattle(Battle battle) {
    if (mounted) {
      setState(() {
        _battle = battle;
        final userId = widget.tutorialMode 
            ? widget.tutorialUserId 
            : Supabase.instance.client.auth.currentUser?.id;
        _isPlayer1 = _battle.player1Id == userId;
        _isMyTurn = _battle.currentTurnPlayerId == userId;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadSetTrick() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    // Ask for trick name - Use StatefulBuilder for proper dialog state management
    String? trickName;
    if (mounted) {
      trickName = await showDialog<String>(
        context: context,
        builder: (context) => _TrickNameDialog(),
      );
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final videoUrl = await BattleService.uploadTrickVideo(
        File(video.path),
        _battle.id!,
        userId,
        'set',
      );

      final updatedBattle = await BattleService.uploadSetTrick(
        battleId: _battle.id!,
        videoUrl: videoUrl,
        trickName: trickName,
      );

      if (updatedBattle != null && mounted) {
        setState(() {
          _battle = updatedBattle;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          _isPlayer1 = _battle.player1Id == userId;
          _isMyTurn = _battle.currentTurnPlayerId == userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error uploading video: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadAttempt() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final videoUrl = await BattleService.uploadTrickVideo(
        File(video.path),
        _battle.id!,
        userId,
        'attempt',
      );

      final updatedBattle = await BattleService.uploadAttempt(
        battleId: _battle.id!,
        videoUrl: videoUrl,
      );

      if (updatedBattle != null && mounted) {
        setState(() {
          _battle = updatedBattle;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          _isPlayer1 = _battle.player1Id == userId;
          _isMyTurn = _battle.currentTurnPlayerId == userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error uploading attempt: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forfeitBattle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forfeit Match?'),
        content: const Text(
          'Are you sure you want to forfeit? You will automatically lose this match and points will be deducted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Forfeit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.forfeitBattle(
        battleId: _battle.id!,
        forfeitingUserId: userId,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match forfeited')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to forfeit: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _noop() {}

  String _modeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return 'S.K.A.T.E';
      case GameMode.sk8:
        return 'S.K.8';
      case GameMode.custom:
        return 'Custom';
    }
  }

  String _currentTrickLabel() {
    if (_battle.setTrickVideoUrl == null) {
      return 'Setting Trick';
    } else if (_battle.attemptVideoUrl == null) {
      return 'Attempting Trick';
    } else {
      return 'Voting';
    }
  }

  String _verificationLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'Pending';
      case VerificationStatus.quickFireVoting:
        return 'Voting';
      case VerificationStatus.communityVerification:
        return 'Community Review';
      case VerificationStatus.resolved:
        return 'Resolved';
    }
  }

  Widget _buildTutorialBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Welcome to Battle Mode! Follow the steps to play.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _isTutorial = false),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn({
    required String title,
    required String letters,
    required String targetLetters,
    required bool highlight,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color progressBackgroundColor,
    required Color progressValueColor,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          letters.isEmpty ? '-' : letters,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: letters.length / targetLetters.length,
          backgroundColor: progressBackgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(progressValueColor),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }

  Widget _buildActionButton({
    required String label,
    required String helper,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helper,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTutorialControls({
    required Color cardColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to Play',
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Set a trick by uploading a video.\n'
            '2. Opponent attempts the trick.\n'
            '3. Vote on the attempt.\n'
            '4. If they miss, they get a letter.',
            style: TextStyle(color: mutedTextColor, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingSection() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final isParticipant = _battle.player1Id == userId || _battle.player2Id == userId;
    if (!isParticipant) return const SizedBox.shrink();

    final isSetter = userId == _battle.setterId;
    final myVote = isSetter ? _battle.setterVote : _battle.attempterVote;
    final hasVoted = myVote != null;

    if (hasVoted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Vote Submitted',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for opponent...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: matrixGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Vote on Attempt',
            style: TextStyle(
              color: matrixGreen,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitVote('missed'),
                  icon: const Icon(Icons.close),
                  label: const Text('MISSED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitVote('landed'),
                  icon: const Icon(Icons.check),
                  label: const Text('LANDED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: matrixGreen.withValues(alpha: 0.2),
                    foregroundColor: matrixGreen,
                    side: const BorderSide(color: matrixGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitVote(String vote) async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.submitVote(
        battleId: _battle.id!,
        userId: userId,
        vote: vote,
      );
      
      final updatedBattle = await BattleService.getBattle(_battle.id!);
      if (updatedBattle != null && mounted) {
        setState(() {
          _battle = updatedBattle;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          _isPlayer1 = _battle.player1Id == userId;
          _isMyTurn = _battle.currentTurnPlayerId == userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to submit vote: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRpsMove(String move) async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.submitRpsMove(
        battleId: _battle.id!,
        userId: userId,
        move: move,
      );
      
      // Poll for update or just reload
      final updatedBattle = await BattleService.getBattle(_battle.id!);
      if (updatedBattle != null && mounted) {
        setState(() {
          _battle = updatedBattle;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          _isPlayer1 = _battle.player1Id == userId;
          _isMyTurn = _battle.currentTurnPlayerId == userId;
          _isLoading = false;
        });
        
        // If tie (moves reset), show snackbar
        if (_battle.setterId == null && 
            _battle.player1RpsMove == null && 
            _battle.player2RpsMove == null) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tie! Go again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to submit RPS move: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRpsSection() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final isPlayer1 = userId == _battle.player1Id;
    final myMove = isPlayer1 ? _battle.player1RpsMove : _battle.player2RpsMove;
    final hasMoved = myMove != null;

    if (hasMoved) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.timer, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Waiting for opponent...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You picked ${myMove.toUpperCase()}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: matrixGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Rock Paper Scissors',
            style: TextStyle(
              color: matrixGreen,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Winner sets the first trick!',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRpsButton('rock', Icons.landscape), // Rock icon proxy
              _buildRpsButton('paper', Icons.note),
              _buildRpsButton('scissors', Icons.content_cut),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRpsButton(String move, IconData icon) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _submitRpsMove(move),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            foregroundColor: matrixGreen,
            side: const BorderSide(color: matrixGreen),
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          move.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Ensure battle is loaded before accessing properties
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final myLetters = _isPlayer1
        ? _battle.player1Letters
        : _battle.player2Letters;
    final opponentLetters = _isPlayer1
        ? _battle.player2Letters
        : _battle.player1Letters;
    final targetLetters = _battle.getGameLetters();
    final modeLabel = _modeLabel(_battle.gameMode);
    final baseCardColor = isDarkMode ? colorScheme.surface : Colors.white;
    final baseTextColor = isDarkMode ? Colors.white : Colors.black87;
    final baseSubtextColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey[600]!;
    final overviewGradientColors = isDarkMode
        ? [colorScheme.primary, colorScheme.primaryContainer]
        : [Colors.green, Colors.green.shade700];
    final uploadPrimaryColor = colorScheme.primary;
    final uploadSecondaryColor = isDarkMode
        ? colorScheme.secondary
        : colorScheme.secondaryContainer;
    final trickLabel = _currentTrickLabel();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('$modeLabel Showdown'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'forfeit') {
                _forfeitBattle();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'forfeit',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Forfeit Match', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isTutorial) ...[
                    _buildTutorialBanner(),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: overviewGradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Battle Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current trick',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _battle.trickName != null 
                              ? '"${_battle.trickName}"' 
                              : '"$trickLabel"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1.1,
                                  ),
                                ),
                                child: _buildPlayerColumn(
                                  title: 'You',
                                  letters: myLetters,
                                  targetLetters: targetLetters,
                                  highlight: true,
                                  primaryTextColor: Colors.white,
                                  secondaryTextColor: Colors.white.withValues(
                                    alpha: 0.8,
                                  ),
                                  progressBackgroundColor: Colors.white
                                      .withValues(alpha: 0.16),
                                  progressValueColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: _buildPlayerColumn(
                                  title: 'Opponent',
                                  letters: opponentLetters,
                                  targetLetters: targetLetters,
                                  highlight: false,
                                  primaryTextColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                  secondaryTextColor: Colors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                  progressBackgroundColor: Colors.white
                                      .withValues(alpha: 0.2),
                                  progressValueColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _battle.setTrickVideoUrl != null
                              ? VideoPlayerWidget(videoUrl: _battle.setTrickVideoUrl!)
                              : Container(
                                  height: 190,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.black.withValues(alpha: 0.2),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 72,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildInfoChip(
                                icon: Icons.sports_kabaddi,
                                label: modeLabel,
                                color: Colors.white,
                              ),
                              _buildInfoChip(
                                icon: _isMyTurn
                                    ? Icons.bolt
                                    : Icons.pause_circle,
                                label: _isMyTurn
                                    ? 'Your turn'
                                    : "Waiting on opponent",
                                color: _isMyTurn
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                              ),
                              _buildInfoChip(
                                icon: Icons.shield,
                                label: _verificationLabel(
                                  _battle.verificationStatus,
                                ),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Bet and Timer Display
                        if (_battle.betAmount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: matrixGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bet: ${_battle.betAmount} pts (pot: ${_battle.betAmount * 2} pts)',
                                  style: const TextStyle(
                                    color: matrixGreen,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (!_battle.betAccepted && !_isMyTurn) ...[
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      try {
                                        final userId = Supabase.instance.client.auth.currentUser!.id;
                                        await BattleService.acceptBet(
                                          battleId: _battle.id!,
                                          opponentId: userId,
                                          betAmount: _battle.betAmount,
                                        );
                                        final refreshed = await BattleService.getBattle(_battle.id!);
                                        if (refreshed != null && mounted) {
                                          setState(() {
                                            _battle = refreshed;
                                            _isLoading = false;
                                          });
                                        }
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ErrorHelper.showError(context, 'Failed to accept bet: $e');
                                        setState(() => _isLoading = false);
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Accept Bet'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Timer countdown
                          if (_battle.turnDeadline != null) ...[
                            Text(
                              'Time left: ${_formatDuration(_battle.getRemainingTime())}',
                              style: TextStyle(
                                color: matrixGreen.withValues(alpha: 0.8),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                        Builder(
                          builder: (context) {
                            // RPS Check
                            if (_battle.setterId == null) {
                              return _buildRpsSection();
                            }

                            if (_battle.verificationStatus == VerificationStatus.quickFireVoting) {
                              return _buildVotingSection();
                            }

                            final bool canUploadSet =
                                _isMyTurn && _battle.setTrickVideoUrl == null;
                            final bool canUploadAttempt =
                                _isMyTurn &&
                                _battle.setTrickVideoUrl != null &&
                                _battle.verificationStatus ==
                                    VerificationStatus.pending;

                            String helper;
                            IconData icon;
                            Color color;
                            VoidCallback onPressed;

                            if (canUploadSet) {
                              helper =
                                  'Kick things off with a clip from your camera roll.';
                              icon = Icons.cloud_upload;
                              color = uploadPrimaryColor;
                              onPressed = _uploadSetTrick;
                            } else if (canUploadAttempt) {
                              helper =
                                  'Respond to the challenge and keep the battle alive.';
                              icon = Icons.sports_kabaddi;
                              color = uploadSecondaryColor;
                              onPressed = _uploadAttempt;
                            } else {
                              helper =
                                  'Upload will unlock when it\'s your turn for this round.';
                              icon = Icons.cloud_upload;
                              color = uploadPrimaryColor;
                              onPressed = _noop;
                            }

                            return _buildActionButton(
                              label: 'Upload Clip',
                              helper: helper,
                              icon: icon,
                              color: color,
                              onPressed: onPressed,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_isTutorial) ...[
                    const SizedBox(height: 20),
                    _buildTutorialControls(
                      cardColor: baseCardColor,
                      borderColor: colorScheme.primary.withValues(
                        alpha: isDarkMode ? 0.3 : 0.15,
                      ),
                      primaryTextColor: baseTextColor,
                      mutedTextColor: baseSubtextColor,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_battle.id != null)
                    _BattleHistoryCarousel(battleId: _battle.id!),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // Helper method to format duration
  String _formatDuration(Duration? duration) {
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

class _TrickNameDialog extends StatefulWidget {
  @override
  State<_TrickNameDialog> createState() => _TrickNameDialogState();
}

class _TrickNameDialogState extends State<_TrickNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Your Trick'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'e.g., Kickflip, Tre Flip',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Set Name'),
        ),
      ],
    );
  }
}

class _BattleHistoryCarousel extends StatelessWidget {
  final String battleId;

  const _BattleHistoryCarousel({required this.battleId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BattleTrick>>(
      future: BattleService.getBattleTricks(battleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final tricks = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Match History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tricks.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final trick = tricks[index];
                  final isLanded = trick.outcome == 'landed';
                  
                  return Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLanded ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: Colors.black),
                                Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 48,
                                  ),
                                ),
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // Show video dialog
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: EdgeInsets.zero,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                AspectRatio(
                                                  aspectRatio: 9/16,
                                                  child: VideoPlayerWidget(videoUrl: trick.attemptVideoUrl),
                                                ),
                                                Positioned(
                                                  top: 40,
                                                  right: 20,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                    onPressed: () => Navigator.pop(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trick.trickName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isLanded ? Icons.check_circle : Icons.cancel,
                                    size: 14,
                                    color: isLanded ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLanded ? 'Landed' : 'Missed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLanded ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
