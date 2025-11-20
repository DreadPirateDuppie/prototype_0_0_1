import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/verification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class _TutorialScene {
  final String description;
  final String trickName;
  final String player1Letters;
  final String player2Letters;
  final String? setTrickVideoUrl;
  final String? attemptVideoUrl;
  final VerificationStatus verificationStatus;
  final String currentTurnPlayerId;
  final String? winnerId;

  const _TutorialScene({
    required this.description,
    required this.trickName,
    required this.player1Letters,
    required this.player2Letters,
    required this.setTrickVideoUrl,
    required this.attemptVideoUrl,
    required this.verificationStatus,
    required this.currentTurnPlayerId,
    this.winnerId,
  });
}

class BattleDetailScreen extends StatefulWidget {
  final Battle battle;
  final bool tutorialMode;
  final String? tutorialUserId;

  const BattleDetailScreen({
    super.key,
    required this.battle,
    this.tutorialMode = false,
    this.tutorialUserId,
  });

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  late Battle _battle;
  bool _isLoading = false;
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<_TutorialScene> _tutorialScenes = [];
  int _tutorialSceneIndex = 0;
  bool _tutorialPlaying = false;

  String? get _effectiveUserId {
    if (widget.tutorialMode) {
      return widget.tutorialUserId ?? 'tutorial_user';
    }
    return _currentUser?.id;
  }

  Widget _buildTutorialControls({
    required Color cardColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    if (!_isTutorial || _tutorialScenes.isEmpty) {
      return const SizedBox.shrink();
    }
    final scene = _tutorialScenes[_tutorialSceneIndex];
    final progress = (_tutorialSceneIndex + 1) / _tutorialScenes.length;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tutorial walkthrough',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              Text(
                '${_tutorialSceneIndex + 1}/${_tutorialScenes.length}',
                style: TextStyle(color: mutedTextColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(scene.description, style: TextStyle(color: primaryTextColor)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: mutedTextColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous step',
                onPressed: _tutorialSceneIndex == 0
                    ? null
                    : () => _goToTutorialScene(-1),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _tutorialScenes.length <= 1
                      ? null
                      : _playTutorialDemo,
                  icon: Icon(
                    _tutorialPlaying ? Icons.stop : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _tutorialPlaying ? 'Stop autoplay' : 'Play walkthrough',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Next step',
                onPressed: _tutorialSceneIndex == _tutorialScenes.length - 1
                    ? null
                    : () => _goToTutorialScene(1),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _isTutorial => widget.tutorialMode;

  void _showInfoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _battle = widget.battle;
    if (_isTutorial) {
      _setupTutorialScenes();
    } else {
      _loadBattleDetails();
    }
  }

  String _currentTrickLabel() {
    if (_isTutorial && _tutorialScenes.isNotEmpty) {
      return _tutorialScenes[_tutorialSceneIndex].trickName;
    }
    // For real battles we dont yet track trick names, so show a generic hint.
    return 'Current line: street trick in progress.';
  }

  void _setupTutorialScenes() {
    final baseBattle = widget.battle;
    _tutorialScenes = [
      _TutorialScene(
        description:
            'Step 1 · Rock–paper–scissors! You and your opponent throw hands to decide who sets first.',
        trickName: 'RPS to decide the opener.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl: null,
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player1Id,
      ),
      _TutorialScene(
        description:
            'Step 2 · You win RPS. You get to set first in this SK8 battle.',
        trickName: 'Winner sets first.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl: null,
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player1Id,
      ),
      _TutorialScene(
        description:
            'Step 3 · Round 1 starts. You have 4:20 on the clock to film and upload your set trick.',
        trickName: 'Warm-up kickflip on flat.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl: null,
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player1Id,
      ),
      _TutorialScene(
        description:
            'Step 4 · Set trick clip is up. Your opponent watches and gets ready to answer it.',
        trickName: 'Treflip down the three stair.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl:
            baseBattle.setTrickVideoUrl ??
            baseBattle.setTrickVideoUrl ??
            'https://example.com/tutorial_set.mp4',
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player2Id,
      ),
      _TutorialScene(
        description:
            'Step 5 · Your opponent has 4:20 to drop their best attempt clip.',
        trickName: 'Nollie backside bigspin over the hip.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl:
            baseBattle.setTrickVideoUrl ??
            'https://example.com/tutorial_set.mp4',
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player2Id,
      ),
      _TutorialScene(
        description:
            'Step 6 · Attempt clip uploaded. Quick-Fire voting kicks in.',
        trickName: 'Nollie backside bigspin over the hip.',
        player1Letters: '',
        player2Letters: '',
        setTrickVideoUrl:
            baseBattle.setTrickVideoUrl ??
            'https://example.com/tutorial_set.mp4',
        attemptVideoUrl:
            baseBattle.attemptVideoUrl ??
            'https://example.com/tutorial_attempt.mp4',
        verificationStatus: VerificationStatus.quickFireVoting,
        currentTurnPlayerId: baseBattle.player2Id,
      ),
      _TutorialScene(
        description:
            'Step 7 · Voting finishes. Your opponent misses and picks up a letter (S).',
        trickName: 'Clean fakie heelflip on the bank.',
        player1Letters: '',
        player2Letters: 'S',
        setTrickVideoUrl: null,
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.pending,
        currentTurnPlayerId: baseBattle.player2Id,
      ),
      _TutorialScene(
        description:
            'Step 8 · Final exchange. Your opponent reaches SK8 and the battle ends.',
        trickName: 'Ender: switch frontside flip on flat.',
        player1Letters: '',
        player2Letters: 'SK8',
        setTrickVideoUrl: null,
        attemptVideoUrl: null,
        verificationStatus: VerificationStatus.resolved,
        currentTurnPlayerId: baseBattle.player1Id,
        winnerId: baseBattle.player1Id,
      ),
    ];
    _applyTutorialScene(0, announce: false);
  }

  void _applyTutorialScene(int index, {bool announce = true}) {
    final scene = _tutorialScenes[index];
    setState(() {
      _tutorialSceneIndex = index;
      _battle = _battle.copyWith(
        player1Letters: scene.player1Letters,
        player2Letters: scene.player2Letters,
        setTrickVideoUrl: scene.setTrickVideoUrl,
        attemptVideoUrl: scene.attemptVideoUrl,
        verificationStatus: scene.verificationStatus,
        currentTurnPlayerId: scene.currentTurnPlayerId,
        winnerId: scene.winnerId,
      );
    });
  }

  void _goToTutorialScene(int delta) {
    final nextIndex = (_tutorialSceneIndex + delta).clamp(
      0,
      _tutorialScenes.length - 1,
    );
    if (nextIndex != _tutorialSceneIndex) {
      _applyTutorialScene(nextIndex);
    }
  }

  Future<void> _playTutorialDemo() async {
    if (_tutorialPlaying) {
      setState(() {
        _tutorialPlaying = false;
      });
      return;
    }

    setState(() {
      _tutorialPlaying = true;
    });

    var index = _tutorialSceneIndex;
    while (mounted && _tutorialPlaying && index < _tutorialScenes.length - 1) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_tutorialPlaying || !mounted) break;
      index++;
      _applyTutorialScene(index);
    }

    if (mounted) {
      setState(() {
        _tutorialPlaying = false;
      });
    }
  }

  Future<void> _loadBattleDetails() async {
    if (widget.tutorialMode) {
      return;
    }
    try {
      final battle = await BattleService.getBattle(_battle.id!);
      if (battle != null) {
        setState(() {
          _battle = battle;
        });
      }

      // Load Quick-Fire vote if in voting status
      if (_battle.verificationStatus == VerificationStatus.quickFireVoting) {
        await _loadQuickFireVote();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading battle: $e')));
      }
    }
  }

  Future<void> _loadQuickFireVote() async {
    // In a real implementation, we'd need to get the current attempt ID
    // For now, we'll skip this
  }

  bool get _isPlayer1 => _battle.player1Id == _effectiveUserId;
  bool get _isMyTurn => _battle.currentTurnPlayerId == _effectiveUserId;

  double _lettersProgress(String letters, String targetLetters) {
    if (targetLetters.isEmpty) return 0;
    return (letters.length / targetLetters.length).clamp(0, 1).toDouble();
  }

  String _modeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return 'SKATE';
      case GameMode.sk8:
        return 'SK8';
      case GameMode.custom:
        return 'Custom';
    }
  }

  String _verificationLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'Awaiting Attempt';
      case VerificationStatus.quickFireVoting:
        return 'Quick-Fire Voting';
      case VerificationStatus.communityVerification:
        return 'Community Review';
      case VerificationStatus.resolved:
        return 'Resolved';
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? background,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
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
    final progress = _lettersProgress(letters, targetLetters);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          letters.isEmpty ? '-' : letters,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'of $targetLetters',
          style: TextStyle(color: secondaryTextColor, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: progressBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              highlight
                  ? progressValueColor
                  : progressValueColor.withValues(alpha: 0.7),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tutorial Mode',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is a read-only preview. Uploads and votes are disabled so you can safely explore the UI.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _noop() {}

  Widget _buildActionButton({
    required String label,
    required String helper,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final helperColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final bool isDisabled = identical(onPressed, _noop);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Opacity(
            opacity: isDisabled ? 0.35 : 1.0,
            child: ElevatedButton.icon(
              onPressed: isDisabled ? null : onPressed,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: onPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.0,
                  ),
                ),
                elevation: 6,
                shadowColor: color.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helper,
          textAlign: TextAlign.center,
          style: TextStyle(color: helperColor, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _uploadSetTrick() async {
    if (widget.tutorialMode) {
      _showInfoSnack('Tutorial mode: uploads are disabled.');
      return;
    }
    final userId = _effectiveUserId;
    if (userId == null) {
      _showInfoSnack('No authenticated user found.');
      return;
    }
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final videoFile = File(video.path);
      final videoUrl = await BattleService.uploadTrickVideo(
        videoFile,
        _battle.id!,
        userId,
        'set',
      );

      final updatedBattle = await BattleService.uploadSetTrick(
        battleId: _battle.id!,
        videoUrl: videoUrl,
      );

      if (updatedBattle != null) {
        setState(() {
          _battle = updatedBattle;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Set trick uploaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading video: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadAttempt() async {
    if (widget.tutorialMode) {
      _showInfoSnack('Tutorial mode: uploads are disabled.');
      return;
    }
    final userId = _effectiveUserId;
    if (userId == null) {
      _showInfoSnack('No authenticated user found.');
      return;
    }
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final videoFile = File(video.path);
      final videoUrl = await BattleService.uploadTrickVideo(
        videoFile,
        _battle.id!,
        userId,
        'attempt',
      );

      // Create verification attempt
      final attempt = await VerificationService.createVerificationAttempt(
        battleId: _battle.id!,
        attemptingPlayerId: userId,
        attemptVideoUrl: videoUrl,
      );

      // Create Quick-Fire vote session
      if (attempt != null && !widget.tutorialMode) {
        await VerificationService.createQuickFireVote(
          attemptId: attempt.id!,
          player1Id: _battle.player1Id,
          player2Id: _battle.player2Id,
        );
      }

      final updatedBattle = await BattleService.uploadAttempt(
        battleId: _battle.id!,
        videoUrl: videoUrl,
      );

      if (updatedBattle != null) {
        setState(() {
          _battle = updatedBattle;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attempt uploaded! Waiting for votes...'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading attempt: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
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
        : [Colors.deepPurple, const Color(0xFF5C6BC0)];
    final uploadPrimaryColor = colorScheme.primary;
    final uploadSecondaryColor = isDarkMode
        ? colorScheme.secondary
        : colorScheme.secondaryContainer;
    final trickLabel = _currentTrickLabel();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('$modeLabel Showdown'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          color: Colors.deepPurple.withValues(alpha: 0.35),
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
                          '"$trickLabel"',
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
                          child: Container(
                            height: 190,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _battle.setTrickVideoUrl != null
                                    ? [
                                        Colors.black.withValues(alpha: 0.9),
                                        Colors.black.withValues(alpha: 0.7),
                                      ]
                                    : [
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
                        Builder(
                          builder: (context) {
                            final bool canUploadSet =
                                _isMyTurn && _battle.setTrickVideoUrl == null;
                            final bool canUploadAttempt =
                                !_isMyTurn &&
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
                ],
              ),
            ),
    );
  }
}
