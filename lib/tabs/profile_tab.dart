import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/edit_username_dialog.dart';
import '../screens/followers_list_screen.dart';
import '../widgets/mini_map_snapshot.dart';
import '../widgets/user_stats_card.dart';
import '../providers/user_provider.dart';
import 'settings_tab.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/error_helper.dart';
import '../config/theme_config.dart';
import '../screens/spot_details_screen.dart';
import '../screens/upload_media_dialog.dart';
import '../screens/create_feed_post_dialog.dart';


class ProfileTab extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileTab({super.key, this.onProfileUpdated});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  late Future<List<MapPost>> _userPostsFuture;
  late TabController _tabController;
  final bool _isStatsExpanded = false;
  bool _isUploadingImage = false;
  int _followersCount = 0;
  int _followingCount = 0;
  List<Map<String, dynamic>> _profileMedia = [];
  bool _isLoadingMedia = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Changed from 2 to 3
    
    // Initialize posts future
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
      _loadFollowCounts(user.id);
      _loadProfileMedia(user.id);
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
      
      // Refresh posts and follow counts
      if (mounted) {
        setState(() {
          _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
        });
        await _loadFollowCounts(user.id);
      }
    }
  }

  Future<void> _loadFollowCounts(String userId) async {
    try {
      final counts = await SupabaseService.getFollowCounts(userId);
      if (mounted) {
        setState(() {
          _followersCount = counts['followers'] ?? 0;
          _followingCount = counts['following'] ?? 0;
        });
      }
    } catch (e) {
      // Silently fail - follow counts are not critical
    }
  }

  Future<void> _loadProfileMedia(String userId) async {
    setState(() => _isLoadingMedia = true);
    try {
      final media = await SupabaseService.getProfileMedia(userId);
      if (mounted) {
        setState(() {
          _profileMedia = media;
          _isLoadingMedia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
  }

  Future<void> _showUploadMediaDialog() async {
    showDialog(
      context: context,
      builder: (context) => UploadMediaDialog(
        onMediaUploaded: () {
          final user = SupabaseService.getCurrentUser();
          if (user != null) {
            _loadProfileMedia(user.id);
          }
        },
      ),
    );
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDetailsScreen(post: post),
          ),
        ).then((_) => _refreshAll()); // Refresh on return in case of changes
      },
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
            ? (post.latitude != null && post.longitude != null
                ? MiniMapSnapshot(
                    latitude: post.latitude!,
                    longitude: post.longitude!,
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.article, color: Colors.white54),
                    ),
                  ))
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
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 400.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    leading: IconButton(
                      icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => CreateFeedPostDialog(
                            onPostAdded: _refreshAll,
                          ),
                        );
                      },
                    ),
                    title: const Text(
                      '> PUSHINN_',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    centerTitle: true,
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
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).scaffoldBackgroundColor
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(height: 10),
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
                                        color: ThemeColors.darkGreen,
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
                            // Username - now from UserProvider
                            if (userProvider.username == null || userProvider.username!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _editUsername('');
                                  },
                                  icon: const Icon(Icons.alternate_email, size: 18),
                                  label: const Text('Set Username'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.green.shade700,
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '@${userProvider.username}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.white70),
                                    onPressed: () {
                                      _editUsername(userProvider.username ?? '');
                                    },
                                    tooltip: 'Edit Username',
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
                            const SizedBox(height: 20),
                            // Stats Row
                            FutureBuilder<List<MapPost>>(
                              future: _userPostsFuture,
                              builder: (context, snapshot) {
                                final postCount = snapshot.data?.length ?? 0;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatColumn('Posts', '$postCount'),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FollowersListScreen(
                                              userId: user!.id,
                                              username: userProvider.username,
                                              initialTab: 0, // Show followers
                                            ),
                                          ),
                                        ).then((_) => _loadFollowCounts(user!.id));
                                      },
                                      child: _buildStatColumn('Followers', '$_followersCount'),
                                    ),
                                    Container(
                                      height: 24,
                                      width: 1,
                                      color: Colors.white24,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FollowersListScreen(
                                              userId: user!.id,
                                              username: userProvider.username,
                                              initialTab: 1, // Show following
                                            ),
                                          ),
                                        ).then((_) => _loadFollowCounts(user!.id));
                                      },
                                      child: _buildStatColumn('Following', '$_followingCount'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
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
                // Persistent Tab Bar
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                      tabs: const [
                        Tab(text: 'My Posts', icon: Icon(Icons.grid_on)),
                        Tab(text: 'Saved', icon: Icon(Icons.bookmark)),
                        Tab(text: 'Media', icon: Icon(Icons.perm_media)),
                      ],
                    ),
                  ),
                  pinned: true,
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
                // Tab 3: Media Gallery
                Stack(
                  children: [
                    _isLoadingMedia
                        ? const Center(child: CircularProgressIndicator())
                        : _profileMedia.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No media yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload photos or videos to your profile',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(2),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                                itemCount: _profileMedia.length,
                                itemBuilder: (context, index) {
                                  final media = _profileMedia[index];
                                  final isVideo = media['media_type'] == 'video';
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      // TODO: Show full screen media viewer
                                    },
                                    onLongPress: () async {
                                      // Show delete option
                                      final shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Media'),
                                          content: const Text('Are you sure you want to delete this media?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (shouldDelete == true) {
                                        try {
                                          await SupabaseService.deleteProfileMedia(media['id']);
                                          final user = SupabaseService.getCurrentUser();
                                          if (user != null) {
                                            _loadProfileMedia(user.id);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ErrorHelper.showError(context, 'Error deleting media: $e');
                                          }
                                        }
                                      }
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          media['media_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image, size: 32),
                                            );
                                          },
                                        ),
                                        if (isVideo)
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    // Upload FAB
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _showUploadMediaDialog,
                        backgroundColor: const Color(0xFF00FF41),
                        child: const Icon(Icons.add, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
