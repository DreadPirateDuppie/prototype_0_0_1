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

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
  }

  bool get _isOwnPost {
    final user = SupabaseService.getCurrentUser();
    return user != null && user.id == currentPost.userId;
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          // Refresh the post data
          try {
            final updatedPosts = await SupabaseService.getAllMapPosts();
            final updated = updatedPosts.firstWhere(
              (p) => p.id == currentPost.id,
              orElse: () => currentPost,
            );
            setState(() {
              currentPost = updated;
            });
            widget.onPostUpdated?.call();
            Navigator.of(context).pop();
          } catch (e) {
            // Silently fail
          }
        },
      ),
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
                          'Popularity',
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
                      icon: const Icon(Icons.favorite),
                      label: Text('${currentPost.likes} Likes'),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.comment),
                      label: const Text('Comment'),
                      onPressed: () {},
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
