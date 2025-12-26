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
import 'dart:ui';

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
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    
    // Animate the selected item
    for (int i = 0; i < _controllers.length; i++) {
      if (i == index) {
        _controllers[i].forward();
      } else {
        _controllers[i].reverse();
      }
    }
  }

  final GlobalKey<MapTabState> _mapTabKey = GlobalKey<MapTabState>();

  void _navigateToMap(LatLng location) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
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
        return ProfileTab(onProfileUpdated: _loadUserProfile);
      default:
        return MapTab(key: _mapTabKey);
    }
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
        
        return Scaffold(
          extendBody: true,
          body: Column(
            children: [
              ConnectivityService.buildOfflineBanner(context),
              Expanded(child: _buildTabContent(navProvider.selectedIndex)),
            ],
          ),
          bottomNavigationBar: _buildFloatingNavBar(navProvider.selectedIndex),
        );
      },
    );
  }

  Widget _buildFloatingNavBar(int currentIndex) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = colorScheme.primary;
    
    
    return SafeArea(
      child: Container(
        height: 85, // Increased height to accommodate overlap
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none, // Allow button to overflow
          children: [
            // Main Navigation Bar Background
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  // Drop shadow for the nav bar
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 5),
                  ),
                  // Subtle neon glow for the nav bar
                  BoxShadow(
                    color: matrixGreen.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark 
                          ? [
                              const Color(0xFF0A0A0A).withValues(alpha: 0.9),
                              const Color(0xFF000000).withValues(alpha: 0.95),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.9),
                              const Color(0xFFF5F5F5).withValues(alpha: 0.95),
                            ],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        width: 1.5,
                        color: matrixGreen.withValues(alpha: 0.6), // Neon green outline
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _buildNavItem(Icons.dashboard, 'Feed', 0, currentIndex)),
                        Expanded(child: _buildNavItem(Icons.sports_kabaddi, 'VS', 1, currentIndex)),
                        const Spacer(), // Space for the center button
                        Expanded(child: _buildNavItem(Icons.emoji_events, 'Rewards', 3, currentIndex)),
                        Expanded(child: _buildNavItem(Icons.person, 'Profile', 4, currentIndex, avatarUrl: _avatarUrl)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Floating Map Button (Diamond)
            Positioned(
              bottom: 10, // Raised from 5 to 10
              child: _buildCenterNavItem(Icons.location_on, 'Map', 2, currentIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex, {String? avatarUrl}) {
    final isSelected = index == currentIndex;
    final theme = Theme.of(context);
    final matrixGreen = theme.colorScheme.primary;
    

    return AnimatedBuilder(
      animation: _scaleAnimations[index],
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimations[index].value,
          child: InkWell(
            onTap: () => _onItemTapped(index),
            borderRadius: BorderRadius.circular(20),
            splashColor: matrixGreen.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2), // Reduced from 6 to fit larger profile pic
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _glowAnimations[index],
                    builder: (context, child) {
                      return Container(
                        padding: index == 4 ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? matrixGreen.withValues(alpha: 0.15)
                              : Colors.transparent,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: matrixGreen.withValues(alpha: 0.3),
                                    blurRadius: _glowAnimations[index].value * 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: avatarUrl != null && index == 4
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: matrixGreen,
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: matrixGreen.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: CircleAvatar(
                                  radius: 20, // Balanced size (was 24)
                                  backgroundImage: NetworkImage(avatarUrl),
                                  backgroundColor: Colors.transparent,
                                ),
                              )
                            : index == 1 // VS Tab
                                ? Text(
                                    'VS',
                                    style: TextStyle(
                                      color: isSelected ? matrixGreen : Colors.grey[600],
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                      letterSpacing: -1,
                                    ),
                                  )
                                : Icon(
                                    icon,
                                    color: isSelected ? matrixGreen : Colors.grey[600],
                                    size: 24,
                                  ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterNavItem(IconData icon, String label, int index, int currentIndex) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = theme.colorScheme.primary;
    
    
    return AnimatedBuilder(
      animation: _scaleAnimations[index],
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimations[index].value,
          child: InkWell(
            onTap: () => _onItemTapped(index),
            borderRadius: BorderRadius.circular(15), // Adjusted for diamond
            splashColor: matrixGreen.withValues(alpha: 0.3),
            child: Transform(
              transform: Matrix4.diagonal3Values(0.8, 1.0, 1.0), // Make it skinner (80% width)
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: 0.785398, // 45 degrees in radians
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(12),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8), // Sharper corners for diamond
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                        ? [
                            const Color(0xFF1A1A1A),
                            const Color(0xFF0F0F0F),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF5F5F5),
                          ],
                    ),
                    boxShadow: [
                      // Drop shadow
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      // Neon glow (only when selected)
                      if (isSelected)
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.8),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                    ],
                    border: Border.all(
                    color: isSelected ? matrixGreen : matrixGreen.withValues(alpha: 0.3), // Dim when not selected
                    width: 2,
                  ),
                ),
                child: Transform.rotate(
                    angle: -0.785398, // Counter-rotate icon (-45 degrees)
                    child: Transform(
                      transform: Matrix4.diagonal3Values(1.25, 1.0, 1.0), // Un-squash icon (1/0.8 = 1.25)
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: isSelected ? matrixGreen : Colors.grey[600], // Green when selected
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
