import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

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

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        backgroundColor: Colors.green.shade200,
        child: avatarUrl == null
            ? Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: username != null ? Text('@$username') : null,
      trailing: isCurrentUser
          ? null
          : SizedBox(
              width: 100,
              child: OutlinedButton(
                onPressed: () => _toggleFollow(userId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isFollowing ? Colors.grey : Colors.green,
                  side: BorderSide(
                    color: isFollowing ? Colors.grey : Colors.green,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 0 ? 'No followers yet' : 'Not following anyone yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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
      appBar: AppBar(
        title: Text(widget.username != null ? '@${widget.username}' : 'Followers'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Followers (${_followers.length})'),
            Tab(text: 'Following (${_following.length})'),
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
