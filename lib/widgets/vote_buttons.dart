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
  late int _currentVoteScore;
  late int? _currentUserVote;
  bool _hasLocalChanges = false; // Track if we've made optimistic updates

  @override
  void initState() {
    super.initState();
    _currentVoteScore = widget.voteScore;
    _currentUserVote = widget.userVote;
  }

  @override
  void didUpdateWidget(VoteButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from parent if:
    // 1. We're not currently voting
    // 2. We haven't made local changes, OR the server data is different from what we have
    if (!_isVoting && !_hasLocalChanges) {
      if (widget.voteScore != _currentVoteScore) {
        _currentVoteScore = widget.voteScore;
      }
      if (widget.userVote != _currentUserVote) {
        _currentUserVote = widget.userVote;
      }
    }
  }

  Future<void> _vote(int voteType) async {
    if (widget.isOwnPost) {
      ErrorHelper.showError(context, 'You cannot vote on your own post');
      return;
    }

    if (_isVoting) return;

    // Optimistic update - update UI immediately
    setState(() {
      _isVoting = true;
      _hasLocalChanges = true; // Mark that we've made changes
      // Treat 0 as null (no vote)
      final oldVote = _currentUserVote == 0 ? null : _currentUserVote;
      
      if (oldVote == voteType) {
        // Removing vote (clicking same button again)
        _currentUserVote = null;
        _currentVoteScore = _currentVoteScore - voteType;
      } else if (oldVote != null) {
        // Changing vote (from upvote to downvote or vice versa)
        _currentUserVote = voteType;
        _currentVoteScore = _currentVoteScore - oldVote + voteType;
      } else {
        // New vote (first time voting)
        _currentUserVote = voteType;
        _currentVoteScore = _currentVoteScore + voteType;
      }
    });

    try {
      // Sync with server in background
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        await SupabaseService.votePost(
          postId: widget.postId,
          voterId: user.id,
          voteType: voteType,
        );
      }
      
      // Success - trigger refresh to get real vote count from database
      widget.onVoteChanged();
      
      // Clear local changes flag quickly so we can sync with server
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _hasLocalChanges = false);
        }
      });
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _currentVoteScore = widget.voteScore;
          _currentUserVote = widget.userVote;
          _hasLocalChanges = false;
        });
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
    final isUpvoted = _currentUserVote == 1;
    final isDownvoted = _currentUserVote == -1;

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
          color: isUpvoted ? matrixGreen : matrixGreen.withValues(alpha: 0.4),
          onPressed: _isVoting ? null : () => _vote(1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        // Vote score
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            _currentVoteScore.toString(),
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
          color: isDownvoted ? matrixGreen : matrixGreen.withValues(alpha: 0.4),
          onPressed: _isVoting ? null : () => _vote(-1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
