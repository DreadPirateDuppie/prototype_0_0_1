import 'package:flutter/material.dart';
import '../tabs/map_tab.dart';
import '../tabs/feed_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/rewards_tab.dart';
import '../tabs/vs_tab.dart';
import '../tabs/settings_tab.dart';
import '../services/connectivity_service.dart';

/// Public interface for the HomeScreen state that can be used by other widgets
abstract class HomeScreenState {
  /// Whether the state is currently in the widget tree
  bool get mounted;

  /// Changes the currently selected tab
  void setTab(int index, {bool editMode = false});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.keyForTesting});

  final Key? keyForTesting;

  static HomeScreenState? of(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    assert(state != null, 'No HomeScreenState found in context');
    return state;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements HomeScreenState {
  int _selectedIndex = 2; // Start with Map tab (index 2)
  bool _shouldEditProfile = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void setTab(int index, {bool editMode = false}) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
        _shouldEditProfile = editMode;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _shouldEditProfile = false; // Reset edit mode when manually changing tabs
    });
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return const FeedTab();
      case 1:
        return const MapTab();
      case 2:
        return const VsTab();
      case 3:
        return const RewardsTab();
      case 4:
        return ProfileTab(editMode: _shouldEditProfile);
      case 5:
        return const SettingsTab();
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
        currentIndex: _selectedIndex >= 5
            ? 4
            : _selectedIndex, // Handle settings tab index
        onTap: (index) {
          // Only allow navigation to tabs 0-4 (Feed, Map, VS, Rewards, Profile)
          if (index < 5) {
            _onItemTapped(index);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_kabaddi),
            label: 'VS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
