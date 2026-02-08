import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';
import '../widgets/hud_avatar.dart';
import '../screens/user_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final int initialTab; // 0 = followers, 1 = following

  const FollowersListScreen({
    super.key,
    required this.userId,
    this.username,
    this.initialTab = 0,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;
  Set<String> _followingIds = {}; // IDs of users the current user follows
  
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final followers = await SupabaseService.getFollowers(widget.userId);
      final following = await SupabaseService.getFollowing(widget.userId);
      
      // Get current user's following list to show follow/unfollow buttons
      final currentUser = SupabaseService.getCurrentUser();
      if (currentUser != null) {
        final myFollowing = await SupabaseService.getFollowing(currentUser.id);
        _followingIds = myFollowing.map((u) => u['id'] as String).toSet();
      }

      if (mounted) {
        setState(() {
          _followers = followers;
          _following = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error loading followers: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(String userId) async {
    try {
      final isCurrentlyFollowing = _followingIds.contains(userId);
      
      if (isCurrentlyFollowing) {
        await SupabaseService.unfollowUser(userId);
        setState(() {
          _followingIds.remove(userId);
        });
      } else {
        await SupabaseService.followUser(userId);
        setState(() {
          _followingIds.add(userId);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error: $e');
      }
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final username = user['username'] as String?;
    final displayName = user['display_name'] as String?;
    final avatarUrl = user['avatar_url'] as String?;
    final name = displayName ?? username ?? 'User';
    final currentUser = SupabaseService.getCurrentUser();
    final isCurrentUser = currentUser?.id == userId;
    final isFollowing = _followingIds.contains(userId);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: userId,
              username: username,
              avatarUrl: avatarUrl,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            HudAvatar(
              avatarUrl: avatarUrl,
              username: username,
              radius: 20,
              showScanline: false,
              neonColor: matrixGreen,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (username != null)
                    Text(
                      '@$username'.toUpperCase(),
                      style: TextStyle(
                        color: matrixGreen.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            if (!isCurrentUser)
              SizedBox(
                width: 100,
                child: TextButton(
                  onPressed: () => _toggleFollow(userId),
                  style: TextButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.transparent : matrixGreen,
                    foregroundColor: isFollowing ? matrixGreen : Colors.black,
                    side: BorderSide(color: matrixGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    isFollowing ? 'STATUS: OK' : 'CMD: FLW',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: matrixGreen),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 0 ? 'NO_FOLLOWERS_FOUND' : 'DATA_STREAM_EMPTY',
              style: TextStyle(
                fontSize: 14,
                color: matrixGreen.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserTile(users[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        title: Text(
          (widget.username != null ? '> @${widget.username}' : '> FOLLOW_LIST').toUpperCase(),
          style: const TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        backgroundColor: matrixBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: matrixGreen),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: matrixGreen,
          labelColor: matrixGreen,
          unselectedLabelColor: Colors.white24,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          indicatorWeight: 1,
          tabs: [
            Tab(text: 'FOLLOWERS // ${_followers.length}'),
            Tab(text: 'FOLLOWING // ${_following.length}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_followers),
          _buildList(_following),
        ],
      ),
    );
  }
}
