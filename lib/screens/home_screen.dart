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

  @override
  void initState() {
    super.initState();
    // Check daily streak on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SupabaseService.checkDailyStreak();
    });
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
        return const ProfileTab();
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
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.feed),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_kabaddi),
              label: 'VS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard),
              label: 'Rewards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
    );
  }
}
