import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import '../../providers/admin_provider.dart';
import '../../models/post.dart';
import '../../screens/post_detail_screen.dart';

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'REPORTS'),
              Tab(text: 'U_SPOTS'),
              Tab(text: 'P_VIDEOS'),
            ],
            labelColor: ThemeColors.matrixGreen,
            unselectedLabelColor: Colors.white24,
            indicatorColor: ThemeColors.matrixGreen,
            labelStyle: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ReportsList(),
                _UnverifiedSpotsList(),
                _PendingVideosList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.reports.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        if (provider.reports.isEmpty) {
          return const Center(
            child: Text(
              'NO_REPORTS_QUEUED',
              style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 12),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadReports,
          child: ListView.builder(
            itemCount: provider.reports.length,
            itemBuilder: (context, index) {
              final report = provider.reports[index];
              final post = report['map_posts'];
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  title: Text(
                    '>_REPORT: ${report['reason']}',
                    style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'TARGET: ${post != null ? post['title'] : 'UNKNOWN_ENTITY'}',
                    style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20, color: Colors.white70),
                        onPressed: () {
                          if (post != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(
                                  post: MapPost.fromMap(post),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, size: 20, color: ThemeColors.matrixGreen),
                        onPressed: () => provider.dismissReport(report['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _UnverifiedSpotsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.unverifiedPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        if (provider.unverifiedPosts.isEmpty) {
          return const Center(
            child: Text(
              'ALL_SPOTS_VERIFIED',
              style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 12),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadUnverifiedPosts,
          child: ListView.builder(
            itemCount: provider.unverifiedPosts.length,
            itemBuilder: (context, index) {
              final post = provider.unverifiedPosts[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      image: post.photoUrls.isNotEmpty
                          ? DecorationImage(image: NetworkImage(post.photoUrls.first), fit: BoxFit.cover)
                          : null,
                    ),
                    child: post.photoUrls.isEmpty
                        ? const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 20))
                        : null,
                  ),
                  title: Text(
                    post.title,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    post.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20, color: Colors.white70),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.verified_outlined, size: 20, color: Colors.blueAccent),
                        onPressed: () => provider.verifyPost(post.id ?? ''),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PendingVideosList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.pendingVideos.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        if (provider.pendingVideos.isEmpty) {
          return const Center(
            child: Text(
              'ZERO_PENDING_STREAMS',
              style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 12),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadPendingVideos,
          child: ListView.builder(
            itemCount: provider.pendingVideos.length,
            itemBuilder: (context, index) {
              final video = provider.pendingVideos[index];
              final postTitle = video['map_posts']?['title'] ?? 'Unknown Spot';
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  title: Text(
                    video['trick_name'] ?? 'ST_VID: $postTitle',
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'NODE_ID: ${video['user_id']}',
                    style: const TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace', fontSize: 9),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_outlined, size: 20, color: ThemeColors.matrixGreen),
                        onPressed: () => provider.moderateVideo(video['id'], 'approved'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_outlined, size: 20, color: Colors.redAccent),
                        onPressed: () => provider.moderateVideo(video['id'], 'rejected'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
