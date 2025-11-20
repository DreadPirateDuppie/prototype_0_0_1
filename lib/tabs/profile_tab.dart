import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/battle_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/edit_username_dialog.dart';
import '../widgets/star_rating_display.dart';
import 'settings_tab.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  late Future<List<MapPost>> _userPostsFuture;
  late Future<String?> _usernameFuture;
  late Future<UserScores> _userScoresFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
        _usernameFuture = SupabaseService.getUserUsername(user.id);
        _userScoresFuture = BattleService.getUserScores(user.id);
      });
    }
  }

  void _editUsername(String currentUsername) {
    showDialog(
      context: context,
      builder: (context) => EditUsernameDialog(
        currentUsername: currentUsername,
        onUsernameSaved: (newUsername) {
          setState(() {
            _usernameFuture = SupabaseService.getUserUsername(SupabaseService.getCurrentUser()!.id);
          });
        },
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
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

    if (confirmed == true) {
      await SupabaseService.deleteMapPost(postId);
      if (mounted) {
        _refreshAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    }
  }

  Future<void> _editPost(MapPost post) async {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: post,
        onPostUpdated: () {
          _refreshAll();
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildGridPost(MapPost post) {
    return GestureDetector(
      onTap: () => _editPost(post), // Or show details
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          image: post.photoUrl != null
              ? DecorationImage(
                  image: NetworkImage(post.photoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: post.photoUrl == null
            ? const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))
            : null,
      ),
    );
  }

  Widget _buildListPost(MapPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    (post.userName?.isNotEmpty ?? false)
                        ? post.userName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _editPost(post),
                ),
              ],
            ),
            if (post.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.photoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(post.description),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StarRatingDisplay(
                  popularityRating: post.popularityRating,
                  securityRating: post.securityRating,
                  qualityRating: post.qualityRating,
                ),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text('${post.likes}'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.getCurrentUser();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 380.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.deepPurple,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsTab(),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade50],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.deepPurple.shade200,
                          child: Text(
                            user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username
                      FutureBuilder<String?>(
                        future: _usernameFuture,
                        builder: (context, snapshot) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                snapshot.data ?? 'Loading...',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                onPressed: () {
                                  _usernameFuture.then((username) {
                                    _editUsername(username ?? '');
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      // Bio / Email
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Stats Row
                      FutureBuilder<List<MapPost>>(
                        future: _userPostsFuture,
                        builder: (context, snapshot) {
                          final postCount = snapshot.data?.length ?? 0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('Posts', '$postCount'),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.deepPurple,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.list)),
                ],
              ),
            ),
          ];
        },
        body: FutureBuilder<List<MapPost>>(
          future: _userPostsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = snapshot.data ?? [];

            return TabBarView(
              controller: _tabController,
              children: [
                // Grid View
                posts.isEmpty
                    ? const Center(child: Text('No posts yet'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) => _buildGridPost(posts[index]),
                      ),
                // List View
                posts.isEmpty
                    ? const Center(child: Text('No posts yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: posts.length,
                        itemBuilder: (context, index) => _buildListPost(posts[index]),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}
