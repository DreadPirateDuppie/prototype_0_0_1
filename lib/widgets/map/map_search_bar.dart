import 'package:flutter/material.dart';
import '../../models/post.dart';

class MapSearchBar extends StatelessWidget {
  final List<MapPost> userPosts;
  final Widget notchChild;
  final Function(MapPost?) onPostSelected;

  const MapSearchBar({
    super.key,
    required this.userPosts,
    required this.notchChild,
    required this.onPostSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: CustomPaint(
        painter: SearchNotchPainter(),
        child: SizedBox(
          height: 86, // 50 (bar) + 36 (notch)
          child: Stack(
            children: [
              // 1. Search Bar Content (Top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 50,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final result = await showSearch<MapPost?>(
                        context: context,
                        delegate: PostSearchDelegate(userPosts),
                      );
                      onPostSelected(result);
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: const Color(0xFF00FF41).withValues(alpha: 0.8),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Search spots...',
                            style: TextStyle(
                              color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                              fontSize: 16,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 2. Notch Content
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 200, // Matches painter notch width
                    child: notchChild,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00FF41).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Dimensions
    final searchBarHeight = 50.0;
    final notchWidth = 180.0; // Width of the notch area
    final notchHeight = 36.0; // Height of the notch hanging down
    final cornerRadius = 25.0; // Radius for search bar ends
    final smoothRadius = 12.0; // Radius for the smooth transition
    
    // Start top-left of search bar
    path.moveTo(cornerRadius, 0);
    
    // Top line
    path.lineTo(size.width - cornerRadius, 0);
    
    // Top-right corner
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    
    // Right side of search bar
    path.lineTo(size.width, searchBarHeight - cornerRadius);
    
    // Bottom-right corner of search bar
    path.arcToPoint(
      Offset(size.width - cornerRadius, searchBarHeight),
      radius: Radius.circular(cornerRadius),
    );
    
    // Bottom line to notch start (Right side)
    final notchRightStart = (size.width + notchWidth) / 2;
    path.lineTo(notchRightStart + smoothRadius, searchBarHeight);
    
    // Smooth transition to notch (Right)
    path.cubicTo(
      notchRightStart, searchBarHeight, // Control point 1
      notchRightStart, searchBarHeight, // Control point 2
      notchRightStart, searchBarHeight + smoothRadius, // End point
    );
    
    // Right side of notch
    path.lineTo(notchRightStart, searchBarHeight + notchHeight - smoothRadius);
    
    // Bottom-right corner of notch
    path.arcToPoint(
      Offset(notchRightStart - smoothRadius, searchBarHeight + notchHeight),
      radius: Radius.circular(smoothRadius),
    );
    
    // Bottom of notch
    final notchLeftStart = (size.width - notchWidth) / 2;
    path.lineTo(notchLeftStart + smoothRadius, searchBarHeight + notchHeight);
    
    // Bottom-left corner of notch
    path.arcToPoint(
      Offset(notchLeftStart, searchBarHeight + notchHeight - smoothRadius),
      radius: Radius.circular(smoothRadius),
    );
    
    // Left side of notch
    path.lineTo(notchLeftStart, searchBarHeight + smoothRadius);
    
    // Smooth transition from notch (Left)
    path.cubicTo(
      notchLeftStart, searchBarHeight, // Control point 1
      notchLeftStart, searchBarHeight, // Control point 2
      notchLeftStart - smoothRadius, searchBarHeight, // End point
    );
    
    // Bottom line to start (Left side)
    path.lineTo(cornerRadius, searchBarHeight);
    
    // Bottom-left corner of search bar
    path.arcToPoint(
      Offset(0, searchBarHeight - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    
    // Left side of search bar
    path.lineTo(0, cornerRadius);
    
    // Top-left corner
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );
    
    path.close();
    
    // Draw shadow
    canvas.drawShadow(path, Colors.black, 8.0, true);
    
    // Draw fill
    canvas.drawPath(path, paint);
    
    // Draw border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PostSearchDelegate extends SearchDelegate<MapPost?> {
  final List<MapPost> posts;

  PostSearchDelegate(this.posts);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = posts.where((post) {
      final title = post.title.toLowerCase();
      final description = post.description.toLowerCase();
      final searchLower = query.toLowerCase();
      return title.contains(searchLower) || description.contains(searchLower);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final post = results[index];
        return ListTile(
          title: Text(post.title),
          subtitle: Text(post.description),
          onTap: () {
            close(context, post);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = posts.where((post) {
      final title = post.title.toLowerCase();
      final description = post.description.toLowerCase();
      final searchLower = query.toLowerCase();
      return title.contains(searchLower) || description.contains(searchLower);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final post = results[index];
        return ListTile(
          title: Text(post.title),
          subtitle: Text(post.description),
          onTap: () {
            close(context, post);
          },
        );
      },
    );
  }
}
