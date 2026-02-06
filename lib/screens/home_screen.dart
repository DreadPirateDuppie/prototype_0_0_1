import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../tabs/map_tab.dart';
import '../tabs/feed_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/rewards_tab.dart';
import '../tabs/vs_tab.dart';
import '../services/connectivity_service.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/battle_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/navigation/pushinn_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  String? _avatarUrl;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _glowAnimations;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    
    // Create animation controllers for each nav item
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    
    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
    
    _glowAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh battles when app resumes to check for expired timers
      context.read<BattleProvider>().refresh();
    }
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
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    if (navProvider.selectedIndex == index) {
      // If tapping the same tab, pop to root
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      navProvider.setIndex(index);
      
      // Animate the selected item
      for (int i = 0; i < _controllers.length; i++) {
        if (i == index) {
          _controllers[i].forward();
        } else {
          _controllers[i].reverse();
        }
      }
    }
  }

  final GlobalKey<MapTabState> _mapTabKey = GlobalKey<MapTabState>();

  void _navigateToMap(LatLng location) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
    // Pop to root of map tab first to ensure we see the map
    _navigatorKeys[2].currentState?.popUntil((route) => route.isFirst);
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapTabKey.currentState?.moveToLocation(location);
    });
  }

  Widget _buildTabContent(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return FeedTab(onNavigateToMap: _navigateToMap);
      case 1:
        return const VsTab();
      case 2:
        return MapTab(key: _mapTabKey);
      case 3:
        return const RewardsTab();
      case 4:
        return const ProfileTab();
      default:
        return MapTab(key: _mapTabKey);
    }
  }

  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => _buildTabContent(index),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        // Trigger animations on index change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (int i = 0; i < _controllers.length; i++) {
            if (i == navProvider.selectedIndex) {
              _controllers[i].forward();
            } else {
              _controllers[i].reverse();
            }
          }
        });
        
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            final isFirstRouteInCurrentTab = !await _navigatorKeys[navProvider.selectedIndex].currentState!.maybePop();
            
            if (isFirstRouteInCurrentTab) {
              // If on the first route of the current tab, let the app exit or handle back
              if (navProvider.selectedIndex != 2) {
                // If not on the map (default tab), go back to the map
                _onItemTapped(2);
              } else {
                // If on the first tab, exit the app (or let system handle it if we returned true above, but we returned false)
                // Since we returned false, we need to manually pop if we want to exit, but usually we just want to minimize or let Android handle it.
                // For now, let's just allow pop if we are at root of tab 0
                 if (context.mounted) Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent, // Show global Matrix
            extendBody: true,
            body: Column(
              children: [
                ConnectivityService.buildOfflineBanner(context),
                Expanded(
                  child: IndexedStack(
                    index: navProvider.selectedIndex,
                    children: [
                      _buildNavigator(0), // Feed
                      _buildNavigator(1), // VS
                      _buildNavigator(2), // Map
                      _buildNavigator(3), // Rewards
                      _buildNavigator(4), // Profile
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: PushinnNavBar(
              currentIndex: navProvider.selectedIndex,
              avatarUrl: _avatarUrl,
              onItemTapped: _onItemTapped,
              scaleAnimations: _scaleAnimations,
              glowAnimations: _glowAnimations,
            ),
          ),
        );
      },
    );
  }
}
