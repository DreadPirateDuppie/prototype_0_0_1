import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../providers/theme_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  Map<String, dynamic> _stats = {};
  String _usersSearchQuery = '';
  String _postsSearchQuery = '';
  Map<String, dynamic> _userStats = {};

  @override
  void initState() {
    super.initState();
    _ensureCurrentUserProfile().then((_) => _loadData());
  }

  Future<void> _ensureCurrentUserProfile() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      try {
        // Check if profile exists
        final existing = await Supabase.instance.client
            .from('user_profiles')
            .select('id, display_name, role')
            .eq('id', user.id)
            .maybeSingle();

        if (existing == null) {
          // Create profile if it doesn't exist
          await Supabase.instance.client.from('user_profiles').insert({
            'id': user.id,
            'display_name': user.email ?? 'User',
            'role': 'user',
          });
        } else {
          // Update display name if it has changed
          final currentDisplayName = await SupabaseService.getUserDisplayName(user.id);
          if (currentDisplayName != user.email && user.email != null) {
            await SupabaseService.saveUserDisplayName(user.id, user.email!);
          }
        }
      } catch (e) {
        // Silently fail - table may not exist yet
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadUsers(),
        _loadPosts(),
        _loadStats(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Error loading data: $e'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error message copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('id, display_name, role, created_at')
          .order('created_at', ascending: false);

      final users = List<Map<String, dynamic>>.from(response);

      // Ensure current user is included
      final currentUser = SupabaseService.getCurrentUser();
      if (currentUser != null) {
        final currentUserInList = users.any((user) => user['id'] == currentUser.id);
        if (!currentUserInList) {
          users.insert(0, {
            'id': currentUser.id,
            'display_name': currentUser.email ?? 'Current User',
            'role': 'user',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      setState(() {
        _users = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Error loading users: $e'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error message copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
      // Set empty list on error
      setState(() {
        _users = [];
      });
    }
  }

  Future<void> _loadPosts() async {
    final response = await Supabase.instance.client
        .from('map_posts')
        .select('''
          id,
          title,
          created_at,
          likes,
          user_id,
          user_profiles!inner(display_name)
        ''')
        .order('created_at', ascending: false)
        .limit(50);

    // Transform the response to include user_name for compatibility
    final transformedPosts = (response as List).map((post) {
      return {
        ...post as Map<String, dynamic>,
        'user_name': post['user_profiles']?['display_name'] ?? 'Unknown',
      };
    }).toList();

    setState(() {
      _posts = List<Map<String, dynamic>>.from(transformedPosts);
    });
  }

  Future<void> _loadStats() async {
    final userResponse = await Supabase.instance.client
        .from('user_profiles')
        .select('id');

    final postResponse = await Supabase.instance.client
        .from('map_posts')
        .select('id');

    final likesResponse = await Supabase.instance.client
        .from('post_likes')
        .select('id');

    setState(() {
      _stats = {
        'users': (userResponse as List).length,
        'posts': (postResponse as List).length,
        'likes': (likesResponse as List).length,
      };
    });
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'role': newRole})
          .eq('id', userId);

      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User role updated successfully'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Error updating role: $e'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error message copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await SupabaseService.deleteMapPost(postId);
      await _loadPosts();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Error deleting post: $e'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error message copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      // Load user's posts count
      final postsResponse = await Supabase.instance.client
          .from('map_posts')
          .select('id, likes')
          .eq('user_id', userId);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      final postsCount = posts.length;
      final totalLikes = posts.fold<int>(0, (sum, post) => sum + (post['likes'] as int? ?? 0));

      // Load user's points
      final pointsResponse = await Supabase.instance.client
          .from('user_points')
          .select('points, last_spin_date')
          .eq('user_id', userId)
          .maybeSingle();

      final points = pointsResponse?['points'] as int? ?? 0;
      final lastSpinDate = pointsResponse?['last_spin_date'] as String?;

      // Load user profile
      final profileResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('display_name, role, created_at')
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        _userStats = {
          'postsCount': postsCount,
          'totalLikes': totalLikes,
          'points': points,
          'lastSpinDate': lastSpinDate,
          'displayName': profileResponse?['display_name'] ?? 'Unknown',
          'role': profileResponse?['role'] ?? 'user',
          'joinDate': profileResponse?['created_at'] as String?,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user stats: $e'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Error loading user stats: $e'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error message copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
      setState(() {
        _userStats = {};
      });
    }
  }

  void _showUserStatsDialog(String userId) {
    _loadUserStats(userId);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('User Statistics'),
          content: _userStats.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${_userStats['displayName']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Role: ${_userStats['role']}'),
                      const SizedBox(height: 8),
                      Text('Posts Made: ${_userStats['postsCount']}'),
                      const SizedBox(height: 8),
                      Text('Total Likes Received: ${_userStats['totalLikes']}'),
                      const SizedBox(height: 8),
                      Text('Reward Points: ${_userStats['points']}'),
                      const SizedBox(height: 8),
                      Text(
                        'Last Spin: ${_userStats['lastSpinDate'] != null ? DateTime.parse(_userStats['lastSpinDate']).toLocal().toString().substring(0, 10) : 'Never'}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Joined: ${_userStats['joinDate'] != null ? DateTime.parse(_userStats['joinDate']).toLocal().toString().substring(0, 10) : 'Unknown'}',
                      ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepPurple.shade700, Colors.deepPurple.shade900]
              : [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: isDark ? 0.5 : 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final filteredUsers = _users.where((user) {
      final displayName = user['display_name']?.toString().toLowerCase() ?? '';
      final email = user['id']?.toString().toLowerCase() ?? '';
      final query = _usersSearchQuery.toLowerCase();
      return displayName.contains(query) || email.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (value) => setState(() => _usersSearchQuery = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(
                      user['display_name'] ?? 'No name',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Role: ${user['role'] ?? 'user'} • Joined: ${user['created_at']?.substring(0, 10) ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bar_chart, color: Colors.deepPurple),
                          onPressed: () => _showUserStatsDialog(user['id']),
                          tooltip: 'View Stats',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (user['role'] == 'admin') ? Colors.deepPurple.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: user['role'] ?? 'user',
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'user', child: Text('User')),
                              DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            ],
                            onChanged: (newRole) {
                              if (newRole != null) {
                                _updateUserRole(user['id'], newRole);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    final filteredPosts = _posts.where((post) {
      final title = post['title']?.toString().toLowerCase() ?? '';
      final userName = post['user_name']?.toString().toLowerCase() ?? '';
      final query = _postsSearchQuery.toLowerCase();
      return title.contains(query) || userName.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search posts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (value) => setState(() => _postsSearchQuery = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPosts,
            child: ListView.builder(
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(
                      post['title'] ?? 'No title',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post['user_name'] ?? 'Unknown',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${post['likes'] ?? 0}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            post['created_at']?.substring(0, 10) ?? 'Unknown',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete, color: Colors.red.shade600, size: 20),
                      ),
                      onPressed: () => _showDeleteConfirmation(post['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(postId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.watch<ThemeProvider>().isDarkMode
                  ? [Colors.deepPurple.shade900, Colors.grey.shade900]
                  : [Colors.deepPurple.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dashboard,
                        color: Colors.deepPurple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildStatsCard(
                      'Total Users',
                      _stats['users']?.toString() ?? '0',
                      Icons.people,
                    ),
                    _buildStatsCard(
                      'Total Posts',
                      _stats['posts']?.toString() ?? '0',
                      Icons.post_add,
                    ),
                    _buildStatsCard(
                      'Total Likes',
                      _stats['likes']?.toString() ?? '0',
                      Icons.favorite,
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up, size: 36, color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.watch<ThemeProvider>().isDarkMode ? 0.3 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timeline, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Activity tracking coming soon...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildUsersTab(),
          _buildPostsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey.shade600,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.post_add),
              label: 'Posts',
            ),
          ],
        ),
      ),
    );
  }
}
