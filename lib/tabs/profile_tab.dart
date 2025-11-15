import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/edit_post_dialog.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/ad_banner.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<List<MapPost>> _userPostsFuture;
  String? _displayName;
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshPosts();
    _loadDisplayName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _refreshPosts() {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
    }
  }

  Future<void> _loadDisplayName() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      final displayName = await SupabaseService.getUserDisplayName(user.id);
      setState(() {
        _displayName = displayName;
        _nameController.text = displayName ?? '';
        _emailController.text = user.email ?? '';
      });
    }
  }

  Future<void> _saveDisplayName() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null && _nameController.text.trim().isNotEmpty) {
      await SupabaseService.saveUserDisplayName(user.id, _nameController.text.trim());
      setState(() {
        _displayName = _nameController.text.trim();
        _isEditingName = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditingName = false;
      _nameController.text = _displayName ?? '';
    });
  }

  Future<void> _deletePost(String postId) async {
    await SupabaseService.deleteMapPost(postId);
    if (mounted) {
      setState(() {
        _refreshPosts();
      });
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditingName)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingName = true;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: SingleChildScrollView(
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
                          (_displayName?.isNotEmpty ?? false)
                              ? _displayName![0].toUpperCase()
                              : user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _displayName ?? 'User Profile',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_isEditingName)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Display Name',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter display name',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      onPressed: _saveDisplayName,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: _cancelEdit,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Email',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter email',
                                    border: OutlineInputBorder(),
                                  ),
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
        ],
      ),
    );
  }
}
