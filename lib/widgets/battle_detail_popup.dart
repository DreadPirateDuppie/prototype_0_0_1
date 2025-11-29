import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../utils/error_helper.dart';

class BattleDetailPopup extends StatefulWidget {
  final Battle battle;
  final VoidCallback? onBattleUpdate;

  const BattleDetailPopup({
    super.key,
    required this.battle,
    this.onBattleUpdate,
  });

  @override
  State<BattleDetailPopup> createState() => _BattleDetailPopupState();
}

class _BattleDetailPopupState extends State<BattleDetailPopup> {
  late Battle _battle;
  bool _isLoading = false;

  // Matrix theme colors
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);
  static const Color matrixDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _battle = widget.battle;
  }

  Future<void> _uploadSetTrick() async {
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
        'set',
      );

      final updatedBattle = await BattleService.uploadSetTrick(
        battleId: _battle.id!,
        videoUrl: videoUrl,
      );

      if (updatedBattle != null && mounted) {
        setState(() {
          _battle = updatedBattle;
          _isLoading = false;
        });
        widget.onBattleUpdate?.call();
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
          _isLoading = false;
        });
        widget.onBattleUpdate?.call();
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error uploading attempt: $e');
        setState(() => _isLoading = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isPlayer1 = _battle.player1Id == userId;
    final isMyTurn = _battle.currentTurnPlayerId == userId;
    
    final myLetters = isPlayer1 ? _battle.player1Letters : _battle.player2Letters;
    final opponentLetters = isPlayer1 ? _battle.player2Letters : _battle.player1Letters;
    final targetLetters = _battle.getGameLetters();
    final modeLabel = _modeLabel(_battle.gameMode);
    final trickLabel = _currentTrickLabel();

    return Dialog(
      backgroundColor: matrixDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: matrixGreen.withValues(alpha: 0.3), width: 1),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    matrixBlack,
                    matrixDark,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sports_kabaddi,
                        color: matrixGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$modeLabel SHOWDOWN',
                          style: const TextStyle(
                            color: matrixGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: matrixGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '"$trickLabel"',
                      style: const TextStyle(
                        color: matrixGreen,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Battle Progress
                    Row(
                      children: [
                        // Your Score
                        Expanded(
                          child: _buildPlayerCard(
                            title: 'YOU',
                            letters: myLetters,
                            targetLetters: targetLetters,
                            isHighlight: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // VS
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: matrixGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Opponent Score
                        Expanded(
                          child: _buildPlayerCard(
                            title: 'OPPONENT',
                            letters: opponentLetters,
                            targetLetters: targetLetters,
                            isHighlight: false,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Status and Actions
                    if (_isLoading)
                      Center(
                        child: CircularProgressIndicator(color: matrixGreen),
                      )
                    else ...[
                      // Status Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: matrixBlack,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: matrixGreen.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isMyTurn ? Icons.bolt : Icons.pause_circle,
                              color: isMyTurn ? matrixGreen : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMyTurn ? 'YOUR TURN' : "WAITING",
                              style: TextStyle(
                                color: isMyTurn ? matrixGreen : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: matrixGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _verificationLabel(_battle.verificationStatus),
                                style: const TextStyle(
                                  color: matrixGreen,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bet Information
                      if (_battle.betAmount > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'BET: ${_battle.betAmount} pts (POT: ${_battle.betAmount * 2})',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Timer
                      if (_battle.turnDeadline != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TIME LEFT: ${_formatDuration(_battle.getRemainingTime())}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Action Button
                      _buildActionButton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required String title,
    required String letters,
    required String targetLetters,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight 
            ? matrixGreen.withValues(alpha: 0.1)
            : matrixBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight 
              ? matrixGreen.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isHighlight ? matrixGreen : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            letters.isEmpty ? '-' : letters,
            style: TextStyle(
              color: isHighlight ? matrixGreen : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '/ $targetLetters',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isPlayer1 = _battle.player1Id == userId;
    final isMyTurn = _battle.currentTurnPlayerId == userId;
    
    final bool canUploadSet = isMyTurn && _battle.setTrickVideoUrl == null;
    final bool canUploadAttempt = !isMyTurn && _battle.setTrickVideoUrl != null && 
        _battle.verificationStatus == VerificationStatus.pending;
    
    String buttonText;
    String helperText;
    IconData icon;
    Color color;
    VoidCallback onPressed;
    
    if (canUploadSet) {
      buttonText = 'SET TRICK';
      helperText = 'Upload a video of the trick you want to set';
      icon = Icons.upload;
      color = Colors.amber;
      onPressed = _uploadSetTrick;
    } else if (canUploadAttempt) {
      buttonText = 'ATTEMPT TRICK';
      helperText = 'Upload your attempt at the set trick';
      icon = Icons.sports_kabaddi;
      color = matrixGreen;
      onPressed = _uploadAttempt;
    } else {
      buttonText = 'WAITING';
      helperText = 'Upload will unlock when it\'s your turn';
      icon = Icons.schedule;
      color = Colors.grey;
      onPressed = () {};
    }
    
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(
            buttonText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: color == Colors.grey ? Colors.white : matrixBlack,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helperText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

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

// Helper function to show the battle detail popup
Future<void> showBattleDetailPopup(BuildContext context, Battle battle, {VoidCallback? onUpdate}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => BattleDetailPopup(
      battle: battle,
      onBattleUpdate: onUpdate,
    ),
  );
}
