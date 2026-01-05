import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../theme/admin_theme.dart';
import 'admin_stat_card.dart';
import 'admin_activity_item.dart';

class OverviewTab extends StatelessWidget {
  final Future<Map<String, dynamic>> analyticsData;
  final VoidCallback onRefresh;
  final VoidCallback onViewAllPosts;
  final String Function(DateTime) formatTimestamp;
  final Function(MapPost) onViewPostDetails;
  final Function(String) onViewUserProfile;
  final Function(MapPost) onEditPost;
  final Function(String) onDeletePost;

  const OverviewTab({
    super.key,
    required this.analyticsData,
    required this.onRefresh,
    required this.onViewAllPosts,
    required this.formatTimestamp,
    required this.onViewPostDetails,
    required this.onViewUserProfile,
    required this.onEditPost,
    required this.onDeletePost,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: analyticsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
          }

          final data = snapshot.data ?? {};
          final totalPosts = data['totalPosts'] ?? 0;
          final totalUpvotes = data['totalUpvotes'] ?? 0;
          final totalReports = data['totalReports'] ?? 0;
          final recentPosts = (data['recentPosts'] ?? []) as List<MapPost>;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              const Text(
                'SYSTEM_OVERVIEW',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.accent,
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  AdminStatCard(
                    label: 'Total Posts',
                    value: totalPosts.toString(),
                    icon: Icons.article_rounded,
                    color: Colors.blue,
                  ),
                  AdminStatCard(
                    label: 'Total Upvotes',
                    value: totalUpvotes.toString(),
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.orange,
                  ),
                  AdminStatCard(
                    label: 'Active Reports',
                    value: totalReports.toString(),
                    icon: Icons.warning_rounded,
                    color: AdminTheme.warning,
                  ),
                  AdminStatCard(
                    label: 'Avg Engagement',
                    value: data['avgUpvotesPerPost'] ?? '0',
                    icon: Icons.trending_up_rounded,
                    color: AdminTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT_ACTIVITY',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.accent,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAllPosts,
                    child: const Text('View All', style: TextStyle(color: AdminTheme.accent, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...recentPosts.map((post) => AdminActivityItem(
                post: post,
                formatTimestamp: formatTimestamp,
                onViewDetails: () => onViewPostDetails(post),
                onViewAuthor: () => onViewUserProfile(post.userId),
                onEdit: () => onEditPost(post),
                onDelete: () => post.id != null ? onDeletePost(post.id!) : null,
              )),
            ],
          );
        },
      ),
    );
  }
}
