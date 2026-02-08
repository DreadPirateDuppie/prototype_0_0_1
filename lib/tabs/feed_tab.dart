import '../utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:latlong2/latlong.dart';
import '../models/post.dart';
import 'package:geocoding/geocoding.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/ad_banner.dart';
import '../widgets/feed/feed_app_bar.dart';
import '../widgets/feed/online_friends_list.dart';
import '../widgets/feed/user_search_results.dart';
import '../utils/error_helper.dart';

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
  String _selectedFeed = 'global'; // 'global', 'following'
  String _selectedPostType = 'all'; // 'all', 'map', 'feed'
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _pageSize = 15;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadPosts(refresh: true);
    _loadOnlineFriends();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore && !_isLoadingMore) {
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading || (_isLoadingMore && !refresh)) return;

    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _posts = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      List<MapPost> newPosts;
      if (_selectedFeed == 'following') {
        newPosts = await SupabaseService.getFollowingMapPostsWithVotes(
          sortBy: _selectedSort,
          category: _selectedCategory == 'All' ? null : _selectedCategory,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          page: _currentPage,
          pageSize: _pageSize,
        );
      } else {
        newPosts = await SupabaseService.getAllMapPostsWithVotes(
          sortBy: _selectedSort,
          category: _selectedCategory == 'All' ? null : _selectedCategory,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          page: _currentPage,
          pageSize: _pageSize,
        );
      }
      
      // Apply post type filter locally since it's based on presence of coordinates
      if (_selectedPostType == 'map') {
        newPosts = newPosts.where((post) => post.latitude != null && post.longitude != null).toList();
      } else if (_selectedPostType == 'feed') {
        newPosts = newPosts.where((post) => post.latitude == null || post.longitude == null).toList();
      }
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = newPosts;
          } else {
            _posts.addAll(newPosts);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = newPosts.length >= _pageSize;
          if (newPosts.isNotEmpty) {
            _currentPage++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
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

    _loadPosts(refresh: true);
    _searchUsers();
  }

  void _onPostTypeChanged(String? type) {
    if (type != null) {
      setState(() {
        _selectedPostType = type;
      });
      _loadPosts(refresh: true);
    }
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _loadPosts(refresh: true);
    }
  }

  void _onSortChanged(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      _loadPosts(refresh: true);
    }
  }

  Future<void> _loadOnlineFriends() async {
    try {
      final following = await SupabaseService.getFollowing(SupabaseService.getCurrentUser()!.id);
      final visibleLocations = await SupabaseService.getVisibleUserLocations();

      final onlineFriends = visibleLocations.where((user) => following.any((followed) => followed['id'] == user['id'])).toList();

      if (mounted) {
        setState(() {
          _onlineFriends = onlineFriends;
        });
      }

      // Enrich with reverse geocoding in background
      // This ensures the UI shows up immediately with "Online" status
      // while we fetch the specific street names.
      Future.wait(onlineFriends.map((friend) async {
        try {
          final lat = friend['current_latitude'] as double?;
          final lng = friend['current_longitude'] as double?;
          if (lat != null && lng != null) {
            List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              friend['location_name'] = '${place.thoroughfare ?? place.name}';
            }
          }
        } catch (e) {
          // Silently fail for geocoding, keeps "Online" as fallback
        }
      })).then((_) {
        if (mounted) {
          setState(() {
            // Trigger rebuild with new location names
             _onlineFriends = onlineFriends; // Reference is same but content changed
          });
        }
      });
    } catch (e) {
      AppLogger.log('Error loading online friends: $e', name: 'FeedTab');
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

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return Scaffold(
      backgroundColor: Colors.transparent, // Show global Matrix
      appBar: FeedAppBar(
        searchController: _searchController,
        selectedFeed: _selectedFeed,
        selectedPostType: _selectedPostType,
        selectedCategory: _selectedCategory,
        selectedSort: _selectedSort,
        onSearchChanged: _onSearchChanged,
        onFeedToggle: (feed) {
          setState(() => _selectedFeed = feed);
          _loadPosts(refresh: true);
        },
        onPostTypeChanged: _onPostTypeChanged,
        onCategoryChanged: _onCategoryChanged,
        onSortChanged: _onSortChanged,
        onPostAdded: () => _loadPosts(refresh: true),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await Future.wait<void>([
            _loadPosts(refresh: true),
            userProvider.refresh(),
          ]);
        },
        color: matrixGreen,
        backgroundColor: Colors.black,
        child: _isLoading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator(color: matrixGreen))
            : CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // User Search Results
                  SliverToBoxAdapter(
                    child: UserSearchResults(
                      users: _users,
                      onFollow: _onUserAction,
                      onUnfollow: _onUserUnfollow,
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: OnlineFriendsList(
                      onlineFriends: _onlineFriends,
                      onNavigateToMap: widget.onNavigateToMap ?? (_) {},
                    ),
                  ),

                  // Feed Posts
                  if (_posts.isEmpty && !_isLoading)
                    SliverFillRemaining(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feed_outlined, size: 64, color: matrixGreen.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No posts found',
                            style: TextStyle(
                              color: matrixGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing your filters or search query',
                            style: TextStyle(color: matrixGreen.withValues(alpha: 0.5), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return AdBanner(initialIndex: index ~/ 2);
                          }
                          
                          final postIndex = index ~/ 2;
                          if (postIndex >= _posts.length) return null;
                          
                          final post = _posts[postIndex];
                          return PostCard(
                            post: post,
                            onDelete: () => _loadPosts(refresh: true),
                          );
                        },
                        childCount: _posts.length * 2,
                      ),
                    ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: matrixGreen)),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // Padding for bottom nav bar
                  ],
                ],
              ),
      ),
    );
  }
}
