import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/spot_details_screen.dart';
import '../screens/user_profile_screen.dart';
import 'vote_buttons.dart';
import 'mini_map_snapshot.dart';
import 'video_player_widget.dart';
import 'verified_badge.dart';
import '../config/theme_config.dart';

class PostCard extends StatefulWidget {
  final MapPost post;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late MapPost currentPost;
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isOwnPost = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _checkOwnership();
    _loadSavedStatus();
  }

  void _checkOwnership() {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _isOwnPost = currentPost.userId == user.id;
        });
      }
    }
  }

  Future<void> _loadSavedStatus() async {
    try {
      if (currentPost.id == null) return;
      final isSaved = await SupabaseService.isPostSaved(currentPost.id!);
      if (mounted) {
        setState(() => _isSaved = isSaved);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    try {
      if (currentPost.id == null) return;
      setState(() => _isSaving = true);
      
      if (_isSaved) {
        await SupabaseService.unsavePost(currentPost.id!);
        if (mounted) setState(() => _isSaved = false);
      } else {
        await SupabaseService.savePost(currentPost.id!);
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _sharePost() {
    // ignore: deprecated_member_use
    Share.share(
      'Check out this spot on Pushinn: ${currentPost.title}\n\n${currentPost.description}',
      subject: 'Pushinn Spot: ${currentPost.title}',
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          if (widget.onDelete != null) {
             widget.onDelete!();
          }
          // Also refresh local state
          try {
             final posts = await SupabaseService.getAllMapPostsWithVotes();
             final updated = posts.firstWhere((p) => p.id == currentPost.id, orElse: () => currentPost);
             if (mounted) setState(() => currentPost = updated);
          } catch (e) {
            // ignore: empty_catches
          }
        },
      ),
    );
  }

  void _showDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotDetailsScreen(post: currentPost),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black, // Pure black for neon contrast
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: matrixGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: matrixGreen.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          onTap: _showDetails,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header: User Info & Title
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: currentPost.userId),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ThemeColors.neonGreen, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColors.neonGreen.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: ThemeColors.neonGreen.withValues(alpha: 0.1),
                        backgroundImage: currentPost.avatarUrl != null
                            ? NetworkImage(currentPost.avatarUrl!)
                            : null,
                        child: currentPost.avatarUrl == null
                            ? Text(
                                (currentPost.userName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: ThemeColors.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(userId: currentPost.userId),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                currentPost.userName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              if (currentPost.isUserVerified)
                                const VerifiedBadge(),
                            ],
                          ),
                        ),
                        Text(
                          currentPost.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ThemeColors.neonGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isOwnPost)
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onPressed: _showEditDialog,
                    ),
                ],
              ),
            ),

            // Image or Map Snapshot
            currentPost.videoUrl != null
              ? VideoPlayerWidget(videoUrl: currentPost.videoUrl!)
              : currentPost.photoUrls.isNotEmpty
                ? _buildImageCarousel()
                : SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: MiniMapSnapshot(
                      latitude: currentPost.latitude ?? 0.0,
                      longitude: currentPost.longitude ?? 0.0,
                    ),
                  ),
            
            // Description
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                currentPost.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),

            // Location & Date (Conditional: Only for maps)
            if (currentPost.latitude != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location: ${currentPost.latitude!.toStringAsFixed(4)}, ${currentPost.longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TIMESTAMP://' + currentPost.createdAt.toString().substring(2, 4) + '.' + 
                      currentPost.createdAt.toString().substring(5, 7) + '.' + 
                      currentPost.createdAt.toString().substring(8, 10) + '.' +
                      currentPost.createdAt.toString().substring(11, 13) + 
                      currentPost.createdAt.toString().substring(14, 16),
                      style: TextStyle(
                        fontSize: 9,
                        color: matrixGreen.withValues(alpha: 0.4),
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

            // Ratings (Conditional: Only for maps)
            if (currentPost.latitude != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildRatingChip(
                      Icons.local_fire_department_rounded,
                      'Popularity',
                      currentPost.popularityRating,
                    ),
                    const SizedBox(width: 8),
                    _buildRatingChip(
                      Icons.shield_rounded,
                      'Security',
                      currentPost.securityRating,
                    ),
                    const SizedBox(width: 8),
                    _buildRatingChip(
                      Icons.star_rounded,
                      'Quality',
                      currentPost.qualityRating,
                    ),
                  ],
                ),
              ),

            // Footer: Votes & Share/Bookmark
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
                    onVoteChanged: () async {
                      try {
                        final allPosts = await SupabaseService.getAllMapPostsWithVotes();
                        final updatedPost = allPosts.firstWhere(
                          (p) => p.id == currentPost.id,
                          orElse: () => currentPost,
                        );
                        if (mounted) setState(() => currentPost = updatedPost);
                      } catch (e) {
                        // ignore: empty_catches
                      }
                    },
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showDetails,
                        icon: const Icon(Icons.history, size: 18, color: ThemeColors.neonGreen),
                        label: const Text(
                          'History',
                          style: TextStyle(
                            color: ThemeColors.neonGreen,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: matrixGreen),
                        onPressed: _sharePost,
                      ),
                      IconButton(
                        icon: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSaved ? matrixGreen : Colors.white70,
                        ),
                        onPressed: _toggleSave,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildImageCarousel() {
    const matrixGreen = Color(0xFF00FF41);
    
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: currentPost.photoUrls.length,
            onPageChanged: (index) {
              if (mounted) setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                currentPost.photoUrls[index],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey[900],
                  child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.white54)),
                ),
              );
            },
          ),
          if (currentPost.photoUrls.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  currentPost.photoUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == index
                          ? matrixGreen
                          : matrixGreen.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingChip(IconData icon, String label, double rating) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: matrixGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: matrixGreen.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: ThemeColors.neonGreen),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ThemeColors.neonGreen,
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
                  color: index < rating ? ThemeColors.neonGreen : ThemeColors.neonGreen.withValues(alpha: 0.3),
                  size: 10,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
