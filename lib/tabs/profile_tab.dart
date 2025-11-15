import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/edit_username_dialog.dart';
import '../widgets/star_rating_display.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<List<MapPost>> _userPostsFuture;
  late Future<String?> _usernameFuture;

  @override
  void initState() {
    super.initState();
    _refreshPosts();
    _refreshUsername();
  }

  void _refreshPosts() {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
    }
  }

  void _refreshUsername() {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _usernameFuture = SupabaseService.getUserUsername(user.id);
    }
  }

  void _editUsername(String currentUsername) {
    showDialog(
      context: context,
      builder: (context) => EditUsernameDialog(
        currentUsername: currentUsername,
        onUsernameSaved: (newUsername) {
          setState(() {
            _refreshUsername();
          });
        },
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    // Show confirmation dialog before deleting
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
        setState(() {
          _refreshPosts();
        });
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
          _refreshPosts();
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _refreshPosts();
            _refreshUsername();
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                    children: [
                      const SizedBox(height: 24),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'User Profile',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Username',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      _usernameFuture.then((username) {
                                        _editUsername(username ?? '');
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<String?>(
                                future: _usernameFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  final username = snapshot.data ?? 'Not set';
                                  return Text(
                                    username,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Email',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user?.email ?? 'Not available',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'User ID',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user?.id ?? 'Not available',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'My Posts',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<MapPost>>(
                        future: _userPostsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          final posts = snapshot.data ?? [];

                          if (posts.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('No posts yet. Add a post from the Map tab!'),
                            );
                          }

                          return Column(
                            children: posts.map((post) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // User info header
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.deepPurple,
                                            child: Text(
                                              (post.userName?.isNotEmpty ?? false)
                                                  ? post.userName![0].toUpperCase()
                                                  : (post.userEmail?.isNotEmpty ?? false)
                                                      ? post.userEmail![0].toUpperCase()
                                                      : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              post.userName ?? 'Unknown User',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (post.photoUrl != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            post.photoUrl!,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 150,
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.image_not_supported),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Text(
                                        post.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        post.description,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${post.latitude.toStringAsFixed(4)}, ${post.longitude.toStringAsFixed(4)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      StarRatingDisplay(
                                        popularityRating: post.popularityRating,
                                        securityRating: post.securityRating,
                                        qualityRating: post.qualityRating,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '❤️ ${post.likes}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Row(
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () => _editPost(post),
                                                icon: const Icon(Icons.edit, size: 16),
                                                label: const Text('Edit'),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                onPressed: () => _deletePost(post.id!),
                                                icon: const Icon(Icons.delete, size: 16),
                                                label: const Text('Delete'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
