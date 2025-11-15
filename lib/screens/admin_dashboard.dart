import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';

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
  late Future<Map<String, dynamic>> _analyticsData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
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
      final avgLikesPerPost = totalPosts > 0 ? (totalLikes / totalPosts).toStringAsFixed(1) : '0';
      
      // Get posts with photos
      final postsWithPhotos = posts.where((p) => p.photoUrl != null && p.photoUrl!.isNotEmpty).length;
      
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
          _loadReports();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              ...recentPosts.take(5).map((post) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
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
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
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
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analytics update in real-time as users interact with your app.',
                          style: TextStyle(color: Colors.blue[900]),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
                Text(
                  'No reports to review',
                  style: TextStyle(fontSize: 18),
                ),
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
      child: FutureBuilder<List<MapPost>>(
        future: _allPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];
          
          // Extract unique users from posts
          final userMap = <String, Map<String, dynamic>>{};
          for (var post in posts) {
            final userId = post.userId;
            final userName = post.userName ?? 'Unknown User';
            
            if (!userMap.containsKey(userId)) {
              userMap[userId] = {
                'name': userName,
                'email': post.userEmail ?? 'No email',
                'postCount': 1,
                'totalLikes': post.likes,
              };
            } else {
              userMap[userId]!['postCount'] = 
                  (userMap[userId]!['postCount'] as int) + 1;
              userMap[userId]!['totalLikes'] = 
                  (userMap[userId]!['totalLikes'] as int) + post.likes;
            }
          }

          final users = userMap.entries.toList()
            ..sort((a, b) => (b.value['postCount'] as int)
                .compareTo(a.value['postCount'] as int));

          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 18),
                  ),
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
                    'User Directory',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text('${users.length} users'),
                    backgroundColor: Colors.deepPurple[100],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...users.map((entry) {
                final userId = entry.key;
                final userData = entry.value;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        (userData['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(userData['name'] as String),
                    subtitle: Text(userData['email'] as String),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${userData['totalLikes']} likes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
>>>>>>> 26e8f460c2110169a16419e73d2bde744c12f423
                        ),
=======
                        Text(
                          '${userData['postCount']} posts',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${userData['totalLikes']} likes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
=======
                        Text(
                          '${userData['totalLikes']} likes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
>>>>>>> 26e8f460c2110169a16419e73d2bde744c12f423
                        ),
                      ],
                    ),
                    onTap: () {
                      // Could navigate to user detail page
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('User details for ${userData['name']}'),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
