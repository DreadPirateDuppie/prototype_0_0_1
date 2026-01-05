import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/post.dart';
import '../../theme/admin_theme.dart';
import '../../services/supabase_service.dart';
import 'admin_empty_state.dart';
import 'admin_error_state.dart';
import 'admin_detail_row.dart';

class ReportsTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> reportsFuture;
  final Function(MapPost) onViewPostDetails;
  final Function(String) onDismissReport;
  final Function(String, String?) onDeletePost;

  const ReportsTab({
    super.key,
    required this.reportsFuture,
    required this.onViewPostDetails,
    required this.onDismissReport,
    required this.onDeletePost,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> with TickerProviderStateMixin {
  late TabController _reportsTabController;

  @override
  void initState() {
    super.initState();
    _reportsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _reportsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            color: AdminTheme.secondary,
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: TabBar(
            controller: _reportsTabController,
            indicatorColor: AdminTheme.accent,
            labelColor: AdminTheme.accent,
            unselectedLabelColor: AdminTheme.textMuted,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'POST_REPORTS'),
              Tab(text: 'ERROR_LOGS'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _reportsTabController,
            children: [
              _buildPostReportsSection(),
              _buildErrorLogsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostReportsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.verified_user_rounded,
            title: 'No pending reports',
            subtitle: 'All content is currently within guidelines.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final post = report['map_posts'] as Map<String, dynamic>?;
            final reporter = report['user_profiles'] as Map<String, dynamic>?;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: AdminTheme.glassDecoration(),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: AdminTheme.warning.withValues(alpha: 0.1),
                  child: const Icon(Icons.report_problem_rounded, color: AdminTheme.warning, size: 20),
                ),
                title: Text(
                  post?['title'] ?? 'Untitled Post',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Reported by ${reporter?['username'] ?? "Anonymous"}',
                  style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminDetailRow(label: 'Reason', value: report['reason'] ?? 'No reason provided'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                if (post != null) {
                                  widget.onViewPostDetails(MapPost.fromMap(post));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Post data not available')),
                                  );
                                }
                              },
                              child: const Text('View Post', style: TextStyle(color: AdminTheme.accent)),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => widget.onDismissReport(report['id']),
                              child: const Text('Dismiss', style: TextStyle(color: AdminTheme.textMuted)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => widget.onDeletePost(report['post_id'], report['id']),
                              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
                              child: const Text('Delete Post'),
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
    );
  }

  Widget _buildErrorLogsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getErrorLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
        }

        if (snapshot.hasError) {
          return AdminErrorState(title: 'Error loading logs', error: snapshot.error.toString());
        }

        final errorLogs = snapshot.data ?? [];

        if (errorLogs.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No errors logged',
            subtitle: 'System is running smoothly.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: errorLogs.length,
            itemBuilder: (context, index) {
              final log = errorLogs[index];
              final message = log['error_message'] as String? ?? 'Unknown error';
              final screen = log['screen_name'] as String?;
              final userProfiles = log['user_profiles'] as Map<String, dynamic>?;
              final username = userProfiles?['username'] as String? ?? 
                               userProfiles?['display_name'] as String? ?? 
                               'Anonymous';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AdminTheme.glassDecoration(opacity: 0.1),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AdminTheme.error.withValues(alpha: 0.1),
                    child: const Icon(Icons.bug_report_rounded, color: AdminTheme.error, size: 20),
                  ),
                  title: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 12, color: AdminTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(username, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
                          if (screen != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.laptop_chromebook_rounded, size: 12, color: AdminTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(screen, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: AdminTheme.accent,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error copied to clipboard')),
                      );
                    },
                  ),
                  onTap: () => _showErrorDetailDialog(log),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showErrorDetailDialog(Map<String, dynamic> log) async {
    final message = log['error_message'] as String? ?? 'Unknown error';
    final stack = log['error_stack'] as String?;
    final screen = log['screen_name'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
        ),
        title: const Text(
          'ERROR_DETAILS',
          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.accent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminDetailRow(label: 'Message', value: message),
              const SizedBox(height: 16),
              if (screen != null) ...[
                AdminDetailRow(label: 'Screen', value: screen),
                const SizedBox(height: 16),
              ],
              if (stack != null) ...[
                const Text(
                  'STACK_TRACE',
                  style: TextStyle(fontSize: 10, color: AdminTheme.accent, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stack,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminTheme.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Message: $message\n\nStack: $stack'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Full error details copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy All'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}
