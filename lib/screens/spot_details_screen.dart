import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../models/post.dart';
import '../models/spot_video.dart';
import '../services/supabase_service.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/vote_buttons.dart';
import '../utils/error_helper.dart';
import 'edit_post_dialog.dart';
import 'trick_submission_dialog.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/mini_map_snapshot.dart';
import '../providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

class SpotDetailsScreen extends StatefulWidget {
  final MapPost post;

  const SpotDetailsScreen({super.key, required this.post});

  @override
  State<SpotDetailsScreen> createState() => _SpotDetailsScreenState();
}

class _SpotDetailsScreenState extends State<SpotDetailsScreen> {
  late MapPost currentPost;
  bool _isOwnPost = false;
  List<SpotVideo> _tricks = [];
  bool _isLoadingTricks = true;
  String _sortBy = 'recent';
  int _usersAtSpot = 0;
  bool _isLoadingUsers = true;

  // Matrix theme colors
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);
  static const Color matrixDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _checkOwnership();
    _loadTricks();
    _loadUsersAtSpot();
  }

  void _checkOwnership() {
    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId != null) {
      setState(() {
        _isOwnPost = currentPost.userId == userId;
      });
    }
  }

  Future<void> _loadTricks() async {
    setState(() => _isLoadingTricks = true);
    
    try {
      // Placeholder for trick loading logic
      // In a real implementation, this would fetch from Supabase
      // await SupabaseService.getSpotVideos(currentPost.id!, _sortBy);
      
      // Simulating network delay and empty list for now
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _tricks = []; // Placeholder
          _isLoadingTricks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTricks = false);
        // ErrorHelper.showError(context, 'Error loading tricks: $e');
      }
    }
  }

  Future<void> _loadUsersAtSpot() async {
    if (currentPost.latitude == null || currentPost.longitude == null) {
      setState(() {
        _usersAtSpot = 0;
        _isLoadingUsers = false;
      });
      return;
    }

    setState(() => _isLoadingUsers = true);
    
    try {
      // Get users near this spot (within 100m)
      final nearbyUsers = await SupabaseService.getNearbyOnlineUsers(
        currentPost.latitude!,
        currentPost.longitude!,
        radiusInMeters: 100,
      );
      
      if (mounted) {
        setState(() {
          _usersAtSpot = nearbyUsers.length;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _showEditDialog() async {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: currentPost,
        onPostUpdated: () async {
          // Refresh post data
          try {
            final updatedPosts = await SupabaseService.getAllMapPosts();
            final updated = updatedPosts.firstWhere(
              (p) => p.id == currentPost.id,
              orElse: () => currentPost,
            );
            if (mounted) {
              setState(() {
                currentPost = updated;
              });
            }
          } catch (e) {
            // Silently fail
          }
        },
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: matrixDark,
        title: const Text('Report Post', style: TextStyle(color: matrixGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this post?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                hintText: 'e.g., Inappropriate content, Spam',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Details (Optional)',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                hintText: 'Provide more context...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: matrixGreen.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ErrorHelper.showError(context, 'Please provide a reason');
                return;
              }

              try {
                await SupabaseService.reportPost(
                  postId: currentPost.id!,
                  reason: reasonController.text.trim(),
                  details: detailsController.text.trim().isEmpty
                      ? null
                      : detailsController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully'),
                      backgroundColor: matrixGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHelper.showError(context, 'Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubmissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TrickSubmissionDialog(spotId: currentPost.id!, onTrickSubmitted: () {}),
    );
    
    if (result == true) {
      _loadTricks();
    }
  }

  Future<void> _launchVideo(SpotVideo trick) async {
    if (trick.url.isEmpty) {
      ErrorHelper.showError(context, 'No video link for this trick yet');
      return;
    }
    
    final uri = Uri.parse(trick.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ErrorHelper.showError(context, 'Could not open video');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = colorScheme.primary;
    final matrixBlack = colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? matrixGreen;
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? matrixGreen.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: matrixBlack,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: matrixBlack,
            foregroundColor: matrixGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                currentPost.title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: isDark ? Colors.black : Colors.white, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (currentPost.videoUrl != null)
                    VideoPlayerWidget(videoUrl: currentPost.videoUrl!)
                  else if (currentPost.photoUrls.isNotEmpty)
                    Stack(
                      children: [
                        PageView.builder(
                          itemCount: currentPost.photoUrls.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              currentPost.photoUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: matrixDark,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        if (currentPost.photoUrls.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                currentPost.photoUrls.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (currentPost.photoUrl != null)
                    Image.network(
                      currentPost.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: matrixDark,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: matrixDark,
                      child: Center(
                        child: Icon(Icons.skateboarding, color: matrixGreen, size: 80),
                      ),
                    ),
                  // Gradient overlay for text readability
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                          Colors.black,
                        ],
                        stops: [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isOwnPost)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _showEditDialog,
                  tooltip: 'Edit Spot',
                ),
              IconButton(
                icon: const Icon(Icons.flag),
                onPressed: _showReportDialog,
                tooltip: 'Report Spot',
              ),
            ],
          ),

          // Spot Details Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info & Date
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: matrixGreen,
                        backgroundImage: currentPost.avatarUrl != null
                            ? NetworkImage(currentPost.avatarUrl!)
                            : null,
                        child: currentPost.avatarUrl == null
                            ? Text(
                                (currentPost.userName?.isNotEmpty == true)
                                    ? currentPost.userName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentPost.userName?.isNotEmpty == true
                                ? currentPost.userName!
                                : 'Unknown Skater',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            currentPost.createdAt.toString().substring(0, 10),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Vote Buttons
                      VoteButtons(
                        postId: currentPost.id!,
                        voteScore: currentPost.voteScore,
                        userVote: currentPost.userVote,
                        isOwnPost: _isOwnPost,
                        orientation: Axis.horizontal,
                        onVoteChanged: () async {
                          // Refresh post data to show updated vote count
                          try {
                            final allPosts = await SupabaseService.getAllMapPosts();
                            final updatedPost = allPosts.firstWhere(
                              (p) => p.id == currentPost.id,
                              orElse: () => currentPost,
                            );
                            if (mounted) {
                              setState(() {
                                currentPost = updatedPost;
                              });
                            }
                          } catch (e) {
                            print('DEBUG: Error refreshing post after vote: $e');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    currentPost.description,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mini Map Preview - tappable to go to map tab (Only if location exists)
                  if (currentPost.latitude != null && currentPost.longitude != null)
                    GestureDetector(
                      onTap: () {
                        // Navigate to map tab and center on this spot
                        final navProvider = Provider.of<NavigationProvider>(context, listen: false);
                        navProvider.setIndex(
                          2, // Map tab is index 2
                          targetLocation: LatLng(currentPost.latitude!, currentPost.longitude!),
                        );
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: matrixGreen.withValues(alpha: 0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: matrixGreen.withValues(alpha: 0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              MiniMapSnapshot(
                                latitude: currentPost.latitude!,
                                longitude: currentPost.longitude!,
                              ),
                              // Overlay with "View on Map" label
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                       Icon(
                                         Icons.map,
                                         color: matrixGreen,
                                         size: 18,
                                       ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'TAP TO VIEW ON MAP',
                                        style: TextStyle(
                                          color: Color(0xFF00FF41),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Ratings
                  Row(
                    children: [
                      _buildRatingChip(
                        Icons.local_fire_department_rounded,
                        'Popularity',
                        currentPost.popularityRating,
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildRatingChip(
                        Icons.shield_rounded,
                        'Security',
                        currentPost.securityRating,
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildRatingChip(
                        Icons.star_rounded,
                        'Quality',
                        currentPost.qualityRating,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Location with clickable coordinates (Only if location exists)
                  if (currentPost.latitude != null && currentPost.longitude != null)
                    GestureDetector(
                      onTap: () async {
                        // Open directions in native maps app
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${currentPost.latitude},${currentPost.longitude}'
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: matrixGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, color: matrixGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${currentPost.latitude!.toStringAsFixed(5)}, ${currentPost.longitude!.toStringAsFixed(5)}',
                              style: TextStyle(
                                color: matrixGreen.withValues(alpha: 0.8),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.directions,
                              color: matrixGreen,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (currentPost.latitude != null && currentPost.longitude != null)
                    const SizedBox(height: 16),
                  
                  // Users at spot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _usersAtSpot > 0 && !_isLoadingUsers
                          ? Colors.red.withValues(alpha: 0.1)
                          : matrixGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: matrixGreen,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: matrixGreen.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people,
                            color: matrixGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SKATERS AT THIS SPOT',
                                style: TextStyle(
                                  color: matrixGreen.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isLoadingUsers
                                  ? Text(
                                      'Loading...',
                                      style: TextStyle(
                                        color: matrixGreen.withValues(alpha: 0.5),
                                        fontSize: 12,
                                      ),
                                    )
                                  : Text(
                                      _usersAtSpot == 0
                                          ? 'Nobody here right now'
                                          : _usersAtSpot == 1
                                              ? '1 person here now'
                                              : '$_usersAtSpot people here now',
                                      style: TextStyle(
                                        color: matrixGreen,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        if (_usersAtSpot > 0 && !_isLoadingUsers)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: matrixGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🔥 ACTIVE',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  

                  Divider(color: isDark ? Colors.white24 : Colors.black12),
                  const SizedBox(height: 16),
                  
                  // Trick History Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRICK HISTORY',
                        style: TextStyle(
                          color: matrixGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                        ),
                      ),
                      PopupMenuButton<String>(
                        initialValue: _sortBy,
                        icon: Icon(Icons.sort, color: matrixGreen),
                        color: matrixDark,
                        onSelected: (value) {
                          setState(() => _sortBy = value);
                          _loadTricks();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'recent',
                            child: Text('Most Recent'),
                          ),
                          const PopupMenuItem(
                            value: 'popular',
                            child: Text('Most Popular'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Trick List
          if (_isLoadingTricks)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: matrixGreen),
                ),
              ),
            )
          else if (_tricks.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.skateboarding, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'No tricks landed yet.',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to claim this spot!',
                      style: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final trick = _tricks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildTrickItem(trick),
                  );
                },
                childCount: _tricks.length,
              ),
            ),
            
          // Bottom Padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmissionDialog,
        backgroundColor: matrixGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('LOG TRICK', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTrickItem(SpotVideo trick) {
    return Container(
      decoration: BoxDecoration(
        color: matrixDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            image: trick.thumbnailUrl != null 
                ? DecorationImage(image: NetworkImage(trick.thumbnailUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: trick.thumbnailUrl == null 
              ? const Center(child: Icon(Icons.play_circle, color: matrixGreen))
              : null,
        ),
        title: Text(
          trick.displayTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          trick.timeAgo,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_up, size: 14, color: matrixGreen.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              '${trick.upvotes}',
              style: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
            ),
          ],
        ),
        onTap: () => _launchVideo(trick),
      ),
    );
  }
  Widget _buildRatingChip(IconData icon, String label, double rating, Color color) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: matrixGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: matrixGreen.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: matrixGreen),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: matrixGreen,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: index < rating ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
                  size: 12,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
