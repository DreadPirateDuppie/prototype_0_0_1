import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import 'admin_badge.dart';
import 'admin_empty_state.dart';
import 'admin_error_state.dart';

class UsersTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> usersFuture;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onShowUserDetail;

  const UsersTab({
    super.key,
    required this.usersFuture,
    required this.onRefresh,
    required this.onShowUserDetail,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
          }

          if (snapshot.hasError) {
            return AdminErrorState(title: 'Error loading users', error: snapshot.error.toString());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No users found',
              subtitle: 'Your community is just getting started.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'USER_DIRECTORY',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.accent,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${users.length} TOTAL',
                      style: const TextStyle(color: AdminTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...users.map((user) => _buildUserCard(user)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? 'Unknown User';
    final email = user['email'] as String? ?? 'No email';
    final isAdmin = user['is_admin'] == true;
    final isVerified = user['is_verified'] == true;
    final isBanned = user['is_banned'] == true;
    final points = user['points'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AdminTheme.glassDecoration(opacity: 0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isAdmin ? AdminTheme.accent.withValues(alpha: 0.2) : Colors.white10,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isAdmin ? AdminTheme.accent : AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isBanned)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AdminTheme.error, shape: BoxShape.circle),
                  child: const Icon(Icons.block_flipped, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBanned ? AdminTheme.textMuted : AdminTheme.textPrimary,
                  decoration: isBanned ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAdmin) const AdminBadge(label: 'ADMIN', color: AdminTheme.accent),
            if (isVerified) const AdminBadge(label: 'VERIFIED', color: Colors.blue),
            if (isBanned) const AdminBadge(label: 'BANNED', color: AdminTheme.error),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${points.toString()} PTS',
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AdminTheme.textMuted),
        onTap: () => onShowUserDetail(user),
      ),
    );
  }
}
