import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../services/battle_service.dart';
import '../widgets/user_stats_card.dart';
import '../widgets/mini_map_snapshot.dart';
import '../screens/spot_details_screen.dart';
import '../screens/followers_list_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/verified_badge.dart';
import '../widgets/matrix_rain_background.dart';
import '../widgets/profile/profile_header.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late Future<List<MapPost>> _userPostsFuture;
  late TabController _tabController;
  UserScores? _userScores;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String? _currentUsername;
  String? _currentAvatarUrl;
  bool _isVerified = false;
  List<Map<String, dynamic>> _profileMedia = [];
  bool _isLoadingMedia = true;
  String? _bio;
  
  // Stats expansion state
  bool _isStatsExpanded = false;
  bool _isPrivate = false;
  
  bool get _canViewContent {
    final currentUser = SupabaseService.getCurrentUser();
    final isMe = currentUser?.id == widget.userId;
    if (isMe) return true;
    if (!_isPrivate) return true;
    return _isFollowing;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUsername = widget.username;
    _currentAvatarUrl = widget.avatarUrl;
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Load posts
      _userPostsFuture = SupabaseService.getUserMapPosts(widget.userId);
      
      // Load profile data
      final profile = await SupabaseService.getUserProfile(widget.userId);
      if (profile != null) {
        if (mounted) {
          setState(() {
            _currentUsername = profile['username'];
            _currentAvatarUrl = profile['avatar_url'];
            _isVerified = profile['is_verified'] as bool? ?? false;
            _isPrivate = profile['is_private'] as bool? ?? false;
          });
        }
      }

      // Load scores
      _userScores = await BattleService.getUserScores(widget.userId);
      
      // Load follow status
      _isFollowing = await SupabaseService.isFollowing(widget.userId);
      
      // Load counts
      final counts = await SupabaseService.getFollowCounts(widget.userId);
      _followersCount = counts['followers'] ?? 0;
      _followingCount = counts['following'] ?? 0;

      // Load media
      _loadProfileMedia();

      _loadBio();

    } catch (e) {
      // Ignore load error
    }
  }

  Future<void> _loadProfileMedia() async {
    setState(() => _isLoadingMedia = true);
    try {
      final media = await SupabaseService.getProfileMedia(widget.userId);
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

  Future<void> _loadBio() async {
    try {
      final bio = await SupabaseService.getUserBio(widget.userId);
      if (mounted) {
        setState(() {
          _bio = bio;
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;

    setState(() {
      _isFollowLoading = true;
    });

    try {
      if (_isFollowing) {
        await SupabaseService.unfollowUser(widget.userId);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followersCount--;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unfollowed user')),
          );
        }
      } else {
        await SupabaseService.followUser(widget.userId);
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followersCount++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Following user!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating follow status: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
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
                'Earn XP from battles: Win = +10 XP, Lose = -5 to -15 XP.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '📍 Spotter Lvl',
                'Earn XP from posting spots on the map.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '⭐ Ranking Score',
                'Traditional scoring (0-1000). Starts at 500.',
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildGridPost(MapPost post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDetailsScreen(post: post),
          ),
        );
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

  Widget _buildMediaGrid() {
    if (_isLoadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileMedia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.perm_media_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No media yet',
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
      itemCount: _profileMedia.length,
      itemBuilder: (context, index) {
        final media = _profileMedia[index];
        final isVideo = media['media_type'] == 'video';
        final isPostSource = media['source'] == 'post' && media['post_id'] != null;
        
        return GestureDetector(
          onTap: () async {
            if (isPostSource) {
              // Navigate to the post
              try {
                // We need to fetch the full post first
                final posts = await SupabaseService.getAllMapPosts(); // Inefficient, should have getById
                // Better approach: filter by ID locally if possible or add getPostById
                // For now, let's just assume we can find it or fail gracefully.
                // Actually, let's use the PostService directly if possible or add a method.
                // Since I can't easily change the Service contract right now without more files, 
                // I'll filter getAllMapPosts (not ideal but works for prototype).
                // Wait, SupabaseService.getAllMapPosts doesn't take an ID.
                // Let's rely on the fact that if it's a post, we can try to construct a partial MapPost 
                // but SpotDetails needs a full one. 
                // Let's just catch the tap and try to open it.
                
                // Optimized: Fetch just this post
                final post = await Supabase.instance.client
                  .from('map_posts')
                  .select()
                  .eq('id', media['post_id'])
                  .single();
                  
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SpotDetailsScreen(post: MapPost.fromMap(post)),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not load post details')),
                );
              }
            } else {
              // Show full screen media viewer (Gallery items)
              if (isVideo) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video playback not supported in preview')),
                  );
                 return;
              }
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: EdgeInsets.zero,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        child: Image.network(
                          media['media_url'],
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 20,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              image: !isVideo ? DecorationImage(
                image: NetworkImage(media['media_url']),
                fit: BoxFit.cover,
              ) : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  Container(
                    color: Colors.black54, // Placeholder for video thumb
                    child: const Center(
                      child: Icon(Icons.videocam, color: Colors.white30, size: 40),
                    ),
                  ),
                if (isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                  ),
                if (isPostSource)
                   Positioned(
                     bottom: 4,
                     right: 4,
                     child: Container(
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(
                         color: Colors.black54,
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: const Icon(Icons.link, color: Colors.white70, size: 12),
                     ),
                   ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF00FF41);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
             child: MatrixRainBackground(opacity: 0.15, speed: 0.8),
          ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
            SliverAppBar(
              expandedHeight: 80.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                '> USER_PROFILE_',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: neonGreen,
                  letterSpacing: 2,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  ProfileHeader(
                    profileData: {
                      'id': widget.userId,
                      'username': _currentUsername,
                      'avatar_url': _currentAvatarUrl,
                      'is_verified': _isVerified,
                      'bio': _bio,
                    },
                    isCurrentUser: SupabaseService.getCurrentUser()?.id == widget.userId,
                  ),
                  const SizedBox(height: 16),
                  
                  // Follow Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.transparent : neonGreen,
                          foregroundColor: _isFollowing ? neonGreen : Colors.black,
                          side: _isFollowing ? const BorderSide(color: neonGreen) : null,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: _isFollowLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isFollowing ? 'STATUS: FOLLOWING' : 'CMD: FOLLOW_USER',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Stats Card
            SliverToBoxAdapter(
              child: _userScores != null
                  ? FutureBuilder<List<MapPost>>(
                      future: _userPostsFuture,
                      builder: (context, snapshot) {
                        return UserStatsCard(
                          scores: _userScores!,
                          followersCount: _followersCount,
                          followingCount: _followingCount,
                          postCount: snapshot.data?.length ?? 0,
                          initiallyExpanded: _isStatsExpanded,
                          showDetailedStats: true, // Now public!
                          onInfoPressed: _showStatsInfo,
                          onPostsTap: _canViewContent ? () => _tabController.animateTo(0) : null,
                          onFollowersTap: _canViewContent ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FollowersListScreen(
                                  userId: widget.userId,
                                  username: _currentUsername,
                                  initialTab: 0,
                                ),
                              ),
                            );
                          } : null,
                          onFollowingTap: _canViewContent ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FollowersListScreen(
                                  userId: widget.userId,
                                  username: _currentUsername,
                                  initialTab: 1,
                                ),
                              ),
                            );
                          } : null,
                        );
                      }
                    )
                  : const SizedBox.shrink(),
            ),

            if (!_canViewContent)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'This account is private',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow to see their posts & pins',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Tab Bar
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: neonGreen,
                    labelColor: neonGreen,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(text: 'Posts', icon: Icon(Icons.grid_on)),
                      Tab(text: 'Media', icon: Icon(Icons.perm_media)),
                    ],
                  ),
                ),
                pinned: true,
              ),            ],
          ];
        },
        body: !_canViewContent 
            ? const SizedBox.shrink()
            : TabBarView(
          controller: _tabController,
          children: [
            // Posts Tab
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
            // Media Tab
            _buildMediaGrid(),
          ],
        ), // End TabBarView
      ), // End NestedScrollView
    ], 
  ), 
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
