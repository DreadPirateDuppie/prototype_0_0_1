import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with SingleTickerProviderStateMixin {
  List<MapPost> _posts = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _searchMode = 'posts'; // 'posts' or 'users'
  final List<String> _categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
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
      List<MapPost> posts = await SupabaseService.getAllMapPostsWithVotes();
      
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

    if (_searchMode == 'posts') {
      _loadPosts();
    } else {
      _searchUsers();
    }
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _loadPosts();
    }
  }

  void _toggleSearchMode() {
    setState(() {
      _searchMode = _searchMode == 'posts' ? 'users' : 'posts';
      _searchQuery = '';
      _searchController.clear();
      _users.clear();
      _posts.clear();
    });
    
    if (_searchMode == 'posts') {
      _loadPosts();
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
            leading: CircleAvatar(
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
            title: Text(
              user['display_name'] ?? user['username'] ?? 'Unknown User',
              style: const TextStyle(
                color: matrixGreen,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              '@${user['username'] ?? 'unknown'}',
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.7),
                fontFamily: 'monospace',
                fontSize: 12,
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
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Search Mode Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeToggle('POSTS', _searchMode == 'posts'),
                    const SizedBox(width: 8),
                    _buildModeToggle('USERS', _searchMode == 'users'),
                  ],
                ),
                const SizedBox(height: 8),
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
                          decoration: InputDecoration(
                            hintText: _searchMode == 'posts' ? 'Search posts...' : 'Search users...',
                            hintStyle: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.5),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              _searchMode == 'posts' ? Icons.search : Icons.person_search,
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
                    if (_searchMode == 'posts')
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

  Widget _buildModeToggle(String text, bool isActive) {
    const matrixGreen = Color(0xFF00FF41);
    
    return GestureDetector(
      onTap: _toggleSearchMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? matrixGreen.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.7),
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_searchMode == 'users') {
      // User search results
      if (_users.isEmpty) {
        if (_searchQuery.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search,
                  size: 64,
                  color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search for users',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          );
        }
      }

      return RefreshIndicator(
        onRefresh: _searchUsers,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            return _buildUserCard(_users[index]);
          },
        ),
      );
    } else {
      // Post search results
      if (_posts.isEmpty) {
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
              Text(
                'No posts found',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              post: _posts[index],
              onPostUpdated: _loadPosts,
            );
          },
        ),
      );
    }
  }
}
