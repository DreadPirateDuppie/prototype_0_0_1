import 'package:flutter/material.dart';
import '../models/post.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/trick_history_screen.dart';
import '../services/supabase_service.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/vote_buttons.dart';
import '../utils/error_helper.dart';

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
  bool _isOwnPost = false;

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
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          // Refresh post data
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
        },
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Inappropriate content, Spam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                labelText: 'Details (Optional)',
                hintText: 'Provide more context...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ErrorHelper.showError(context, 'Please provide a reason');
                return;
              }

              try {
                await SupabaseService.reportPost(
                  postId: currentPost.id!,
                  reason: reasonController.text.trim(),
                  details: detailsController.text.trim().isEmpty
                      ? null
                      : detailsController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHelper.showError(context, 'Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report'),
          ),
        ],
      ),
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
              // Top buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // History button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrickHistoryScreen(spot: currentPost),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 20),
                    label: const Text('History'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),

              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.green,
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
                      currentPost.userName ?? 
                          (currentPost.userEmail != null 
                              ? currentPost.userEmail!.split('@')[0] 
                              : 'Unknown User'),
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

              // Image Carousel Placeholder
              Container(
                width: double.infinity,
                height: 150,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.view_carousel_rounded, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Image Carousel Space',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '(Coming Soon)',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Star Ratings Section
              StarRatingDisplay(
                popularityRating: currentPost.popularityRating,
                securityRating: currentPost.securityRating,
                qualityRating: currentPost.qualityRating,
              ),

              const SizedBox(height: 16),

              // Location info
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${currentPost.latitude.toStringAsFixed(4)}, ${currentPost.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Engagement buttons
              Row(
                children: [
                  // Vote Buttons
                  VoteButtons(
                    postId: currentPost.id!,
                    voteScore: currentPost.voteScore,
                    userVote: currentPost.userVote,
                    isOwnPost: _isOwnPost,
                    orientation: Axis.horizontal,
                    onVoteChanged: () async {
                      // Refresh post data
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
                    },
                  ),
                  const Spacer(),
                  // Report Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('Report'),
                    onPressed: () {
                      _showReportDialog();
                    },
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
