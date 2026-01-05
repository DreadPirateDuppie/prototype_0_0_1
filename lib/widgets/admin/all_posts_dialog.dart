import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../theme/admin_theme.dart';
import 'admin_activity_item.dart';
import 'admin_empty_state.dart';
import 'admin_error_state.dart';

class AllPostsDialog extends StatefulWidget {
  final Future<List<MapPost>> allPostsFuture;
  final VoidCallback onRefresh;
  final String Function(DateTime) formatTimestamp;
  final Function(MapPost) onViewPostDetails;
  final Function(String) onViewUserProfile;
  final Function(MapPost) onEditPost;
  final Function(String) onDeletePost;

  const AllPostsDialog({
    super.key,
    required this.allPostsFuture,
    required this.onRefresh,
    required this.formatTimestamp,
    required this.onViewPostDetails,
    required this.onViewUserProfile,
    required this.onEditPost,
    required this.onDeletePost,
  });

  @override
  State<AllPostsDialog> createState() => _AllPostsDialogState();
}

class _AllPostsDialogState extends State<AllPostsDialog> {
  final TextEditingController _postSearchController = TextEditingController();
  String _selectedPostType = 'All';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _postSearchController.dispose();
    super.dispose();
  }

  List<MapPost> _filterPosts(List<MapPost> posts) {
    return posts.where((post) {
      // Search filter
      final query = _postSearchController.text.toLowerCase();
      final matchesSearch = query.isEmpty ||
          post.title.toLowerCase().contains(query) ||
          post.description.toLowerCase().contains(query) ||
          (post.userName?.toLowerCase().contains(query) ?? false);

      if (!matchesSearch) return false;

      // Post Type filter
      if (_selectedPostType != 'All') {
        final isVideo = post.videoUrl != null && post.videoUrl!.isNotEmpty;
        final isImage = post.photoUrls.isNotEmpty;
        
        if (_selectedPostType == 'Video' && !isVideo) return false;
        if (_selectedPostType == 'Image' && !isImage) return false;
        if (_selectedPostType == 'Text' && (isVideo || isImage)) return false;
      }

      // Category filter
      if (_selectedCategory != 'All') {
        if (post.category != _selectedCategory) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AdminTheme.primary,
      child: Column(
        children: [
          AppBar(
            backgroundColor: AdminTheme.secondary,
            title: const Text('ALL_POSTS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: widget.onRefresh,
              ),
            ],
          ),
          // Search and Filters UI
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            color: AdminTheme.secondary,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _postSearchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by title, description, or user...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.accent),
                    suffixIcon: _postSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AdminTheme.textMuted),
                            onPressed: () {
                              _postSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Chips - TYPE
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildFilterGroup(
                    'TYPE:',
                    ['All', 'Video', 'Image', 'Text'],
                    _selectedPostType,
                    (value) => setState(() => _selectedPostType = value),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips - CATEGORY
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildFilterGroup(
                    'CATEGORY:',
                    ['All', 'Spot', 'Battle', 'VS', 'Other'],
                    _selectedCategory,
                    (value) => setState(() => _selectedCategory = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MapPost>>(
              future: widget.allPostsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AdminTheme.accent));
                }
                if (snapshot.hasError) {
                  return AdminErrorState(title: 'Error loading posts', error: snapshot.error.toString());
                }
                
                final allPosts = snapshot.data ?? [];
                final filteredPosts = _filterPosts(allPosts);

                if (filteredPosts.isEmpty) {
                  return const AdminEmptyState(
                    icon: Icons.search_off_rounded, 
                    title: 'No matching posts', 
                    subtitle: 'Try adjusting your search or filters.'
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) => AdminActivityItem(
                    post: filteredPosts[index],
                    formatTimestamp: widget.formatTimestamp,
                    onViewDetails: () => widget.onViewPostDetails(filteredPosts[index]),
                    onViewAuthor: () => widget.onViewUserProfile(filteredPosts[index].userId),
                    onEdit: () => widget.onEditPost(filteredPosts[index]),
                    onDelete: () => filteredPosts[index].id != null ? widget.onDeletePost(filteredPosts[index].id!) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(String label, List<String> options, String selectedValue, Function(String) onSelected) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: AdminTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        ...options.map((option) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(option, style: const TextStyle(fontSize: 11)),
            selected: selectedValue == option,
            onSelected: (selected) {
              if (selected) onSelected(option);
            },
            selectedColor: AdminTheme.accent.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: selectedValue == option ? AdminTheme.accent : AdminTheme.textSecondary,
              fontWeight: selectedValue == option ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: Colors.transparent,
            side: BorderSide(
              color: selectedValue == option ? AdminTheme.accent : Colors.white10,
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        )),
      ],
    );
  }
}
