import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/battle_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../screens/edit_post_dialog.dart';
import '../screens/edit_username_dialog.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/mini_map_snapshot.dart';
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
  late Future<String?> _usernameFuture;
  late Future<String?> _avatarUrlFuture;
  late Future<UserScores> _userScoresFuture;
  late TabController _tabController;
  bool _isStatsExpanded = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize futures immediately to prevent LateInitializationError
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
      _usernameFuture = SupabaseService.getUserUsername(user.id);
      _avatarUrlFuture = SupabaseService.getUserAvatarUrl(user.id);
      _userScoresFuture = BattleService.getUserScores(user.id);
    } else {
      // Fallback for no user (shouldn't happen in this tab usually)
      _userPostsFuture = Future.value([]);
      _usernameFuture = Future.value('Guest');
      _avatarUrlFuture = Future.value(null);
      _userScoresFuture = Future.value(UserScores(
        userId: '',
        mapScore: 0,
        playerScore: 0,
        rankingScore: 500,
      ));
    }
    
    // Then trigger a refresh to ensure data is up to date (including XP recalculation)
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      // Recalculate XP to ensure stats are up to date
      await SupabaseService.recalculateUserXP(user.id);
      
      if (mounted) {
        setState(() {
          _userPostsFuture = SupabaseService.getUserMapPosts(user.id);
          _usernameFuture = SupabaseService.getUserUsername(user.id);
          _avatarUrlFuture = SupabaseService.getUserAvatarUrl(user.id);
          _userScoresFuture = BattleService.getUserScores(user.id);
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
          await SupabaseService.uploadProfileImage(File(pickedFile.path), user.id);
          await _refreshAll();
          widget.onProfileUpdated?.call(); // Notify parent to refresh nav bar
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
        onUsernameSaved: (newUsername) {
          setState(() {
            _usernameFuture = SupabaseService.getUserUsername(SupabaseService.getCurrentUser()!.id);
          });
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

  Widget _buildScoreCard(String label, double score, Color color, {String? subtitle, bool isXP = false, int? level, double? levelProgress, double? xpForNextLevel}) {
    // For XP scores, use progressive leveling
    // For traditional scores, show progress out of 1000
    final double progress;
    final String displayValue;
    String? progressSubtitle;
    
    if (isXP && level != null && levelProgress != null && xpForNextLevel != null) {
      // XP system: use progressive leveling
      progress = levelProgress;
      displayValue = 'Lvl $level • ${score.toStringAsFixed(0)} XP';
      final xpNeeded = (xpForNextLevel - score).toStringAsFixed(0);
      progressSubtitle = '$xpNeeded XP to Lvl ${level + 1}';
    } else {
      // Traditional scoring (0-1000)
      progress = score / 1000.0;
      displayValue = score.toStringAsFixed(0);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                // color: Colors.black87,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        if (progressSubtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            progressSubtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSection(UserScores scores) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? Colors.green.shade900.withValues(alpha: 0.2) 
                : Colors.green.shade50,
            Theme.of(context).brightness == Brightness.dark 
                ? Colors.green.shade900.withValues(alpha: 0.1) 
                : Colors.lightGreen.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isStatsExpanded = !_isStatsExpanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Stats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.green.shade600,
                  ),
                  onPressed: _showStatsInfo,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Learn about stats',
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Private',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isStatsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.green.shade700,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Column(
              children: [
                const SizedBox(height: 16),
                _buildScoreCard(
                  'Spotter Lvl',
                  scores.mapScore,
                  Colors.green.shade600,
                  subtitle: 'XP from map contributions',
                  isXP: true,
                  level: scores.mapLevel,
                  levelProgress: scores.mapLevelProgress,
                  xpForNextLevel: scores.mapXPForNextLevel,
                ),
                const SizedBox(height: 12),
                _buildScoreCard(
                  'VS Lvl',
                  scores.playerScore,
                  Colors.blue.shade600,
                  subtitle: 'XP from battle performance',
                  isXP: true,
                  level: scores.playerLevel,
                  levelProgress: scores.playerLevelProgress,
                  xpForNextLevel: scores.playerXPForNextLevel,
                ),
                const SizedBox(height: 12),
                _buildScoreCard(
                  'Ranking Score',
                  scores.rankingScore,
                  Colors.orange.shade600,
                  subtitle: 'Voting accuracy (500-1000)',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Final Score',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scores.finalScore.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vote Weight',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(scores.voteWeight * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isStatsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
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
                  backgroundColor: Colors.green,
                  child: Text(
                    (post.userName?.isNotEmpty ?? false)
                        ? post.userName![0].toUpperCase()
                        : (post.userEmail?.isNotEmpty ?? false)
                        ? post.userEmail![0].toUpperCase()
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
                        post.userName ?? 
                            (post.userEmail != null 
                                ? post.userEmail!.split('@')[0] 
                                : 'Unknown User'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
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
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
            ] else ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: MiniMapSnapshot(
                    latitude: post.latitude,
                    longitude: post.longitude,
                  ),
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
                              child: FutureBuilder<String?>(
                                future: _avatarUrlFuture,
                                builder: (context, snapshot) {
                                  if (_isUploadingImage) {
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.black54,
                                      child: const CircularProgressIndicator(color: Colors.green),
                                    );
                                  }
                                  
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(snapshot.data!),
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
                                  // color: Colors.black87,
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
            // User Stats Section (Scrollable)
            SliverToBoxAdapter(
              child: FutureBuilder<UserScores>(
                future: _userScoresFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasData) {
                    return _buildStatsSection(snapshot.data!);
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
  }

}
