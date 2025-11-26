import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

/// Provider for managing post/feed state across the app
class PostProvider extends ChangeNotifier {
  List<MapPost> _posts = [];
  List<MapPost> _userPosts = [];
  List<MapPost> _savedPosts = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  static const List<String> categories = [
    'All', 'Street', 'Park', 'DIY', 'Shop', 'Other'
  ];

  // Getters
  List<MapPost> get posts => _filteredPosts;
  List<MapPost> get allPosts => _posts;
  List<MapPost> get userPosts => _userPosts;
  List<MapPost> get savedPosts => _savedPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  /// Get filtered posts based on search and category
  List<MapPost> get _filteredPosts {
    var filtered = _posts;
    
    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((post) => post.category == _selectedCategory)
          .toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        return post.title.toLowerCase().contains(query) ||
               post.description.toLowerCase().contains(query) ||
               post.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
    
    return filtered;
  }

  /// Load all posts
  Future<void> loadPosts() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _posts = await SupabaseService.getAllMapPostsWithVotes();
      _error = null;
    } catch (e) {
      _error = 'Failed to load posts: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load posts for a specific user
  Future<void> loadUserPosts(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userPosts = await SupabaseService.getUserMapPosts(userId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load user posts: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load saved posts for a user
  Future<void> loadSavedPosts(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _savedPosts = await SupabaseService.getSavedPosts();
      _error = null;
    } catch (e) {
      _error = 'Failed to load saved posts: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update selected category
  void setCategory(String category) {
    if (categories.contains(category)) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  /// Clear filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    notifyListeners();
  }

  /// Refresh posts
  Future<void> refresh() async {
    await loadPosts();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get post by ID
  MapPost? getPostById(String id) {
    try {
      return _posts.firstWhere((post) => post.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update a post in the local cache
  void updatePost(MapPost updatedPost) {
    final index = _posts.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      _posts[index] = updatedPost;
      notifyListeners();
    }
  }

  /// Remove a post from the local cache
  void removePost(String postId) {
    _posts.removeWhere((post) => post.id == postId);
    _userPosts.removeWhere((post) => post.id == postId);
    notifyListeners();
  }
}
