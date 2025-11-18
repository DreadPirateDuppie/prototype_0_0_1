import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../models/verification.dart';
import '../services/battle_service.dart';
import '../services/verification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BattleDetailScreen extends StatefulWidget {
  final Battle battle;

  const BattleDetailScreen({super.key, required this.battle});

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  late Battle _battle;
  bool _isLoading = false;
  final _currentUser = Supabase.instance.client.auth.currentUser;
  QuickFireVote? _quickFireVote;
  VerificationAttempt? _currentAttempt;

  @override
  void initState() {
    super.initState();
    _battle = widget.battle;
    _loadBattleDetails();
  }

  Future<void> _loadBattleDetails() async {
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

  bool get _isPlayer1 => _battle.player1Id == _currentUser?.id;
  bool get _isMyTurn => _battle.currentTurnPlayerId == _currentUser?.id;

  Future<void> _uploadSetTrick() async {
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
        _currentUser!.id,
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
        _currentUser!.id,
        'attempt',
      );

      // Create verification attempt
      final attempt = await VerificationService.createVerificationAttempt(
        battleId: _battle.id!,
        attemptingPlayerId: _currentUser.id,
        attemptVideoUrl: videoUrl,
      );

      // Create Quick-Fire vote session
      if (attempt != null) {
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
          _currentAttempt = attempt;
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

  Future<void> _submitQuickFireVote(VoteType voteType) async {
    if (_currentAttempt == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedVote = await VerificationService.submitQuickFireVote(
        attemptId: _currentAttempt!.id!,
        playerId: _currentUser!.id,
        vote: voteType,
      );

      setState(() {
        _quickFireVote = updatedVote;
      });

      if (mounted) {
        if (updatedVote?.bothPlayersVoted == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vote recorded! Processing result...'),
            ),
          );
          // Reload battle details after a delay
          await Future.delayed(const Duration(seconds: 2));
          await _loadBattleDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vote recorded! Waiting for other player...'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting vote: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildQuickFireVoting() {
    final myId = _currentUser?.id;
    final hasVoted =
        _quickFireVote != null &&
        ((_quickFireVote!.player1Id == myId &&
                _quickFireVote!.player1Vote != null) ||
            (_quickFireVote!.player2Id == myId &&
                _quickFireVote!.player2Vote != null));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick-Fire Voting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (hasVoted)
              const Text(
                'Waiting for other player to vote...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              )
            else
              Column(
                children: [
                  const Text('Did the player land the trick?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _submitQuickFireVote(VoteType.land),
                        icon: const Icon(Icons.check),
                        label: const Text('Land'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _submitQuickFireVote(VoteType.noLand),
                        icon: const Icon(Icons.close),
                        label: const Text('No Land'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _submitQuickFireVote(VoteType.rebate),
                        icon: const Icon(Icons.replay),
                        label: const Text('Rebate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myLetters = _isPlayer1
        ? _battle.player1Letters
        : _battle.player2Letters;
    final opponentLetters = _isPlayer1
        ? _battle.player2Letters
        : _battle.player1Letters;
    final targetLetters = _battle.getGameLetters();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_battle.gameMode.toString().split('.').last.toUpperCase()} Battle',
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Score Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    // ignore: deprecated_member_use
                    color: Colors.deepPurple.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$myLetters / $targetLetters',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          children: [
                            const Text(
                              'Opponent',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$opponentLetters / $targetLetters',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Turn indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _isMyTurn
                        // ignore: deprecated_member_use
                        ? Colors.green.withOpacity(0.1)
                        // ignore: deprecated_member_use
                        : Colors.orange.withOpacity(0.1),
                    child: Text(
                      _isMyTurn
                          ? "Your turn - Upload a trick!"
                          : "Opponent's turn",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isMyTurn ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),

                  // Set trick video display
                  if (_battle.setTrickVideoUrl != null)
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Set Trick',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              color: Colors.black,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Quick-Fire voting
                  if (_battle.verificationStatus ==
                      VerificationStatus.quickFireVoting)
                    _buildQuickFireVoting(),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isMyTurn && _battle.setTrickVideoUrl == null)
                          ElevatedButton.icon(
                            onPressed: _uploadSetTrick,
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Set Trick'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        if (!_isMyTurn &&
                            _battle.setTrickVideoUrl != null &&
                            _battle.verificationStatus ==
                                VerificationStatus.pending)
                          ElevatedButton.icon(
                            onPressed: _uploadAttempt,
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Attempt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
