import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/ad_banner.dart';
import '../widgets/vote_buttons.dart';
import '../widgets/post_map_snapshot.dart';
import '../screens/trick_history_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  late Future<List<MapPost>> _allPostsFuture;

  @override
  void initState() {
    super.initState();
    _allPostsFuture = SupabaseService.getAllMapPostsWithVotes();
  }



  void _refreshPosts() {
    setState(() {
      _allPostsFuture = SupabaseService.getAllMapPostsWithVotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pushinn'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: FutureBuilder<List<MapPost>>(
              future: _allPostsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No posts yet. Create a post from the Map tab!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _allPostsFuture = SupabaseService.getAllMapPostsWithVotes();
                    });
                  },
                  child: ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final currentUser = SupabaseService.getCurrentUser();
                      final isOwnPost = currentUser?.id == post.userId;
                      
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Vote buttons on the left
                              VoteButtons(
                                postId: post.id!,
                                voteScore: post.voteScore,
                                userVote: post.userVote,
                                isOwnPost: isOwnPost,
                                onVoteChanged: _refreshPosts,
                              ),
                              const SizedBox(width: 12),
                              // Post content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User info header
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.green,
                                          child: Text(
                                            (post.userName?.isNotEmpty ?? false)
                                                ? post.userName![0].toUpperCase()
                                                : (post.userEmail?.isNotEmpty ?? false)
                                                    ? post.userEmail![0].toUpperCase()
                                                    : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            post.userName ?? 
                                                (post.userEmail != null 
                                                    ? post.userEmail!.split('@')[0] 
                                                    : 'Unknown User'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 12),
                              if (post.photoUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    post.photoUrl!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.image_not_supported),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                post.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Location: ${post.latitude.toStringAsFixed(4)}, ${post.longitude.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.createdAt.toString().substring(0, 16),
                                style:
                                    Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                              ),
                              const SizedBox(height: 12),
                              PostMapSnapshot(
                                latitude: post.latitude,
                                longitude: post.longitude,
                              ),
                              const SizedBox(height: 8),
                              // Star Ratings
                              StarRatingDisplay(
                                popularityRating: post.popularityRating,
                                securityRating: post.securityRating,
                                qualityRating: post.qualityRating,
                              ),
                              const SizedBox(height: 12),
                              // Bottom action row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // History button - bottom left
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TrickHistoryScreen(spot: post),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.history, size: 18),
                                    label: const Text('History'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                  // Comment button - bottom right
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Comments coming in v1.1!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sharing coming in v1.1!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                                    ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
