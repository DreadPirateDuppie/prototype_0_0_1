import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../theme/admin_theme.dart';
import 'admin_empty_state.dart';
import 'admin_error_state.dart';

class VerificationTab extends StatelessWidget {
  final Future<List<MapPost>> unverifiedPostsFuture;
  final VoidCallback onRefresh;
  final String Function(DateTime) formatTimestamp;
  final Function(MapPost) onViewPostDetails;
  final Function(String) onVerifyPost;
  final Function(String) onDeletePost;

  const VerificationTab({
    super.key,
    required this.unverifiedPostsFuture,
    required this.onRefresh,
    required this.formatTimestamp,
    required this.onViewPostDetails,
    required this.onVerifyPost,
    required this.onDeletePost,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<MapPost>>(
        future: unverifiedPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
          }

          if (snapshot.hasError) {
            return AdminErrorState(title: 'Error loading unverified posts', error: snapshot.error.toString());
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.verified_rounded,
              title: 'No pending verifications',
              subtitle: 'All spots have been reviewed.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: AdminTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AdminTheme.accent.withValues(alpha: 0.1),
                        child: const Icon(Icons.location_on_rounded, color: AdminTheme.accent, size: 20),
                      ),
                      title: Text(
                        post.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'by ${post.userName ?? "Anonymous"} • ${formatTimestamp(post.createdAt)}',
                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility_rounded, color: AdminTheme.accent),
                        onPressed: () => onViewPostDetails(post),
                      ),
                    ),
                    if (post.photoUrl != null && post.photoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post.photoUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(child: Icon(Icons.broken_image_rounded)),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => post.id != null ? onVerifyPost(post.id!) : null,
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('VERIFY & AWARD 5 PTS'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => post.id != null ? onDeletePost(post.id!) : null,
                                icon: const Icon(Icons.delete_outline_rounded, color: AdminTheme.error),
                                tooltip: 'Reject & Delete',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
