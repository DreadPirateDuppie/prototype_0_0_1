import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_scores.dart';
import '../services/battle_service.dart';
import '../widgets/user_stats_card.dart';
import '../widgets/mini_map_snapshot.dart';
import '../screens/spot_details_screen.dart';
import '../screens/followers_list_screen.dart';
import '../config/theme_config.dart';
import '../utils/error_helper.dart';

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
  UserScores? _userScores;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String? _currentUsername;
  String? _currentAvatarUrl;
  
  // Stats expansion state
  final bool _isStatsExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.username;
    _currentAvatarUrl = widget.avatarUrl;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load posts
      _userPostsFuture = SupabaseService.getUserMapPosts(widget.userId);
      
      // Load profile data if missing
      if (_currentUsername == null || _currentAvatarUrl == null) {
        final profile = await SupabaseService.getUserProfile(widget.userId);
        if (profile != null) {
          _currentUsername = profile['username'];
          _currentAvatarUrl = profile['avatar_url'];
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

    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 380.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey.shade900,
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
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _currentAvatarUrl != null
                                ? NetworkImage(_currentAvatarUrl!)
                                : null,
                            backgroundColor: Colors.grey.shade800,
                            child: _currentAvatarUrl == null
                                ? Text(
                                    (_currentUsername?.isNotEmpty == true)
                                        ? _currentUsername![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Username
                        Text(
                          _currentUsername != null ? '@$_currentUsername' : 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Follow Button
                        ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.transparent : Colors.white,
                            foregroundColor: _isFollowing ? Colors.white : Colors.black,
                            side: _isFollowing ? const BorderSide(color: Colors.white) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isFollowLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isFollowing ? Colors.white : Colors.black,
                                  ),
                                )
                              : Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                          userId: widget.userId,
                                          username: _currentUsername,
                                          initialTab: 0,
                                        ),
                                      ),
                                    );
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
                                          userId: widget.userId,
                                          username: _currentUsername,
                                          initialTab: 1,
                                        ),
                                      ),
                                    );
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
            
            // Stats Card
            SliverToBoxAdapter(
              child: _userScores != null
                  ? UserStatsCard(
                      scores: _userScores!,
                      initiallyExpanded: _isStatsExpanded,
                      onInfoPressed: _showStatsInfo,
                    )
                  : const SizedBox.shrink(),
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
      ),
    );
  }
}
