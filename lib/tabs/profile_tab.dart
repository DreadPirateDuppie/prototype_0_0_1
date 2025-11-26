import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/edit_username_dialog.dart';
import '../widgets/mini_map_snapshot.dart';
import '../widgets/user_stats_card.dart';
import '../providers/user_provider.dart';
import 'settings_tab.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/error_helper.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileTab({super.key, this.onProfileUpdated});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  late Future<List<MapPost>> _userPostsFuture;
  late TabController _tabController;
  final bool _isStatsExpanded = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize posts future
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
    } else {
      _userPostsFuture = Future.value([]);
    }
    
    // Initialize user provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser == null) {
        userProvider.initialize();
      } else {
        userProvider.loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      // Refresh user provider (handles XP recalculation)
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshScores();
      
      // Refresh posts
      if (mounted) {
        setState(() {
          _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);

    if (pickedFile != null) {
      setState(() {
        _isUploadingImage = true;
      });

      try {
        final user = SupabaseService.getCurrentUser();
        if (user != null) {
          final newUrl = await SupabaseService.uploadProfileImage(File(pickedFile.path), user.id);
          // Update provider with new avatar URL
          if (mounted) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            userProvider.updateAvatarUrl(newUrl);
            widget.onProfileUpdated?.call(); // Notify parent to refresh nav bar
          }
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, 'Error uploading image: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }
    }
  }

  void _editUsername(String currentUsername) {
    showDialog(
      context: context,
      builder: (context) => EditUsernameDialog(
        currentUsername: currentUsername,
        onUsernameSaved: (newUsername) async {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.updateUsername(newUsername);
          widget.onProfileUpdated?.call();
        },
      ),
    );
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
            // color: Colors.black87, // Removed to use theme default
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  void _showStatsInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Stats Explained'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(
                '🎯 VS Lvl',
                'Earn XP from battles: Win = +10 XP, Lose = -5 to -15 XP (based on performance). Progressive leveling: Lvl 1 = 100 XP, Lvl 2 = 300 XP, Lvl 3 = 600 XP, etc.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '📍 Spotter Lvl',
                'Earn XP from posting spots on the map. Get +1 XP for each upvote on your posts! Progressive leveling: Lvl 1 = 100 XP, Lvl 2 = 300 XP, Lvl 3 = 600 XP, etc.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '⭐ Ranking Score',
                'Traditional scoring (0-1000). Starts at 500. Increases with voting accuracy.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '🏆 Final Score',
                'Average of all three scores. Determines your overall standing.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '⚖️ Vote Weight',
                'Your voting influence (0-100%). Higher final score = more influence.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  // Stats section now uses the extracted UserStatsCard widget
  Widget _buildStatsSection(UserScores scores) {
    return UserStatsCard(
      scores: scores,
      initiallyExpanded: _isStatsExpanded,
      onInfoPressed: _showStatsInfo,
    );
  }

  Widget _buildGridPost(MapPost post) {
    return GestureDetector(
      onTap: () => _editPost(post), // Or show details
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          image: post.photoUrl != null
              ? DecorationImage(
                  image: NetworkImage(post.photoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: post.photoUrl == null
            ? MiniMapSnapshot(
                latitude: post.latitude,
                longitude: post.longitude,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.getCurrentUser();

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 300.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.green,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _refreshAll,
                    ),
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
                      colors: [
                        Colors.green.shade700, 
                        Theme.of(context).scaffoldBackgroundColor
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Avatar
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Builder(
                                builder: (context) {
                                  if (_isUploadingImage) {
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.black54,
                                      child: const CircularProgressIndicator(color: Colors.green),
                                    );
                                  }
                                  
                                  if (userProvider.avatarUrl != null) {
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(userProvider.avatarUrl!),
                                      backgroundColor: Colors.green.shade200,
                                    );
                                  }
                                  
                                  return CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.green.shade200,
                                    child: Text(
                                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username - now from UserProvider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            userProvider.isLoading 
                                ? 'Loading...' 
                                : userProvider.displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                            onPressed: () {
                              _editUsername(userProvider.username ?? '');
                            },
                          ),
                        ],
                      ),
                      // Bio / Email
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
                indicatorColor: Colors.green,
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'My Posts', icon: Icon(Icons.grid_on)),
                  Tab(text: 'Saved', icon: Icon(Icons.bookmark)),
                ],
              ),
            ),
            // User Stats Section (Scrollable) - now from UserProvider
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  if (userProvider.isLoading) {
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (userProvider.userScores != null) {
                    return _buildStatsSection(userProvider.userScores!);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: My Posts (Grid)
            FutureBuilder<List<MapPost>>(
              future: _userPostsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final posts = snapshot.data ?? [];
                
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildGridPost(posts[index]);
                  },
                );
              },
            ),
            
            // Tab 2: Saved Posts (Grid)
            FutureBuilder<List<MapPost>>(
              future: SupabaseService.getSavedPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final posts = snapshot.data ?? [];
                
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No saved posts',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save posts from the feed to see them here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildGridPost(posts[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
      },
    );
  }

}
