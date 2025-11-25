import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/spot_details_bottom_sheet.dart';
import '../screens/trick_history_screen.dart';
import 'star_rating_display.dart';
import 'vote_buttons.dart';
import 'mini_map_snapshot.dart';
import '../utils/error_helper.dart';

class PostCard extends StatefulWidget {
  final MapPost post;
  final VoidCallback? onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late MapPost currentPost;
  bool _isOwnPost = false;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _checkOwnership();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      currentPost = widget.post;
      _checkOwnership();
    }
  }

  void _checkOwnership() {
    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId != null) {
      setState(() {
        _isOwnPost = currentPost.userId == userId;
      });
    }
    _loadSavedStatus();
  }

  Future<void> _loadSavedStatus() async {
    if (currentPost.id == null) return;
    final saved = await SupabaseService.isPostSaved(currentPost.id!);
    if (mounted) {
      setState(() {
        _isSaved = saved;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (currentPost.id == null || _isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final newSavedStatus = await SupabaseService.toggleSavePost(currentPost.id!);
      if (mounted) {
        setState(() {
          _isSaved = newSavedStatus;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ErrorHelper.showError(context, 'Error saving post: $e');
      }
    }
  }

  Future<void> _sharePost() async {
    try {
      final rating = currentPost.popularityRating > 0 
          ? '${currentPost.popularityRating.toStringAsFixed(1)}/5 ⭐' 
          : 'Not rated yet';
      await Share.share(
        'Check out "${currentPost.title}" 🛹\n'
        'Rating: $rating\n'
        '${currentPost.description}\n\n'
        'Get the app: https://pushinn.app',
        subject: 'Amazing spot on Pushinn!',
      );
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Share failed: $e');
      }
    }
  }

  Future<void> _showEditDialog() async {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          widget.onPostUpdated?.call();
        },
      ),
    );
  }

  void _showDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SpotDetailsBottomSheet(
        post: currentPost,
        onClose: () => Navigator.pop(context),
        onPostUpdated: widget.onPostUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    const matrixSurface = Color(0xFF0D0D0D);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: const Color(0xFF000000), // Pure black background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen.withOpacity(0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: matrixGreen.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User Info & Edit Button
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: matrixGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF000000), // Pure black
                      child: Text(
                        (currentPost.userName?.isNotEmpty == true)
                            ? currentPost.userName![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: matrixGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPost.userName?.isNotEmpty == true
                            ? currentPost.userName!
                            : 'User',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      Text(
                        currentPost.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF00FF41), // Matrix Green
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isOwnPost)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showEditDialog,
                  ),
              ],
            ),
          ),

          // Image or Map Snapshot
          InkWell(
            onTap: _showDetails,
            child: currentPost.photoUrl != null
              ? Image.network(
                  currentPost.photoUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
                    );
                  },
                )
              : SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: MiniMapSnapshot(
                    latitude: currentPost.latitude,
                    longitude: currentPost.longitude,
                  ),
                ),
          ),
          
          // Description
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              currentPost.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Location & Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location: ${currentPost.latitude.toStringAsFixed(4)}, ${currentPost.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Posted: ${currentPost.createdAt.toString().substring(0, 16)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Ratings as horizontal chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                _buildRatingChip(
                  Icons.local_fire_department_rounded,
                  'Popularity',
                  currentPost.popularityRating,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildRatingChip(
                  Icons.shield_rounded,
                  'Security',
                  currentPost.securityRating,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildRatingChip(
                  Icons.star_rounded,
                  'Quality',
                  currentPost.qualityRating,
                  Colors.green,
                ),
              ],
            ),
          ),

          // Footer: Votes, History & Save
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                VoteButtons(
                  postId: currentPost.id!,
                  voteScore: currentPost.voteScore,
                  userVote: currentPost.userVote,
                  isOwnPost: _isOwnPost,
                  orientation: Axis.horizontal,
                  onVoteChanged: () {},
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrickHistoryScreen(spot: currentPost),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history, size: 18, color: Color(0xFF00FF41)),
                      label: const Text(
                        'History',
                        style: TextStyle(
                          color: Color(0xFF00FF41),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Color(0xFF00FF41)),
                      onPressed: _sharePost,
                      tooltip: 'Share',
                    ),
                    IconButton(
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: _isSaved ? const Color(0xFF00FF41) : null,
                      ),
                      onPressed: _isSaving ? null : _toggleSave,
                      tooltip: _isSaved ? 'Remove from saved' : 'Save',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRatingChip(IconData icon, String label, double rating, Color color) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: matrixGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: matrixGreen.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: matrixGreen.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: matrixGreen),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: matrixGreen,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: index < rating ? matrixGreen : matrixGreen.withOpacity(0.3),
                  size: 12,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
