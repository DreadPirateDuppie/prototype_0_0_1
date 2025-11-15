import 'package:flutter/material.dart';
import '../models/post.dart';
import '../screens/edit_post_dialog.dart';
import '../services/supabase_service.dart';

class SpotDetailsBottomSheet extends StatefulWidget {
  final MapPost post;
  final VoidCallback onClose;
  final VoidCallback? onPostUpdated;

  const SpotDetailsBottomSheet({
    super.key,
    required this.post,
    required this.onClose,
    this.onPostUpdated,
  });

  @override
  State<SpotDetailsBottomSheet> createState() => _SpotDetailsBottomSheetState();
}

class _SpotDetailsBottomSheetState extends State<SpotDetailsBottomSheet> {
  late MapPost currentPost;
  bool _hasUserLiked = false;
  Map<String, int>? _userRating;

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _loadUserInteractionData();
  }

  Future<void> _loadUserInteractionData() async {
    final hasLiked = await SupabaseService.hasUserLikedPost(currentPost.id!);
    final userRating = await SupabaseService.getUserRatingForPost(currentPost.id!);
    if (mounted) {
      setState(() {
        _hasUserLiked = hasLiked;
        _userRating = userRating;
      });
    }
  }

  bool get _isOwnPost {
    final user = SupabaseService.getCurrentUser();
    return user != null && user.id == currentPost.userId;
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          // Refresh the post data
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
              widget.onPostUpdated?.call();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            }
          } catch (e) {
            // Silently fail
          }
        },
      ),
    );
  }

  Future<void> _toggleLike() async {
    final liked = await SupabaseService.likeMapPost(currentPost.id!);
    if (mounted) {
      setState(() {
        _hasUserLiked = liked;
      });
      // Refresh post data to get updated like count
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
          widget.onPostUpdated?.call();
        }
      } catch (e) {
        // Silently fail
      }
    }
  }

  void _showRatingDialog() {
    int popularityRating = _userRating?['popularity'] ?? 3;
    int securityRating = _userRating?['security'] ?? 3;
    int qualityRating = _userRating?['quality'] ?? 3;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setState) => AlertDialog(
          title: const Text('Rate this Spot'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRatingRow('Rating', popularityRating, (value) {
                    setState(() => popularityRating = value);
                  }),
                  const SizedBox(height: 16),
                  _buildRatingRow('Security', securityRating, (value) {
                    setState(() => securityRating = value);
                  }),
                  const SizedBox(height: 16),
                  _buildRatingRow('Quality', qualityRating, (value) {
                    setState(() => qualityRating = value);
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await SupabaseService.rateMapPost(
                  postId: currentPost.id!,
                  popularityRating: popularityRating,
                  securityRating: securityRating,
                  qualityRating: qualityRating,
                );
                if (mounted) {
                  await _loadUserInteractionData();
                  // Refresh post data to get updated ratings
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
                      widget.onPostUpdated?.call();
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  } catch (e) {
                    // Silently fail
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  }
                }
              },
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(String label, int currentRating, Function(int) onChanged) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < currentRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                ),
                onPressed: () => onChanged(index + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text('$currentRating/5'),
        ),
      ],
    );
  }

  Widget _buildStarRating(double rating, String label) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 18,
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '${rating.toStringAsFixed(1)}/5.0',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ),

              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      (currentPost.userName?.isNotEmpty ?? false)
                          ? currentPost.userName![0].toUpperCase()
                          : (currentPost.userEmail?.isNotEmpty ?? false)
                              ? currentPost.userEmail![0].toUpperCase()
                              : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentPost.userName ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                currentPost.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Photo if available
              if (currentPost.photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    currentPost.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description
              Text(
                currentPost.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Star Ratings Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Spot Ratings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStarRating(
                          currentPost.popularityRating,
                          'Rating',
                        ),
                        _buildStarRating(
                          currentPost.securityRating,
                          'Security',
                        ),
                        _buildStarRating(
                          currentPost.qualityRating,
                          'Quality',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Location info
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${currentPost.latitude.toStringAsFixed(4)}, ${currentPost.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date info
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    currentPost.createdAt.toString().substring(0, 16),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Engagement buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.favorite,
                        color: _hasUserLiked ? Colors.red : null,
                      ),
                      label: Text('${currentPost.likes} Likes'),
                      onPressed: _toggleLike,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star),
                      label: const Text('Rate'),
                      onPressed: _showRatingDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              if (_isOwnPost) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Post'),
                  onPressed: _showEditDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
