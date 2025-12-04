import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class VoteButtons extends StatefulWidget {
  final String postId;
  final int voteScore;
  final int? userVote;
  final bool isOwnPost;
  final VoidCallback onVoteChanged;
  final Axis orientation;

  const VoteButtons({
    super.key,
    required this.postId,
    required this.voteScore,
    required this.userVote,
    required this.isOwnPost,
    required this.onVoteChanged,
    this.orientation = Axis.vertical,
  });

  @override
  State<VoteButtons> createState() => _VoteButtonsState();
}

class _VoteButtonsState extends State<VoteButtons> {
  bool _isVoting = false;

  Future<void> _vote(int voteType) async {
    if (widget.isOwnPost) {
      ErrorHelper.showError(context, 'You cannot vote on your own post');
      return;
    }

    if (_isVoting) return;

    setState(() => _isVoting = true);

    try {
      await SupabaseService.votePost(widget.postId, voteType);
      widget.onVoteChanged();
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to vote: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    final isUpvoted = widget.userVote == 1;
    final isDownvoted = widget.userVote == -1;

    return Flex(
      direction: widget.orientation,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote button
        IconButton(
          icon: Icon(
            isUpvoted ? Icons.arrow_drop_up : Icons.arrow_drop_up_outlined,
            size: 32,
          ),
          color: isUpvoted ? matrixGreen : matrixGreen.withOpacity(0.4),
          onPressed: _isVoting ? null : () => _vote(1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        // Vote score
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            widget.voteScore.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: matrixGreen,
            ),
          ),
        ),
        // Downvote button
        IconButton(
          icon: Icon(
            isDownvoted ? Icons.arrow_drop_down : Icons.arrow_drop_down_outlined,
            size: 32,
          ),
          color: isDownvoted ? matrixGreen : matrixGreen.withOpacity(0.4),
          onPressed: _isVoting ? null : () => _vote(-1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
