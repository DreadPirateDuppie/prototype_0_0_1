import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import 'admin_metric_row.dart';
import 'admin_analytic_row.dart';

class AnalyticsTab extends StatelessWidget {
  final Future<Map<String, dynamic>> analyticsData;

  const AnalyticsTab({
    super.key,
    required this.analyticsData,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: analyticsData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
        }

        final data = snapshot.data ?? {};
        final postTypes = (data['postTypes'] as Map<String, int>?) ?? {};
        final totalPosts = data['totalPosts'] ?? 1;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'DATA_INSIGHTS',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: AdminTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            _buildGrowthSection(data),
            const SizedBox(height: 24),
            _buildEngagementSection(data),
            const SizedBox(height: 24),
            _buildRetentionSection(data),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminTheme.glassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content Distribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...postTypes.entries.map((entry) {
                    final percentage = entry.value / totalPosts;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AdminAnalyticRow(
                        label: entry.key.toUpperCase(),
                        value: entry.value.toString(),
                        percentage: percentage,
                        color: entry.key == 'video' ? Colors.purple : Colors.blue,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrowthSection(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Growth',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          AdminMetricRow(
            label: 'Total Users',
            value: (data['totalUsers'] ?? 0).toString(),
            icon: Icons.people_rounded,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          AdminMetricRow(
            label: 'New Users (7d)',
            value: '+${data['newUsersLastWeek'] ?? 0}',
            icon: Icons.person_add_rounded,
            color: AdminTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementSection(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engagement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          AdminMetricRow(
            label: 'New Posts (7d)',
            value: (data['newPostsLastWeek'] ?? 0).toString(),
            icon: Icons.post_add_rounded,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          AdminMetricRow(
            label: 'Avg Upvotes/Post',
            value: data['avgUpvotesPerPost'] ?? '0',
            icon: Icons.favorite_rounded,
            color: AdminTheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionSection(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Retention',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          AdminMetricRow(
            label: 'Active Users',
            value: (data['activeUsers'] ?? 0).toString(),
            icon: Icons.bolt_rounded,
            color: Colors.yellow,
          ),
          const SizedBox(height: 16),
          AdminMetricRow(
            label: 'Retention Rate',
            value: '${data['retentionRate'] ?? 0}%',
            icon: Icons.loop_rounded,
            color: Colors.cyan,
          ),
        ],
      ),
    );
  }
}
