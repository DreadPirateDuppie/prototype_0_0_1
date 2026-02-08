import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/vote_buttons.dart';
import 'edit_post_dialog.dart';
import '../widgets/video_player_widget.dart';
import 'user_profile_screen.dart';
import '../widgets/verified_badge.dart';
import '../widgets/hud_avatar.dart';

class PostDetailScreen extends StatefulWidget {
  final MapPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late MapPost currentPost;
  bool _isOwnPost = false;
  int _currentImageIndex = 0;

  // Matrix theme colors
  static const Color matrixGreen = Color(0xFF00FF41);

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _checkOwnership();
  }

  void _checkOwnership() {
    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId != null) {
      setState(() {
        _isOwnPost = currentPost.userId == userId;
      });
    }
  }

  Future<void> _showEditDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          try {
            final updatedPosts = await SupabaseService.getAllMapPosts();
            final updated = updatedPosts.firstWhere(
              (p) => p.id == currentPost.id,
              orElse: () => currentPost,
            );
            if (mounted) {
              setState(() {
                currentPost = updated;
              });
            }
          } catch (e) {
            // Silently fail
          }
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrixBlack = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: matrixGreen),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isOwnPost)
            IconButton(
              icon: const Icon(Icons.edit, color: matrixGreen),
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. User Info (Top)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: currentPost.userId,
                            username: currentPost.userName,
                            avatarUrl: currentPost.avatarUrl,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        HudAvatar(
                          radius: 18,
                          avatarUrl: currentPost.avatarUrl,
                          username: currentPost.userName,
                          showScanline: false,
                          neonColor: matrixGreen,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  currentPost.userName ?? 'Anonymous',
                                  style: const TextStyle(
                                    color: matrixGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (currentPost.isUserVerified)
                                  const VerifiedBadge(),
                              ],
                            ),
                             Text(
                               'TIMESTAMP // ' + currentPost.createdAt.toString().substring(2, 4) + '.' + 
                               currentPost.createdAt.toString().substring(5, 7) + '.' + 
                               currentPost.createdAt.toString().substring(8, 10),
                               style: TextStyle(
                                 color: matrixGreen.withValues(alpha: 0.4),
                                 fontSize: 9,
                                 fontFamily: 'monospace',
                                 letterSpacing: 2,
                               ),
                             ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Title (Below User Info)
                  Text(
                    currentPost.title,
                    style: const TextStyle(
                      color: matrixGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 3. Media Section (Middle)
            if (currentPost.videoUrl != null)
              VideoPlayerWidget(videoUrl: currentPost.videoUrl!)
            else if (currentPost.photoUrls.isNotEmpty)
              _buildImageCarousel()
            else
              const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4. Description (Below Media)
                  Text(
                    currentPost.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Interaction Bar (Bottom)
                  Row(
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
                            final updated = allPosts.firstWhere(
                              (p) => p.id == currentPost.id,
                              orElse: () => currentPost,
                            );
                            if (mounted) {
                              setState(() {
                                currentPost = updated;
                              });
                            }
                          } catch (e) {
                            // Silently fail
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: matrixGreen),
                        onPressed: () {
                          // Share logic
                        },
                      ),
                    ],
                  ),
                  
                  // 6. Tags & Category (Only for Spots)
                  if (currentPost.latitude != null) ...[
                    const SizedBox(height: 24),
                    if (currentPost.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentPost.tags.map((tag) => _buildTag(tag)).toList(),
                      ),
                    const SizedBox(height: 12),
                    _buildCategoryChip(currentPost.category),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: currentPost.photoUrls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                currentPost.photoUrls[index],
                fit: BoxFit.cover,
              );
            },
          ),
          if (currentPost.photoUrls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  currentPost.photoUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
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

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: matrixGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(color: matrixGreen, fontSize: 12),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
