import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/battle.dart';
import '../models/battle_trick.dart';
import '../services/battle_service.dart';
import '../utils/error_helper.dart';
import '../widgets/video_player_widget.dart';
import '../config/theme_config.dart';
import '../services/supabase_service.dart';
import 'dart:developer' as developer;
import 'chat_screen.dart';
import '../services/messaging_service.dart';

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
  bool _isRefreshing = false;
  RealtimeChannel? _battleSubscription;
  Timer? _refreshTimer;

  String? _player1Name;
  String? _player1Avatar;
  String? _player2Name;
  String? _player2Avatar;



  @override
  void initState() {
    super.initState();
    _isTutorial = widget.tutorialMode;
    _loadBattle();
    _subscribeToBattle();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Trigger rebuild to update countdown
        setState(() {});

        if (!_isLoading && !_isRefreshing) {
          try {
            final remaining = _battle.getRemainingTime();
            if (remaining != null && remaining.inSeconds <= 0) {
               _refreshBattle();
            }
          } catch (e) {
            // Battle might not be initialized yet
          }
        }
      }
    });
  }

  Future<void> _refreshBattle() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    // Check for expired turns to update game state
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await BattleService.checkExpiredTurns(userId);
      } catch (e) {
        // Ignore error, just try to reload
      }
    }

    await _loadBattle();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _battleSubscription?.unsubscribe();
    super.dispose();
  }

  void _subscribeToBattle() {
    if (widget.battleId == null) return;

    _battleSubscription = Supabase.instance.client
        .channel('public:battles:id=eq.${widget.battleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'battles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.battleId!,
          ),
          callback: (payload) {
            if (mounted) {
              final updatedBattle = Battle.fromMap(payload.newRecord);
              _initBattle(updatedBattle);
            }
          },
        )
        .subscribe();
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
      // Check for winner transition
      if (!_isLoading && _battle.winnerId == null && battle.winnerId != null) {
        _showWinnerDialog(battle.winnerId!);
      }

      // Check for tie (RPS moves reset to null from non-null)
      if (_isLoading == false && // Only check after initial load
          _battle.setterId == null &&
          battle.setterId == null &&
          (_battle.player1RpsMove != null || _battle.player2RpsMove != null) &&
          battle.player1RpsMove == null &&
          battle.player2RpsMove == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tie! Go again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        _battle = battle;
        final userId = widget.tutorialMode 
            ? widget.tutorialUserId 
            : Supabase.instance.client.auth.currentUser?.id;
        _isPlayer1 = _battle.player1Id == userId;
        _isMyTurn = _battle.currentTurnPlayerId == userId;
        _isLoading = false;
      });
      _loadPlayerProfiles();
    }
  }

  Future<void> _loadPlayerProfiles() async {
    try {
      final p1Name = await SupabaseService.getUserUsername(_battle.player1Id);
      final p1Avatar = await SupabaseService.getUserAvatarUrl(_battle.player1Id);
      final p2Name = await SupabaseService.getUserUsername(_battle.player2Id);
      final p2Avatar = await SupabaseService.getUserAvatarUrl(_battle.player2Id);

      if (mounted) {
        setState(() {
          _player1Name = p1Name;
          _player1Avatar = p1Avatar;
          _player2Name = p2Name;
          _player2Avatar = p2Avatar;
        });
      }
    } catch (e) {
      developer.log('Error loading player profiles: $e', name: 'BattleDetailScreen');
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

  Future<void> _forfeitTurn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          side: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.5)),
        ),
        title: Text(
          'SKIP TRICK?',
          style: AppTextStyles.heading3.copyWith(color: ThemeColors.matrixGreen),
        ),
        content: Text(
          'Are you sure you want to skip this trick? You will receive a letter.',
          style: AppTextStyles.body1.copyWith(color: ThemeColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: AppTextStyles.button.copyWith(color: ThemeColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'SKIP TRICK',
              style: AppTextStyles.button.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final updatedBattle = await BattleService.forfeitTurn(
        battleId: _battle.id!,
        playerId: userId,
      );
      
      if (updatedBattle != null && mounted) {
        _initBattle(updatedBattle);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn forfeited')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to skip trick: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showWinnerDialog(String winnerId) async {
    // Get winner profile
    String? avatarUrl;
    String winnerName = 'Winner';
    
    try {
      final profile = await SupabaseService.getUserProfile(winnerId);
      if (profile != null) {
        avatarUrl = profile['avatar_url'];
        winnerName = profile['username'] ?? 'Winner';
      }
    } catch (e) {
      // Ignore error, just show default
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: ThemeColors.matrixGreen,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: ThemeColors.matrixGreen,
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThemeColors.matrixGreen,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 50,
                            color: ThemeColors.matrixGreen,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 50,
                          color: ThemeColors.matrixGreen,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                winnerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'WINS THE BATTLE!',
                style: TextStyle(
                  color: ThemeColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close battle screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.matrixGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'BACK TO LOBBY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBattleChat() async {
    if (_battle.id == null) return;

    setState(() => _isLoading = true);

    try {
      final conversationId = await MessagingService.getOrCreateBattleConversation(
        _battle.id!,
        [_battle.player1Id, _battle.player2Id],
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (conversationId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(conversationId: conversationId),
            ),
          );
        } else {
          ErrorHelper.showError(context, 'Failed to open chat');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHelper.showError(context, 'Error opening chat: $e');
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
    String? name,
    String? avatarUrl,
  }) {
    return Column(
      children: [
        // Avatar and Name
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryTextColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryTextColor.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: primaryTextColor.withValues(alpha: 0.1),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Icon(Icons.person, color: primaryTextColor.withValues(alpha: 0.5))
              : null,
        ),
      ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          name?.toUpperCase() ?? 'UNKNOWN',
          style: AppTextStyles.caption.copyWith(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.md),
        // Letters
        Text(
          letters.isEmpty ? '-' : letters.toUpperCase(),
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            fontFamily: 'monospace',
            shadows: highlight ? [
              Shadow(
                color: primaryTextColor.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ] : null,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: letters.length / targetLetters.length,
            backgroundColor: progressBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressValueColor),
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            label,
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

  Widget _buildActionButton({
    required String label,
    required String helper,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final bool isDisabled = onPressed == _noop;
    final bool isOpponentTurn = label.contains("OPPONENT'S TURN");
    
    Color textColor;
    if (isOpponentTurn) {
      textColor = Colors.white;
    } else if (isDisabled) {
      textColor = ThemeColors.textDisabled;
    } else if (color == ThemeColors.matrixGreen || color == Colors.orange) {
      textColor = Colors.black;
    } else {
      textColor = Colors.white;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            gradient: isOpponentTurn 
                ? const LinearGradient(
                    colors: [Color(0xFF600000), Color(0xFFB71C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !isOpponentTurn ? color : null,
            boxShadow: [
              BoxShadow(
                color: (isOpponentTurn ? Colors.red : color).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: textColor),
            label: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          helper.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: ThemeColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: ThemeColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: ThemeColors.matrixGreen,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'VOTE SUBMITTED',
              style: AppTextStyles.heading3.copyWith(
                color: ThemeColors.matrixGreen,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Waiting for opponent...',
              style: AppTextStyles.body1.copyWith(
                color: ThemeColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '> VOTE ON ATTEMPT_',
            style: AppTextStyles.heading2.copyWith(
              color: ThemeColors.matrixGreen,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitVote('missed'),
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('MISSED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    foregroundColor: Colors.red,
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _submitVote('landed'),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('LANDED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                    foregroundColor: ThemeColors.matrixGreen,
                    side: BorderSide(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
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
      
      // Optimistically update local state
      setState(() {
        if (_battle.player1Id == userId) {
          _battle = _battle.copyWith(player1RpsMove: move);
        } else {
          _battle = _battle.copyWith(player2RpsMove: move);
        }
        _isLoading = false; // Stop loading to show waiting screen immediately
      });

      // Submit RPS move to backend
      await BattleService.submitRpsMove(
        battleId: _battle.id!,
        userId: userId,
        move: move,
      );
      
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to submit RPS move: $e');
        // Revert local state if needed, or just let the user try again
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
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated waiting indicator
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: ThemeColors.matrixGreen,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'WAITING FOR OPPONENT',
                style: AppTextStyles.heading3.copyWith(
                  color: ThemeColors.matrixGreen,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'YOU CHOSE: ${myMove.toUpperCase()}',
                  style: AppTextStyles.body2.copyWith(
                    color: ThemeColors.matrixGreen,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Main RPS selection screen - ENHANCED & RESPONSIVE
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_kabaddi_outlined,
              size: 48,
              color: ThemeColors.matrixGreen.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'ROCK PAPER SCISSORS',
            style: AppTextStyles.heading3.copyWith(
              color: ThemeColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'WINNER SETS THE FIRST TRICK',
            style: AppTextStyles.caption.copyWith(
              color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Forfeit Option in RPS
          TextButton.icon(
            onPressed: _forfeitBattle,
            icon: const Icon(Icons.flag_outlined, size: 14, color: Colors.red),
            label: Text(
              'FORFEIT MATCH',
              style: AppTextStyles.caption.copyWith(
                color: Colors.red.withValues(alpha: 0.7),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Enhanced RPS buttons - Responsive Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildEnhancedRpsButton(
                  'rock',
                  Icons.circle_outlined,
                  'ROCK',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildEnhancedRpsButton(
                  'paper',
                  Icons.article_outlined,
                  'PAPER',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildEnhancedRpsButton(
                  'scissors',
                  Icons.content_cut_outlined,
                  'SCISSORS',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRpsButton(String move, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1, // Keeps it square
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeColors.backgroundDark,
              border: Border.all(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _submitRpsMove(move),
                customBorder: const CircleBorder(),
                splashColor: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                highlightColor: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    icon,
                    size: 32, // Fixed icon size, container scales
                    color: ThemeColors.matrixGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: ThemeColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 10, // Slightly smaller to prevent wrap
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure battle is loaded before accessing properties
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThemeColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: ThemeColors.backgroundDark,
          title: Text(
            'Loading...',
            style: AppTextStyles.heading3.copyWith(color: ThemeColors.matrixGreen),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeColors.matrixGreen,
            strokeWidth: 3,
          ),
        ),
      );
    }

    final modeLabel = _modeLabel(_battle.gameMode);

    // FIRST SCREEN: RPS Selection (when no setter chosen yet)
    if (_battle.setterId == null) {
      return Scaffold(
        backgroundColor: ThemeColors.backgroundDark,
        appBar: AppBar(
          title: Text(
          'VS',
          style: AppTextStyles.heading3.copyWith(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
          backgroundColor: Colors.transparent,
          foregroundColor: ThemeColors.matrixGreen,
          centerTitle: true,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'forfeit') {
                  _forfeitBattle();
                }
              },
              icon: Icon(Icons.more_vert, color: ThemeColors.matrixGreen),
              color: ThemeColors.surfaceDark,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'forfeit',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.red.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Forfeit Match',
                        style: AppTextStyles.body2.copyWith(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildRpsSection(),
          ),
        ),
      );
    }

    // SECOND SCREEN: Full Battle UI (after RPS complete)
    final myLetters = _isPlayer1
        ? _battle.player1Letters
        : _battle.player2Letters;
    final opponentLetters = _isPlayer1
        ? _battle.player2Letters
        : _battle.player1Letters;
    final targetLetters = _battle.getGameLetters();
    final trickLabel = _currentTrickLabel();

    return Scaffold(
      backgroundColor: ThemeColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'VS',
          style: AppTextStyles.heading3.copyWith(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: ThemeColors.matrixGreen,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openBattleChat,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'forfeit') {
                _forfeitBattle();
              } else if (value == 'forfeit_turn') {
                _forfeitTurn();
              }
            },
            icon: Icon(Icons.more_vert, color: ThemeColors.matrixGreen),
            color: ThemeColors.surfaceDark,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'forfeit_turn',
                child: Row(
                  children: [
                    Icon(Icons.skip_next, color: Colors.orange.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Text(
                      'Forfeit Turn',
                      style: AppTextStyles.body2.copyWith(color: Colors.orange),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'forfeit',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Text(
                      'Forfeit Match',
                      style: AppTextStyles.body2.copyWith(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ThemeColors.backgroundDark,
                ThemeColors.backgroundDark.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  ThemeColors.matrixGreen.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isTutorial) ...[
              _buildTutorialBanner(),
              const SizedBox(height: AppSpacing.md),
            ],

            // 1. Timer countdown (at the top)
            if (_battle.turnDeadline != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppBorderRadius.round),
                    border: Border.all(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TIME REMAINING: ${_formatDuration(_battle.getRemainingTime())}',
                        style: AppTextStyles.caption.copyWith(
                          color: ThemeColors.matrixGreen,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 2. Trick name
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'CURRENT TRICK',
                  style: AppTextStyles.caption.copyWith(
                    color: ThemeColors.textSecondary.withValues(alpha: 0.6),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _battle.trickName != null 
                      ? _battle.trickName!.toUpperCase() 
                      : trickLabel.toUpperCase(),
                  style: AppTextStyles.heading2.copyWith(
                    color: ThemeColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    color: ThemeColors.matrixGreen,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3. Status & Bet Chips (above video)
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _buildInfoChip(
                    icon: Icons.sports_kabaddi,
                    label: modeLabel.toUpperCase(),
                    color: ThemeColors.matrixGreen,
                  ),
                  _buildInfoChip(
                    icon: Icons.verified_user_outlined,
                    label: _verificationLabel(_battle.verificationStatus).toUpperCase(),
                    color: _battle.verificationStatus == VerificationStatus.pending 
                        ? Colors.red 
                        : ThemeColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_battle.betAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.08),
                      const Color(0xFFFFD700).withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.stars_rounded,
                            color: const Color(0xFFFFD700),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WAGER AMOUNT',
                              style: AppTextStyles.caption.copyWith(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              '${_battle.betAmount} PTS',
                              style: AppTextStyles.body1.copyWith(
                                color: const Color(0xFFFFD700),
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            'POT: ${_battle.betAmount * 2}',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_battle.betAccepted && !_isMyTurn) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
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
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('ACCEPT WAGER'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            textStyle: AppTextStyles.button.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 4. Video player section
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                border: Border.all(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                child: _battle.setTrickVideoUrl != null
                    ? VideoPlayerWidget(videoUrl: _battle.setTrickVideoUrl!)
                    : Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ThemeColors.surfaceDark,
                              ThemeColors.backgroundDark,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 48,
                                  color: ThemeColors.matrixGreen.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'NO VIDEO YET',
                                style: AppTextStyles.caption.copyWith(
                                  color: ThemeColors.textSecondary.withValues(alpha: 0.5),
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

            // 5. Players VS display (at the bottom)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ThemeColors.matrixGreen.withValues(alpha: 0.08),
                          ThemeColors.matrixGreen.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(
                        color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: _buildPlayerColumn(
                      title: 'YOU',
                      letters: myLetters,
                      targetLetters: targetLetters,
                      highlight: true,
                      primaryTextColor: ThemeColors.matrixGreen,
                      secondaryTextColor: ThemeColors.textSecondary,
                      progressBackgroundColor: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                      progressValueColor: ThemeColors.matrixGreen,
                      name: _isPlayer1 ? _player1Name : _player2Name,
                      avatarUrl: _isPlayer1 ? _player1Avatar : _player2Avatar,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      Text(
                        'VS',
                        style: AppTextStyles.heading3.copyWith(
                          color: ThemeColors.textSecondary.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.withValues(alpha: 0.08),
                          Colors.red.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: _buildPlayerColumn(
                      title: 'OPP',
                      letters: opponentLetters,
                      targetLetters: targetLetters,
                      highlight: false,
                      primaryTextColor: Colors.red.withValues(alpha: 0.8),
                      secondaryTextColor: ThemeColors.textSecondary,
                      progressBackgroundColor: Colors.red.withValues(alpha: 0.1),
                      progressValueColor: Colors.red.withValues(alpha: 0.7),
                      name: _isPlayer1 ? _player2Name : _player1Name,
                      avatarUrl: _isPlayer1 ? _player2Avatar : _player1Avatar,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Builder(
              builder: (context) {
                // RPS Check
                if (_battle.setterId == null) {
                  return _buildRpsSection();
                }

                if (_battle.verificationStatus == VerificationStatus.quickFireVoting) {
                  return _buildVotingSection();
                }

                if (_battle.verificationStatus == VerificationStatus.communityVerification) {
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: ThemeColors.surfaceDark.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            color: Colors.orange,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'COMMUNITY REVIEW',
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Votes didn\'t match. The community will decide the outcome.',
                          style: AppTextStyles.body2.copyWith(
                            color: ThemeColors.textSecondary.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
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
                String label = 'UPLOAD CLIP';

                if (canUploadSet) {
                  helper = 'Set the challenge for your opponent';
                  icon = Icons.add_a_photo_outlined;
                  color = ThemeColors.matrixGreen;
                  onPressed = _uploadSetTrick;
                  label = 'SET TRICK';
                } else if (canUploadAttempt) {
                  helper = 'Attempt the trick to avoid a letter';
                  icon = Icons.sports_kabaddi_outlined;
                  color = Colors.orange;
                  onPressed = _uploadAttempt;
                  label = 'ATTEMPT TRICK';
                } else {
                  helper = 'Wait for your turn to make a move';
                  icon = Icons.lock_outline;
                  color = Colors.red;
                  onPressed = _noop;
                  label = "OPPONENT'S TURN";
                  if (_battle.turnDeadline != null) {
                    label += ' (${_formatDuration(_battle.getRemainingTime())})';
                  }
                }

                return Column(
                  children: [
                    _buildActionButton(
                      label: label,
                      helper: helper,
                      icon: icon,
                      color: color,
                      onPressed: onPressed,
                    ),
                    if (canUploadAttempt) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _forfeitTurn,
                        child: Text(
                          'SKIP TRICK (TAKE LETTER)',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.red.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            if (_isTutorial) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildTutorialControls(
                cardColor: ThemeColors.surfaceDark,
                borderColor: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                primaryTextColor: ThemeColors.textPrimary,
                mutedTextColor: ThemeColors.textSecondary,
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
