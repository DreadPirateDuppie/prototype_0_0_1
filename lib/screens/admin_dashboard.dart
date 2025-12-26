import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/admin_service.dart';
import '../models/post.dart';
import '../utils/error_helper.dart';

class AdminTheme {
  static const Color primary = Color(0xFF000000);
  static const Color secondary = Color(0xFF0A0A0A);
  static const Color accent = Color(0xFF00FF41);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;

  static BoxDecoration glassDecoration({Color? color, double opacity = 0.3}) {
    return BoxDecoration(
      color: (color ?? surface).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: accent.withValues(alpha: 0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _reportsTabController;
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  late Future<List<MapPost>> _allPostsFuture;
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late Future<Map<String, dynamic>> _analyticsData;
  final _adminService = AdminService();
  bool _isCheckingAuth = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _reportsTabController = TabController(length: 2, vsync: this);
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    try {
      final isAdmin = await SupabaseService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAuthorized = isAdmin;
          _isCheckingAuth = false;
        });

        if (!isAdmin) {
          // Not authorized, show error and go back
          ErrorHelper.showError(context, 'Access denied: Admin privileges required');
          Navigator.of(context).pop();
        } else {
          // Authorized, load data
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthorized = false;
          _isCheckingAuth = false;
        });
        ErrorHelper.showError(context, 'Authorization check failed');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportsTabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _reportsFuture = SupabaseService.getReportedPosts();
      _allPostsFuture = SupabaseService.getAllMapPostsWithVotes();
      _usersFuture = _adminService.getAllUsers(limit: 100);
      _analyticsData = _loadAnalytics();
    });
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    try {
      final posts = await SupabaseService.getAllMapPostsWithVotes();
      final reports = await SupabaseService.getReportedPosts();
      final users = await _adminService.getAllUsers();
      
      final totalPosts = posts.length;
      final totalUpvotes = posts.fold<int>(0, (sum, post) => sum + post.voteScore);
      final totalReports = reports.length;
      final avgUpvotesPerPost = totalPosts > 0
          ? (totalUpvotes / totalPosts).toStringAsFixed(1)
          : '0';

      // Get posts with photos
      final postsWithPhotos = posts
          .where((p) => p.photoUrl != null && p.photoUrl!.isNotEmpty)
          .length;

      final totalUsers = users.length;

      // Calculate growth (new users in last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final newUsersLastWeek = users.where((u) {
        final createdAt = DateTime.tryParse(u['created_at'] ?? '');
        return createdAt != null && createdAt.isAfter(sevenDaysAgo);
      }).length;

      // Calculate engagement trends (posts in last 7 days)
      final newPostsLastWeek = posts.where((p) => p.createdAt.isAfter(sevenDaysAgo)).length;
      
      // Calculate retention (active users - users who have points or posts)
      final activeUsers = users.where((u) {
        final hasPoints = (u['points'] as num? ?? 0) > 0;
        final userId = u['id'];
        final hasPosts = posts.any((p) => p.userId == userId);
        return hasPoints || hasPosts;
      }).length;

      final retentionRate = totalUsers > 0 ? (activeUsers / totalUsers * 100).toStringAsFixed(1) : '0';

      // Get post types distribution
      final postTypes = <String, int>{};
      for (var post in posts) {
        final type = post.photoUrl != null ? 'video' : 'text';
        postTypes[type] = (postTypes[type] ?? 0) + 1;
      }

      return {
        'totalPosts': totalPosts,
        'totalUpvotes': totalUpvotes,
        'totalReports': totalReports,
        'avgUpvotesPerPost': avgUpvotesPerPost,
        'postsWithPhotos': postsWithPhotos,
        'recentPosts': posts.take(5).toList(),
        'totalUsers': totalUsers,
        'newUsersLastWeek': newUsersLastWeek,
        'newPostsLastWeek': newPostsLastWeek,
        'activeUsers': activeUsers,
        'retentionRate': retentionRate,
        'postTypes': postTypes,
      };
    } catch (e) {
      return {
        'totalPosts': 0,
        'totalUpvotes': 0,
        'totalReports': 0,
        'avgUpvotesPerPost': '0',
        'postsWithPhotos': 0,
        'recentPosts': <MapPost>[],
      };
    }
  }

  Future<void> _deletePost(String postId, [String? reportId]) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.deleteMapPost(postId);
        if (reportId != null) {
          await SupabaseService.dismissReport(reportId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error deleting post: $e');
        }
      }
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await SupabaseService.dismissReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error dismissing report: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking authorization
    if (_isCheckingAuth) {
      return Scaffold(
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking authorization...'),
            ],
          ),
        ),
      );
    }

    // Show dashboard if authorized
    if (_isAuthorized) {
      return Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AdminTheme.primary,
          colorScheme: const ColorScheme.dark(
            primary: AdminTheme.accent,
            secondary: AdminTheme.accent,
            surface: AdminTheme.surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AdminTheme.secondary,
            elevation: 0,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'ADMIN_CONSOLE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AdminTheme.accent,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AdminTheme.accent),
                onPressed: _loadData,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AdminTheme.accent,
              labelColor: AdminTheme.accent,
              unselectedLabelColor: AdminTheme.textMuted,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.grid_view_rounded), text: 'Overview'),
                Tab(icon: Icon(Icons.insights_rounded), text: 'Analytics'),
                Tab(icon: Icon(Icons.gavel_rounded), text: 'Moderation'),
                Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
              ],
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  AdminTheme.accent.withValues(alpha: 0.05),
                  AdminTheme.primary,
                ],
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAnalyticsTab(),
                _buildReportsTab(),
                _buildUsersTab(),
              ],
            ),
          ),
        ),
      );
    }

    // Should not reach here, but just in case
    return Scaffold(
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 80, color: Colors.red),
            SizedBox(height: 16),
            Text('Access denied: Admin privileges required'),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsData,
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
                  _buildStatCard(
                    'Total Posts',
                    totalPosts.toString(),
                    Icons.article_rounded,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Total Upvotes',
                    totalUpvotes.toString(),
                    Icons.arrow_upward_rounded,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Active Reports',
                    totalReports.toString(),
                    Icons.warning_rounded,
                    AdminTheme.warning,
                  ),
                  _buildStatCard(
                    'Avg Engagement',
                    data['avgUpvotesPerPost'] ?? '0',
                    Icons.trending_up_rounded,
                    AdminTheme.success,
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
                    onPressed: () => _showAllPostsDialog(),
                    child: const Text('View All', style: TextStyle(color: AdminTheme.accent, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...recentPosts.map((post) => _buildActivityItem(post)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(MapPost post) {
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
                _formatTimestamp(post.createdAt),
                style: TextStyle(color: AdminTheme.accent.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'monospace'),
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
                  _viewPostDetails(post);
                  break;
                case 'user':
                  _viewUserProfile(post.userId);
                  break;
                case 'delete':
                  if (post.id != null) {
                    _deletePost(post.id!);
                  }
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

  Future<void> _showAllPostsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AdminTheme.primary,
        child: Column(
          children: [
            AppBar(
              backgroundColor: AdminTheme.secondary,
              title: const Text('ALL_POSTS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    setState(() {
                      _allPostsFuture = SupabaseService.getAllMapPostsWithVotes();
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<MapPost>>(
                future: _allPostsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState('Error loading posts', snapshot.error.toString());
                  }
                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return _buildEmptyState(Icons.map_rounded, 'No posts found', 'Start by creating some content.');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => _buildActivityItem(posts[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPostDetails(MapPost post) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A), // Solid dark background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.4)), // More visible border
        ),
        title: Row(
          children: [
            const Icon(Icons.description_rounded, color: AdminTheme.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                post.title.toUpperCase(),
                style: const TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.photoUrl != null && post.photoUrl!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.photoUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: AdminTheme.textMuted, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              _buildDetailRow('Author', post.userName ?? "Anonymous"),
              const SizedBox(height: 8),
              _buildDetailRow('Category', post.category),
              const SizedBox(height: 8),
              _buildDetailRow('Upvotes', post.voteScore.toString()),
              const SizedBox(height: 8),
              _buildDetailRow('Created', post.createdAt.toLocal().toString().split('.')[0]),
              const Divider(color: Colors.white10, height: 24),
              const Text(
                'DESCRIPTION',
                style: TextStyle(fontSize: 10, color: AdminTheme.textMuted, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                post.description.isEmpty ? 'No description provided' : post.description,
                style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 14),
              ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'TAGS',
                  style: TextStyle(fontSize: 10, color: AdminTheme.textMuted, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(color: AdminTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: AdminTheme.textMuted, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  void _viewUserProfile(String userId) {
    // Find the user in our list and show the detail dialog
    _usersFuture.then((users) {
      if (!mounted) return;
      final user = users.firstWhere((u) => u['id'] == userId, orElse: () => {});
      if (user.isNotEmpty) {
        _showUserDetailDialog(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found in current list')),
        );
      }
    });
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: AdminTheme.glassDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 80,
                color: color.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: AdminTheme.textMuted,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsData,
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
                      child: _buildAnalyticRow(
                        entry.key.toUpperCase(),
                        entry.value.toString(),
                        percentage,
                        entry.key == 'video' ? Colors.purple : Colors.blue,
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
          _buildMetricRow('Total Users', data['totalUsers']?.toString() ?? '0', Icons.people_rounded, AdminTheme.accent),
          const Divider(color: Colors.white10, height: 24),
          _buildMetricRow('New Users (7d)', '+${data['newUsersLastWeek'] ?? 0}', Icons.person_add_rounded, AdminTheme.success),
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
            'Engagement Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildMetricRow('Avg Upvotes / Post', data['avgUpvotesPerPost']?.toString() ?? '0', Icons.arrow_upward_rounded, Colors.orange),
          const Divider(color: Colors.white10, height: 24),
          _buildMetricRow('New Posts (7d)', data['newPostsLastWeek']?.toString() ?? '0', Icons.post_add_rounded, Colors.blue),
          const Divider(color: Colors.white10, height: 24),
          _buildMetricRow('Report Rate', '${((data['totalReports'] ?? 0) / (data['totalPosts'] ?? 1) * 100).toStringAsFixed(1)}%', Icons.flag_rounded, AdminTheme.warning),
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
            'Community Retention',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildMetricRow('Active Users', data['activeUsers']?.toString() ?? '0', Icons.bolt_rounded, Colors.yellow),
          const Divider(color: Colors.white10, height: 24),
          _buildMetricRow('Retention Rate', '${data['retentionRate']}%', Icons.loop_rounded, AdminTheme.accent),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(color: AdminTheme.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticRow(
    String label,
    String value,
    double percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 6,
              width: MediaQuery.of(context).size.width * 0.7 * percentage,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
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
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return _buildEmptyState(
            Icons.verified_user_rounded,
            'No pending reports',
            'All content is currently within guidelines.',
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
                        _buildDetailRow('Reason', report['reason'] ?? 'No reason provided'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                if (post != null) {
                                  _viewPostDetails(MapPost.fromMap(post));
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
                              onPressed: () => _dismissReport(report['id']),
                              child: const Text('Dismiss', style: TextStyle(color: AdminTheme.textMuted)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _deletePost(report['post_id'], report['id']),
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

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AdminTheme.accent.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AdminTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: AdminTheme.accent, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AdminTheme.textSecondary)),
      ],
    );
  }

  Widget _buildErrorLogsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getErrorLogs(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading logs: ${snapshot.error}'));
        }

        final errorLogs = snapshot.data ?? [];

        if (errorLogs.isEmpty) {
          return _buildEmptyState(
            Icons.check_circle_outline_rounded,
            'No errors logged',
            'System is running smoothly.',
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
                          Icon(Icons.person_rounded, size: 12, color: AdminTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(username, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
                          if (screen != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.laptop_chromebook_rounded, size: 12, color: AdminTheme.textMuted),
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
          style: TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (screen != null) ...[
                _buildDetailRow('Screen', screen),
                const SizedBox(height: 16),
              ],
              _buildDetailRow('Message', message),
              if (stack != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'STACK_TRACE',
                  style: TextStyle(fontSize: 10, color: AdminTheme.accent, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    stack,
                    style: TextStyle(
                      color: AdminTheme.accent.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final fullError = stack != null ? '$message\n\nStack:\n$stack' : message;
              Clipboard.setData(ClipboardData(text: fullError));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Full error copied to clipboard')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent, foregroundColor: Colors.black),
            child: const Text('COPY_ALL'),
          ),
        ],
      ),
    );
  }


  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
          }

          if (snapshot.hasError) {
            return _buildErrorState('Error loading users', snapshot.error.toString());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return _buildEmptyState(Icons.people_outline_rounded, 'No users found', 'Your community is just getting started.');
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
            if (isAdmin) _buildBadge('ADMIN', AdminTheme.accent),
            if (isBanned) _buildBadge('BANNED', AdminTheme.error),
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
        onTap: () => _showUserDetailDialog(user),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildErrorState(String title, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AdminTheme.error),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: AdminTheme.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent, foregroundColor: Colors.black),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserDetailDialog(Map<String, dynamic> user) async {
    final username = user['username'] as String? ?? 'Unknown User';
    final email = user['email'] as String? ?? 'No email';
    final userId = user['id'] as String? ?? '';
    final isAdmin = user['is_admin'] == true;
    final isBanned = user['is_banned'] == true;
    final banReason = user['ban_reason'] as String?;
    final points = user['points'] as num? ?? 0;
    final canPost = user['can_post'] != false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
        ),
        title: Text(
          username.toUpperCase(),
          style: const TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', email),
              const SizedBox(height: 12),
              _buildDetailRow('User ID', userId),
              const SizedBox(height: 12),
              _buildDetailRow('Points', points.toString()),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusBadge(isAdmin ? 'ADMIN' : 'USER', isAdmin ? AdminTheme.accent : AdminTheme.textMuted),
                  const SizedBox(width: 8),
                  _buildStatusBadge(isBanned ? 'BANNED' : 'ACTIVE', isBanned ? AdminTheme.error : AdminTheme.success),
                ],
              ),
              if (isBanned && banReason != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Ban Reason', banReason),
              ],
              const SizedBox(height: 24),
              const Text(
                'ADMIN_ACTIONS',
                style: TextStyle(fontSize: 10, color: AdminTheme.accent, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                isAdmin ? 'Demote from Admin' : 'Promote to Admin',
                isAdmin ? Icons.remove_moderator_rounded : Icons.admin_panel_settings_rounded,
                isAdmin ? AdminTheme.warning : AdminTheme.accent,
                () {
                  Navigator.pop(context);
                  _toggleAdminStatus(userId, username, !isAdmin);
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                isBanned ? 'Unban User' : 'Ban User',
                isBanned ? Icons.check_circle_rounded : Icons.block_rounded,
                isBanned ? AdminTheme.success : AdminTheme.error,
                () {
                  Navigator.pop(context);
                  if (isBanned) {
                    _unbanUser(userId, username);
                  } else {
                    _banUserWithReason(userId, username);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                canPost ? 'Restrict Posting' : 'Allow Posting',
                canPost ? Icons.edit_off_rounded : Icons.edit_rounded,
                canPost ? AdminTheme.warning : Colors.blue,
                () {
                  Navigator.pop(context);
                  _togglePostingRestriction(userId, username, !canPost);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'POINT_MANAGEMENT',
                style: TextStyle(fontSize: 10, color: Colors.amber, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton('Add', Icons.add_rounded, Colors.amber, () => _showAddPointsDialog(userId, username)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton('Remove', Icons.remove_rounded, AdminTheme.error, () => _showRemovePointsDialog(userId, username)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Transaction History',
                Icons.history_rounded,
                AdminTheme.textSecondary,
                () => _showTransactionHistory(userId, username),
                isOutlined: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: AdminTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed, {bool isOutlined = false}) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color == AdminTheme.accent ? Colors.black : Colors.white),
        label: Text(label, style: TextStyle(color: color == AdminTheme.accent ? Colors.black : Colors.white, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _toggleAdminStatus(String userId, String username, bool makeAdmin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
        ),
        title: Text(
          makeAdmin ? 'PROMOTE_TO_ADMIN' : 'DEMOTE_FROM_ADMIN',
          style: const TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontSize: 16),
        ),
        content: Text(
          makeAdmin
              ? 'Are you sure you want to grant administrative privileges to $username?'
              : 'Are you sure you want to revoke administrative privileges from $username?',
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: makeAdmin ? AdminTheme.accent : AdminTheme.warning,
              foregroundColor: Colors.black,
            ),
            child: Text(makeAdmin ? 'PROMOTE' : 'REVOKE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.setUserAdminStatus(userId, makeAdmin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(makeAdmin ? 'User promoted to admin' : 'Admin privileges removed'),
              backgroundColor: const Color(0xFF00FF41),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error updating admin status: $e');
        }
      }
    }
  }

  Future<void> _banUserWithReason(String userId, String username) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Ban User', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ban $username?',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Reason for ban',
                  labelStyle: TextStyle(color: Color(0xFF00FF41)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF41)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF41), width: 2),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ban'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await _adminService.banUser(userId, result.isEmpty ? 'No reason provided' : result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User banned successfully'),
              backgroundColor: Colors.red,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error banning user: $e');
        }
      }
    }
  }

  Future<void> _unbanUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Unban User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Unban $username and allow them to use the app again?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.unbanUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User unbanned successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error unbanning user: $e');
        }
      }
    }
  }

  Future<void> _togglePostingRestriction(String userId, String username, bool canPost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          canPost ? 'Allow Posting' : 'Restrict Posting',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          canPost
              ? 'Allow $username to create new posts?'
              : 'Prevent $username from creating new posts?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: canPost ? Colors.blue : Colors.deepOrange,
            ),
            child: Text(canPost ? 'Allow' : 'Restrict'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.togglePostingRestriction(userId, canPost);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(canPost ? 'Posting enabled for user' : 'Posting restricted for user'),
              backgroundColor: canPost ? Colors.blue : Colors.deepOrange,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error updating posting restriction: $e');
        }
      }
    }
  }

  Future<void> _showAddPointsDialog(String userId, String username) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
        ),
        title: Text(
          'ADD_POINTS: $username',
          style: const TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(amountController, 'Amount', Icons.add_circle_outline_rounded, isNumber: true),
            const SizedBox(height: 16),
            _buildDialogTextField(reasonController, 'Reason', Icons.description_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              
              try {
                await _adminService.addPointTransaction(
                  userId: userId,
                  amount: amount,
                  type: 'admin_adjustment',
                  description: reasonController.text.isEmpty ? 'Admin adjustment' : reasonController.text,
                );
                if (!context.mounted) return;
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $amount points to $username'),
                    backgroundColor: AdminTheme.success,
                  ),
                );
                _loadData();
              } catch (e) {
                if (context.mounted) ErrorHelper.showError(context, 'Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accent, foregroundColor: Colors.black),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AdminTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AdminTheme.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AdminTheme.accent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminTheme.accent),
        ),
        filled: true,
        fillColor: Colors.black26,
      ),
    );
  }

  Future<void> _showRemovePointsDialog(String userId, String username) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AdminTheme.error.withValues(alpha: 0.2)),
        ),
        title: Text(
          'REMOVE_POINTS: $username',
          style: const TextStyle(color: AdminTheme.error, fontFamily: 'monospace', fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(amountController, 'Amount', Icons.remove_circle_outline_rounded, isNumber: true),
            const SizedBox(height: 16),
            _buildDialogTextField(reasonController, 'Reason', Icons.description_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              
              try {
                await _adminService.addPointTransaction(
                  userId: userId,
                  amount: -amount,
                  type: 'admin_adjustment',
                  description: reasonController.text.isEmpty ? 'Admin adjustment' : reasonController.text,
                );
                if (!context.mounted) return;
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed $amount points from $username'),
                    backgroundColor: AdminTheme.error,
                  ),
                );
                _loadData();
              } catch (e) {
                if (context.mounted) ErrorHelper.showError(context, 'Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionHistory(String userId, String username) async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AdminTheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AdminTheme.accent.withValues(alpha: 0.2)),
          ),
          title: Text(
            'TRANSACTION_HISTORY: $username',
            style: const TextStyle(color: AdminTheme.accent, fontFamily: 'monospace', fontSize: 16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _adminService.getPointTransactions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions found', style: TextStyle(color: AdminTheme.textMuted)));
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final amount = (tx['amount'] as num).toDouble();
                    final isPositive = amount > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          (tx['transaction_type'] as String? ?? 'Unknown').toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                        subtitle: Text(tx['description'] ?? '', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isPositive ? "+" : ""}$amount',
                              style: TextStyle(
                                color: isPositive ? AdminTheme.success : AdminTheme.error,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminTheme.textMuted),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AdminTheme.secondary,
                                    title: const Text('DELETE_TRANSACTION?', style: TextStyle(color: AdminTheme.error, fontSize: 16)),
                                    content: const Text('This will reverse the points for this transaction.', style: TextStyle(color: AdminTheme.textSecondary)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: AdminTheme.textMuted))),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: AdminTheme.error))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await _adminService.deletePointTransaction(tx['id'], userId, amount);
                                    if (!context.mounted) return;
                                    setState(() {});
                                    _loadData();
                                  } catch (e) {
                                    if (context.mounted) ErrorHelper.showError(context, 'Error: $e');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: AdminTheme.textMuted))),
          ],
        ),
      ),
    );
  }

  // Removed unused _buildUserDetailRow
}
