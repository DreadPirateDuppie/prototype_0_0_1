import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/admin_service.dart';
import '../models/post.dart';
import '../utils/error_helper.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _reportsFuture = SupabaseService.getReportedPosts();
      _allPostsFuture = SupabaseService.getAllMapPosts();
      _usersFuture = _adminService.getAllUsers(limit: 100);
      _analyticsData = _loadAnalytics();
    });
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    try {
      final posts = await SupabaseService.getAllMapPosts();
      final reports = await SupabaseService.getReportedPosts();

      // Calculate analytics
      final totalPosts = posts.length;
      final totalLikes = posts.fold<int>(0, (sum, post) => sum + post.likes);
      final totalReports = reports.length;
      final avgLikesPerPost = totalPosts > 0
          ? (totalLikes / totalPosts).toStringAsFixed(1)
          : '0';

      // Get posts with photos
      final postsWithPhotos = posts
          .where((p) => p.photoUrl != null && p.photoUrl!.isNotEmpty)
          .length;

      return {
        'totalPosts': totalPosts,
        'totalLikes': totalLikes,
        'totalReports': totalReports,
        'avgLikesPerPost': avgLikesPerPost,
        'postsWithPhotos': postsWithPhotos,
        'recentPosts': posts.take(5).toList(),
      };
    } catch (e) {
      return {
        'totalPosts': 0,
        'totalLikes': 0,
        'totalReports': 0,
        'avgLikesPerPost': '0',
        'postsWithPhotos': 0,
        'recentPosts': <MapPost>[],
      };
    }
  }

  Future<void> _deletePost(String postId) async {
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
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text(
            '> ADMIN_DASHBOARD_',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          backgroundColor: const Color(0xFF00FF41),
          foregroundColor: Colors.black,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black.withValues(alpha: 0.6),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.report), text: 'Reports'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildAnalyticsTab(),
            _buildReportsTab(),
            _buildUsersTab(),
          ],
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
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final totalPosts = data['totalPosts'] ?? 0;
          final totalLikes = data['totalLikes'] ?? 0;
          final totalReports = data['totalReports'] ?? 0;
          final recentPosts = (data['recentPosts'] ?? []) as List<MapPost>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Posts',
                      totalPosts.toString(),
                      Icons.article,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Total Likes',
                      totalLikes.toString(),
                      Icons.favorite,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Reports',
                      totalReports.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Avg Likes',
                      data['avgLikesPerPost'] ?? '0',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Recent Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...recentPosts
                  .take(5)
                  .map(
                    (post) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            post.likes.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(post.title),
                        subtitle: Text(post.userName ?? 'Unknown User'),
                        trailing: Icon(
                          post.photoUrl != null
                              ? Icons.photo
                              : Icons.text_fields,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    const matrixGreen = Color(0xFF00FF41);
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: matrixGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: matrixGreen),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: matrixGreen,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Analytics & Insights',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Content Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticRow(
                        'Total Posts',
                        '${data['totalPosts'] ?? 0}',
                      ),
                      _buildAnalyticRow(
                        'Posts with Photos',
                        '${data['postsWithPhotos'] ?? 0}',
                      ),
                      _buildAnalyticRow(
                        'Total Likes',
                        '${data['totalLikes'] ?? 0}',
                      ),
                      _buildAnalyticRow(
                        'Average Likes per Post',
                        data['avgLikesPerPost'] ?? '0',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moderation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticRow(
                        'Pending Reports',
                        '${data['totalReports'] ?? 0}',
                      ),
                      _buildAnalyticRow(
                        'Report Rate',
                        data['totalPosts'] != null && data['totalPosts'] > 0
                            ? '${((data['totalReports'] / data['totalPosts']) * 100).toStringAsFixed(1)}%'
                            : '0%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Color(0xFF00FF41)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analytics update in real-time as users interact with your app.',
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: Colors.green),
                SizedBox(height: 16),
                Text('No reports to review', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final post = report['map_posts'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REPORTED',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Status: ${report['status']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (post != null) ...[
                        Text(
                          post['title'] ?? 'Unknown Title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post['description'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By: ${post['user_name'] ?? 'Unknown User'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      Text(
                        'Report Reason: ${report['reason']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      if (report['details'] != null) ...[
                        const SizedBox(height: 8),
                        Text('Details: ${report['details']}'),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Report dismissed'),
                                ),
                              );
                              _loadData();
                            },
                            child: const Text('Dismiss'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: post != null
                                ? () => _deletePost(post['id'])
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete Post'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading users: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No users found', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Users',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text('${users.length} users'),
                    backgroundColor: const Color(0xFF00FF41).withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: Color(0xFF00FF41)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...users.map((user) {
                final username = user['username'] as String? ?? 'Unknown User';
                final email = user['email'] as String? ?? 'No email';
                final isAdmin = user['is_admin'] == true;
                final isBanned = user['is_banned'] == true;
                final points = user['points'] as int? ?? 0;
                final createdAt = user['created_at'] as String?;
                final userId = user['id'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: isAdmin ? const Color(0xFF00FF41) : Colors.grey[700],
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isAdmin ? Colors.black : Colors.white,
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
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.block,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            style: TextStyle(
                              color: isBanned ? Colors.grey[600] : Colors.white,
                              decoration: isBanned ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF41),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isBanned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Row(
                          children: [
                            Icon(Icons.stars, size: 12, color: Colors.amber[600]),
                            const SizedBox(width: 4),
                            Text(
                              '$points pts',
                              style: TextStyle(color: Colors.amber[600], fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                'Joined: ${createdAt.substring(0, 10)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[600],
                    ),
                    onTap: () => _showUserDetailDialog(user),
                  ),
                );
              }),
            ],
          );
        },
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
    final points = user['points'] as int? ?? 0;
    final canPost = user['can_post'] != false; // Default to true if not set
    final createdAt = user['created_at'] as String?;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          username,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserDetailRow('Email', email),
              _buildUserDetailRow('User ID', userId),
              _buildUserDetailRow('Points', points.toString()),
              _buildUserDetailRow('Admin', isAdmin ? 'Yes' : 'No'),
              _buildUserDetailRow('Banned', isBanned ? 'Yes' : 'No'),
              if (isBanned && banReason != null)
                _buildUserDetailRow('Ban Reason', banReason),
              _buildUserDetailRow('Can Post', canPost ? 'Yes' : 'No'),
              if (createdAt != null)
                _buildUserDetailRow('Joined', createdAt.substring(0, 10)),
              const SizedBox(height: 24),
              const Text(
                'Admin Actions',
                style: TextStyle(
                  color: Color(0xFF00FF41),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              
              // Admin Promotion/Demotion
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _toggleAdminStatus(userId, username, !isAdmin);
                  },
                  icon: Icon(isAdmin ? Icons.remove_moderator : Icons.admin_panel_settings),
                  label: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAdmin ? Colors.orange : const Color(0xFF00FF41),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Ban/Unban
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (isBanned) {
                      await _unbanUser(userId, username);
                    } else {
                      await _banUserWithReason(userId, username);
                    }
                  },
                  icon: Icon(isBanned ? Icons.check_circle : Icons.block),
                  label: Text(isBanned ? 'Unban User' : 'Ban User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBanned ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Posting Restriction
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _togglePostingRestriction(userId, username, !canPost);
                  },
                  icon: Icon(canPost ? Icons.do_not_disturb_on : Icons.post_add),
                  label: Text(canPost ? 'Restrict Posting' : 'Allow Posting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canPost ? Colors.deepOrange : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF00FF41)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAdminStatus(String userId, String username, bool makeAdmin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          makeAdmin ? 'Make Admin' : 'Remove Admin',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          makeAdmin
              ? 'Are you sure you want to give admin privileges to $username?'
              : 'Are you sure you want to remove admin privileges from $username?',
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
              backgroundColor: makeAdmin ? const Color(0xFF00FF41) : Colors.orange,
            ),
            child: Text(makeAdmin ? 'Make Admin' : 'Remove', style: const TextStyle(color: Colors.black)),
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
    String? banReason;
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

  Widget _buildUserDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF00FF41),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
