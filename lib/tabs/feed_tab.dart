import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';
import '../screens/user_profile_screen.dart';

class FeedTab extends StatefulWidget {
  final Function(LatLng)? onNavigateToMap;

  const FeedTab({
    super.key,
    this.onNavigateToMap,
  });

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with SingleTickerProviderStateMixin {
  List<MapPost> _posts = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _onlineFriends = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSort = 'newest'; // 'newest', 'popularity', 'oldest'
  final List<String> _categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadOnlineFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<MapPost> posts = await SupabaseService.getAllMapPostsWithVotes(sortBy: _selectedSort);
      
      // Apply filters
      if (_selectedCategory != 'All') {
        posts = posts.where((post) => post.category == _selectedCategory).toList();
      }
      
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        posts = posts.where((post) {
          return post.title.toLowerCase().contains(query) ||
                 post.description.toLowerCase().contains(query) ||
                 post.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ErrorHelper.showError(context, 'Error loading posts: $e');
      }
    }
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await SupabaseService.searchUsers(_searchQuery);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ErrorHelper.showError(context, 'Error searching users: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    _loadPosts();
    _searchUsers();
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _loadPosts();
    }
  }

  void _onSortChanged(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      _loadPosts();
    }
  }

  Future<void> _loadOnlineFriends() async {
    try {
      final friends = await SupabaseService.getMutualFollowers();
      final visibleLocations = await SupabaseService.getVisibleUserLocations();

      final onlineFriends = visibleLocations.where((user) => friends.any((friend) => friend['id'] == user['id'])).toList();

      if (mounted) {
        setState(() {
          _onlineFriends = onlineFriends;
        });
      }
    } catch (e) {
      developer.log('Error loading online friends: $e', name: 'FeedTab');
    }
  }

  Future<void> _onUserAction(Map<String, dynamic> user) async {
    try {
      await SupabaseService.followUser(user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now following ${user['display_name'] ?? user['username']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Refresh the user list to update follow button
      _searchUsers();
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error following user: $e');
      }
    }
  }

  Future<void> _onUserUnfollow(Map<String, dynamic> user) async {
    try {
      await SupabaseService.unfollowUser(user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed ${user['display_name'] ?? user['username']}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Refresh the user list to update follow button
      _searchUsers();
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error unfollowing user: $e');
      }
    }
  }

  Future<bool> _isFollowingUser(String userId) async {
    try {
      return await SupabaseService.isFollowing(userId);
    } catch (e) {
      return false;
    }
  }

  Widget _buildOnlineFriendCard(Map<String, dynamic> user) {
    const matrixGreen = Color(0xFF00FF41);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: user['id'],
                  username: user['username'],
                  avatarUrl: user['avatar_url'],
                ),
              ),
            );
          },
          child: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: matrixGreen.withValues(alpha: 0.2),
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                child: user['avatar_url'] == null
                    ? Text(
                        (user['display_name'] ?? user['username'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: matrixGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: user['id'],
                  username: user['username'],
                  avatarUrl: user['avatar_url'],
                ),
              ),
            );
          },
          child: Row(
            children: [
              Flexible(
                child: Text(
                  user['display_name'] ?? user['username'] ?? 'Unknown User',
                  style: const TextStyle(
                    color: matrixGreen,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        subtitle: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: user['id'],
                  username: user['username'],
                  avatarUrl: user['avatar_url'],
                ),
              ),
            );
          },
          child: Text(
            '@${user['username'] ?? 'unknown'}',
            style: TextStyle(
              color: matrixGreen.withValues(alpha: 0.7),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        trailing: SizedBox(
          width: 80,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to map tab and center on friend's location
              final lat = user['current_latitude'] as double?;
              final lng = user['current_longitude'] as double?;
              
              if (lat != null && lng != null) {
                final location = LatLng(lat, lng);
                
                if (widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!(location);
                  
                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Showing ${user['display_name'] ?? user['username']}\'s location'),
                      backgroundColor: const Color(0xFF00FF41),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Fallback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigation not available'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location not available'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: matrixGreen.withValues(alpha: 0.2),
              foregroundColor: matrixGreen,
              side: BorderSide(color: matrixGreen, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(70, 32),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            child: const Text('VIEW'),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    const matrixGreen = Color(0xFF00FF41);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FutureBuilder<bool>(
        future: _isFollowingUser(user['id']),
        builder: (context, snapshot) {
          final isFollowing = snapshot.data ?? false;

          return ListTile(
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: matrixGreen.withValues(alpha: 0.2),
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                child: user['avatar_url'] == null
                    ? Text(
                        (user['display_name'] ?? user['username'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: matrixGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: Text(
                user['display_name'] ?? user['username'] ?? 'Unknown User',
                style: const TextStyle(
                  color: matrixGreen,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            subtitle: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: Text(
                '@${user['username'] ?? 'unknown'}',
                style: TextStyle(
                  color: matrixGreen.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            trailing: SizedBox(
              width: 80,
              child: ElevatedButton(
                onPressed: () => isFollowing
                    ? _onUserUnfollow(user)
                    : _onUserAction(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing
                      ? Colors.orange.withValues(alpha: 0.8)
                      : matrixGreen.withValues(alpha: 0.2),
                  foregroundColor: isFollowing ? Colors.white : matrixGreen,
                  side: BorderSide(
                    color: isFollowing ? Colors.orange : matrixGreen,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(70, 32),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                child: Text(isFollowing ? 'UNFOLLOW' : 'FOLLOW'),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '> PUSHINN_',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: matrixGreen,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: matrixGreen.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: matrixGreen,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          cursorColor: matrixGreen,
                          maxLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Search posts and users...',
                            hintStyle: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.5),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: matrixGreen,
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: matrixGreen, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: matrixGreen.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          icon: const Icon(Icons.filter_list, color: matrixGreen, size: 18),
                          dropdownColor: Colors.black,
                          isDense: true,
                          style: const TextStyle(
                            color: matrixGreen,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          items: _categories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: _onCategoryChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: matrixGreen, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: matrixGreen.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, color: matrixGreen, size: 18),
                        color: Colors.black,
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                        ),
                        onSelected: _onSortChanged,
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'newest',
                            child: Text('Newest', style: TextStyle(color: matrixGreen, fontFamily: 'monospace')),
                          ),
                          const PopupMenuItem<String>(
                            value: 'popularity',
                            child: Text('Popularity', style: TextStyle(color: matrixGreen, fontFamily: 'monospace')),
                          ),
                          const PopupMenuItem<String>(
                            value: 'oldest',
                            child: Text('Oldest', style: TextStyle(color: matrixGreen, fontFamily: 'monospace')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: matrixGreen))
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    const matrixGreen = Color(0xFF00FF41);

    return Container(
      margin: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_searchQuery.isEmpty) {
      // Show online friends first, then posts with filters
      final List<Widget> items = [];

      // Add online friends if any
      if (_onlineFriends.isNotEmpty) {
        items.add(_buildSectionHeader('FRIENDS ONLINE'));
        for (final friend in _onlineFriends) {
          items.add(_buildOnlineFriendCard(friend));
        }
      }

      // Add posts
      for (final post in _posts) {
        items.add(PostCard(
          post: post,
          onPostUpdated: _loadPosts,
        ));
      }

      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article,
                size: 64,
                color: const Color(0xFF00FF41).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No posts to display',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00FF41),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _loadPosts();
          await _loadOnlineFriends();
        },
        child: ListView(
          children: items,
        ),
      );
    } else {
      // Search mode: show combined results
      final List<Widget> items = [];

      // Add users section if any
      if (_users.isNotEmpty) {
        items.add(_buildSectionHeader('USERS'));
        for (final user in _users) {
          items.add(_buildUserCard(user));
        }
      }

      // Add posts section if any
      if (_posts.isNotEmpty) {
        items.add(_buildSectionHeader('POSTS'));
        for (final post in _posts) {
          items.add(PostCard(
            post: post,
            onPostUpdated: _loadPosts,
          ));
        }
      }

      // If no results
      if (_users.isEmpty && _posts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: const Color(0xFF00FF41).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No results found',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00FF41),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _loadPosts();
          await _searchUsers();
        },
        child: ListView(
          children: items,
        ),
      );
    }
  }
}
