import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile/profile_header.dart';

// Removed ProfileStatsRow as it's replaced by UserStatsCard
import '../widgets/profile/profile_media_grid.dart';
import '../widgets/user_stats_card.dart';
import '../screens/followers_list_screen.dart';
import 'settings_tab.dart';
import '../config/theme_config.dart';
import '../services/supabase_service.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const _ProfileTabContent(),
    );
  }
}

class _ProfileTabContent extends StatefulWidget {
  const _ProfileTabContent();

  @override
  State<_ProfileTabContent> createState() => _ProfileTabContentState();
}

class _ProfileTabContentState extends State<_ProfileTabContent> {
  final _currentUser = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProfileProvider>().loadProfile(_currentUser.id);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.profileData == null) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        final profileData = provider.profileData;
        if (profileData == null) {
          return const Center(child: Text('Failed to load profile'));
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.transparent, // Let global Matrix show through
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 120.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent, // Show global Matrix
                    elevation: 0,
                    flexibleSpace: const FlexibleSpaceBar(
                      background: SizedBox.expand(),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsTab()),
                          );
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        ProfileHeader(
                          profileData: profileData,
                          isCurrentUser: true,
                        ),
                        const SizedBox(height: 12),
                        if (provider.userScores != null) ...[
                          const SizedBox(height: 8),
                          UserStatsCard(
                            scores: provider.userScores!,
                            followersCount: provider.followersCount,
                            followingCount: provider.followingCount,
                            postCount: provider.userPosts.length,
                            initiallyExpanded: false,
                            onPostsTap: () {
                              // Maybe switch to Posts tab?
                              DefaultTabController.of(context).animateTo(0);
                            },
                            onFollowersTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowersListScreen(
                                    userId: _currentUser!.id,
                                    username: profileData['username'],
                                    initialTab: 0,
                                  ),
                                ),
                              );
                            },
                            onFollowingTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowersListScreen(
                                    userId: _currentUser!.id,
                                    username: profileData['username'],
                                    initialTab: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        indicatorColor: ThemeColors.matrixGreen,
                        labelColor: ThemeColors.matrixGreen,
                        unselectedLabelColor: Colors.white60,
                        tabs: [
                          Tab(text: 'Posts', icon: Icon(Icons.grid_on)),
                          Tab(text: 'Media', icon: Icon(Icons.perm_media)),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  ProfileMediaGrid(
                    posts: provider.userPosts,
                    isLoading: provider.isLoading,
                  ),
                  _buildMediaTab(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getProfileMedia(_currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }
        
        final mediaList = snapshot.data ?? [];
        
        if (mediaList.isEmpty) {
           return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.perm_media_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No media yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: mediaList.length,
          itemBuilder: (context, index) {
            final media = mediaList[index];
            final mediaUrl = media['media_url'];
            final isVideo = media['media_type'] == 'video';
            
            return GestureDetector(
              onTap: () {
                if (mediaUrl == null) return;
                // Show full screen media viewer
                 showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          child: Image.network(
                            mediaUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.error, color: Colors.white, size: 50),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  image: mediaUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(mediaUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: isVideo
                    ? const Center(
                        child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                      )
                    : (mediaUrl == null 
                        ? const Center(child: Icon(Icons.broken_image, color: Colors.white24))
                        : null),
              ),
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent, // Let Matrix show under tabs
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
