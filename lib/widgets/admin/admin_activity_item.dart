import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../theme/admin_theme.dart';

class AdminActivityItem extends StatelessWidget {
  final MapPost post;
  final String Function(DateTime) formatTimestamp;
  final VoidCallback onViewDetails;
  final VoidCallback onViewAuthor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AdminActivityItem({
    super.key,
    required this.post,
    required this.formatTimestamp,
    required this.onViewDetails,
    required this.onViewAuthor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AdminTheme.glassDecoration(opacity: 0.1),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdminTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              post.photoUrl != null ? Icons.image_rounded : Icons.notes_rounded,
              color: AdminTheme.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'by ${post.userName ?? "Anonymous"}',
                  style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    post.voteScore.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatTimestamp(post.createdAt),
                style: TextStyle(
                  color: AdminTheme.accent.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AdminTheme.textMuted, size: 20),
            color: AdminTheme.secondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'view':
                  onViewDetails();
                  break;
                case 'user':
                  onViewAuthor();
                  break;
                case 'edit':
                  onEdit();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, size: 18, color: AdminTheme.accent),
                    SizedBox(width: 12),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'user',
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 18, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('View Author'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Edit Post'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AdminTheme.error),
                    SizedBox(width: 12),
                    Text('Delete Post', style: TextStyle(color: AdminTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
