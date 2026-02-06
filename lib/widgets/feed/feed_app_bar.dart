import 'package:flutter/material.dart';
import '../../screens/add_post_dialog.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/messaging_screen.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final String selectedFeed;
  final String selectedPostType;
  final String selectedCategory;
  final String selectedSort;
  final Function(String) onSearchChanged;
  final Function(String) onFeedToggle;
  final Function(String) onPostTypeChanged;
  final Function(String) onCategoryChanged;
  final Function(String) onSortChanged;
  final VoidCallback onPostAdded;

  const FeedAppBar({
    super.key,
    required this.searchController,
    required this.selectedFeed,
    required this.selectedPostType,
    required this.selectedCategory,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onFeedToggle,
    required this.onPostTypeChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onPostAdded,
  });

  @override
  Size get preferredSize => const Size.fromHeight(156); // AppBar (56) + bottom (100)

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.add_box_outlined, color: matrixGreen),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => AddPostDialog(
                onPostAdded: onPostAdded,
              ),
            ),
          );
        },
      ),
      title: const Text(
        '> PUSHINN_',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: matrixGreen,
          letterSpacing: 2,
          fontSize: 20,
          fontFamily: 'monospace',
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: matrixGreen),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.mail_outline, color: matrixGreen),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessagingScreen(),
              ),
            );
          },
          tooltip: 'Messages',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Search Bar
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: matrixGreen.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
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
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(height: 12),
              // Feed Toggle and Filter
              Row(
                children: [
                  // Feed Toggle
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          _buildFeedToggleOption('Global', selectedFeed == 'global', onFeedToggle),
                          Container(width: 1, color: matrixGreen.withValues(alpha: 0.3)),
                          _buildFeedToggleOption('Following', selectedFeed == 'following', onFeedToggle),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter Button
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
                      icon: const Icon(Icons.tune, color: matrixGreen, size: 18),
                      color: Colors.black,
                      offset: const Offset(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                      ),
                      onSelected: (value) {
                        if (value.startsWith('cat_')) {
                          onCategoryChanged(value.replaceFirst('cat_', ''));
                        } else if (value.startsWith('type_')) {
                          onPostTypeChanged(value.replaceFirst('type_', ''));
                        } else {
                          onSortChanged(value);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: Text(
                            'CONTENT TYPE',
                            style: TextStyle(
                              color: Color(0xFF00FF41),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        _buildPopupItem('type_all', 'All Content', selectedPostType == 'all'),
                        _buildPopupItem('type_map', 'Map Spots', selectedPostType == 'map'),
                        _buildPopupItem('type_feed', 'Feed Posts', selectedPostType == 'feed'),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: Text(
                            'CATEGORIES',
                            style: TextStyle(
                              color: Color(0xFF00FF41),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        _buildPopupItem('cat_All', 'All Categories', selectedCategory == 'All'),
                        _buildPopupItem('cat_Street', 'Street', selectedCategory == 'Street'),
                        _buildPopupItem('cat_Park', 'Park', selectedCategory == 'Park'),
                        _buildPopupItem('cat_DIY', 'DIY', selectedCategory == 'DIY'),
                        _buildPopupItem('cat_Shop', 'Shop', selectedCategory == 'Shop'),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: Text(
                            'SORT BY',
                            style: TextStyle(
                              color: Color(0xFF00FF41),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        _buildPopupItem('newest', 'Newest First', selectedSort == 'newest'),
                        _buildPopupItem('popularity', 'Most Popular', selectedSort == 'popularity'),
                        _buildPopupItem('oldest', 'Oldest First', selectedSort == 'oldest'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check, color: Color(0xFF00FF41), size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00FF41) : Colors.white70,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedToggleOption(String label, bool isSelected, Function(String) onToggle) {
    const matrixGreen = Color(0xFF00FF41);

    return Expanded(
      child: GestureDetector(
        onTap: () => onToggle(label.toLowerCase()),
        child: Container(
          color: isSelected ? matrixGreen.withValues(alpha: 0.2) : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isSelected ? matrixGreen : matrixGreen.withValues(alpha: 0.5),
              fontFamily: 'monospace',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
