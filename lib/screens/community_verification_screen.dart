import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/verification.dart';
import '../models/battle.dart';
import '../services/verification_service.dart';
import '../services/battle_service.dart';

class CommunityVerificationScreen extends StatefulWidget {
  const CommunityVerificationScreen({super.key});

  @override
  State<CommunityVerificationScreen> createState() => _CommunityVerificationScreenState();
}

class _CommunityVerificationScreenState extends State<CommunityVerificationScreen> {
  List<VerificationAttempt> _attempts = [];
  bool _isLoading = true;
  final _currentUser = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadVerificationQueue();
  }

  Future<void> _loadVerificationQueue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final attempts = await VerificationService.getCommunityVerificationQueue();
      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading verification queue: $e')),
        );
      }
    }
  }

  Future<void> _submitVote(String attemptId, VoteType voteType) async {
    if (_currentUser == null) return;

    try {
      await VerificationService.submitCommunityVote(
        attemptId: attemptId,
        userId: _currentUser.id,
        voteType: voteType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote submitted successfully!')),
        );
        _loadVerificationQueue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting vote: $e')),
        );
      }
    }
  }

  Widget _buildAttemptCard(VerificationAttempt attempt) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video placeholder
          Container(
            height: 200,
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attempt from Battle ${attempt.battleId.substring(0, 8)}...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submitted ${_formatDateTime(attempt.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Did the player land this trick?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitVote(attempt.id!, VoteType.land),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Land'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitVote(attempt.id!, VoteType.noLand),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text('No Land'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitVote(attempt.id!, VoteType.rebate),
                        icon: const Icon(Icons.replay, size: 20),
                        label: const Text('Rebate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<double>(
                  future: _getVoteWeight(),
                  builder: (context, snapshot) {
                    final voteWeight = snapshot.data ?? 0.5;
                    final percentage = (voteWeight * 100).toStringAsFixed(1);
                    return Text(
                      'Your vote influence: $percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<double> _getVoteWeight() async {
    if (_currentUser == null) return 0.5;
    final scores = await BattleService.getUserScores(_currentUser.id);
    return scores.voteWeight;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Verification'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No attempts to verify',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVerificationQueue,
                  child: ListView.builder(
                    itemCount: _attempts.length,
                    itemBuilder: (context, index) {
                      return _buildAttemptCard(_attempts[index]);
                    },
                  ),
                ),
    );
  }
}
