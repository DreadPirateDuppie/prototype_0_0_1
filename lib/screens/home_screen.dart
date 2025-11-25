import 'package:flutter/material.dart';
import '../tabs/map_tab.dart';
import '../tabs/feed_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/rewards_tab.dart';
import '../tabs/vs_tab.dart';
import '../services/connectivity_service.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Check daily streak on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SupabaseService.checkDailyStreak();
    });
  }

  Future<void> _loadUserProfile() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      final url = await SupabaseService.getUserAvatarUrl(user.id);
      if (mounted && url != null) {
        setState(() {
          _avatarUrl = url;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return const FeedTab();
      case 1:
        return const VsTab();
      case 2:
        return const MapTab();
      case 3:
        return const RewardsTab();
      case 4:
        return ProfileTab(
          onProfileUpdated: () {
            _loadUserProfile();
          },
        );
      default:
        return const MapTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ConnectivityService.buildOfflineBanner(context),
          Expanded(child: _buildTabContent()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF00FF41).withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFF00FF41),
          unselectedItemColor: const Color(0xFF008F11),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'monospace',
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Feed',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.sports_kabaddi_outlined),
              activeIcon: Icon(Icons.sports_kabaddi),
              label: 'VS',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: 'Map',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Rewards',
            ),
            BottomNavigationBarItem(
              icon: _avatarUrl != null
                  ? CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(_avatarUrl!),
                      backgroundColor: Colors.transparent,
                    )
                  : const Icon(Icons.person_outline),
              activeIcon: _avatarUrl != null
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00FF41),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(_avatarUrl!),
                        backgroundColor: Colors.transparent,
                      ),
                    )
                  : const Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
