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

class _FeedTabState extends State<FeedTab> {
  List<MapPost> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadPosts();
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _loadPosts();
    }
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: matrixGreen, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: matrixGreen,
                        fontFamily: 'monospace',
                      ),
                      cursorColor: matrixGreen,
                      decoration: InputDecoration(
                        hintText: 'Search posts...',
                        hintStyle: TextStyle(
                          color: matrixGreen.withOpacity(0.5),
                          fontFamily: 'monospace',
                        ),
                        prefixIcon: const Icon(Icons.search, color: matrixGreen),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: matrixGreen, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: matrixGreen.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      icon: const Icon(Icons.filter_list, color: matrixGreen),
                      dropdownColor: Colors.black,
                      style: const TextStyle(
                        color: matrixGreen,
                        fontFamily: 'monospace',
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
          ),
        ),
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: const Color(0xFF00FF41).withOpacity(0.5),
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
                      )
                    : RefreshIndicator(
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
                      ),
          ),
        ],
      ),
    );
  }
}
