import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';
import '../screens/spot_details_screen.dart';
import '../screens/location_privacy_dialog.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';
import '../providers/navigation_provider.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => MapTabState();
}

class MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this tab alive in the background
  
  late MapController mapController;
  List<Marker> markers = [];
  List<Marker> nonClusterMarkers = [];
  List<MapPost> userPosts = [];
  Map<String, MapPost> markerPostMap = {}; // Map marker location to post
  LatLng currentLocation = const LatLng(37.7749, -122.4194); // Default: SF
  bool _isLoadingLocation = false;
  bool _isPinMode = false;
  bool _isSharingLocation = false; // Slider: Others can see you
  bool _hasLocationPermission = false; // User's location is visible to self
  String _sharingMode = 'off';

  final String _selectedCategory = 'All';
  bool _hasExplicitlyNavigated = false; // Track if user has manually navigated

  void moveToLocation(LatLng location) {
    _hasExplicitlyNavigated = true; // Mark that we've manually navigated
    mapController.move(location, 17.0); // Increased zoom for better detail
  }

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _addSampleMarkers();
    _loadUserPosts();
    // Automatically get location and privacy settings
    _getCurrentLocation();
    _loadPrivacySettings();
    
    // Check for target location from navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);
      if (navProvider.targetLocation != null) {
        moveToLocation(navProvider.targetLocation!);
        navProvider.clearTargetLocation();
      }
    });
  }

  Future<void> _loadUserPosts() async {
    try {
      // Load posts with filter
      final posts = await SupabaseService.getAllMapPosts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      
      // Load online friends
      final friends = await SupabaseService.getMutualFollowers();
      final visibleLocations = await SupabaseService.getVisibleUserLocations();
      final onlineFriends = visibleLocations.where((user) => friends.any((friend) => friend['id'] == user['id'])).toList();

      if (mounted) {
        setState(() {
          userPosts = posts;
          // Create new lists to ensure state update
          markers = []; // This will now hold only clusterable markers (posts)
          nonClusterMarkers = []; // This will hold non-clusterable markers (user location + friends)
          markerPostMap.clear();
          
          _addSampleMarkers(); // Adds to markers (clusterable)
          
          // Always add user location if permission granted
          if (_hasLocationPermission) {
            _addMarkerToList(
              currentLocation,
              'Your Location',
              'You are here',
              Colors.blue,
              isUserLocation: true,
              addToNonCluster: true,
            );
          }
          
          // Calculate active pushers per spot
          final Map<String, int> spotSessionCounts = {};
          final List<Map<String, dynamic>> friendsAtSpots = [];
          const distanceThreshold = 100.0; // meters

          for (final friend in onlineFriends) {
            if (friend['current_latitude'] != null && friend['current_longitude'] != null) {
              final friendLoc = LatLng(friend['current_latitude'], friend['current_longitude']);
              bool isAtSpot = false;

              for (final post in posts) {
                if (post.latitude == null || post.longitude == null) continue;
                
                final postLoc = LatLng(post.latitude!, post.longitude!);
                final distance = const Distance().as(LengthUnit.Meter, friendLoc, postLoc);
                
                if (distance <= distanceThreshold && post.id != null) {
                  spotSessionCounts[post.id!] = (spotSessionCounts[post.id!] ?? 0) + 1;
                  isAtSpot = true;
                  friendsAtSpots.add(friend);
                  break; // Only count for the first matching spot
                }
              }

              // If friend is NOT at a spot, show individual marker
              if (!isAtSpot) {
                _addMarkerToList(
                  friendLoc,
                  friend['display_name'] ?? friend['username'] ?? 'Friend',
                  'Online now',
                  Colors.red, // Red color for friend markers
                  addToNonCluster: true, // Don't cluster friends
                  isUserLocation: false, // Use pin style
                  isFriend: true, // Use precise icon
                );
              }
            }
          }

          _addUserPostMarkers(spotSessionCounts); // Adds to markers (clusterable)
          debugPrint('MapTab: Updated markers. Cluster: ${markers.length}, Non-Cluster: ${nonClusterMarkers.length}');
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      // Silently fail
    }
  }




  void _addUserPostMarkers(Map<String, int> spotSessionCounts) {
    for (final post in userPosts) {
      if (post.id == null || post.latitude == null || post.longitude == null) continue;
      final activePushers = spotSessionCounts[post.id!] ?? 0;
      _addMarkerToList(
        LatLng(post.latitude!, post.longitude!),
        post.title,
        post.description,
        Colors.green,
        postId: post.id,
        post: post,
        activePushers: activePushers,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
           setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
         setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
          if (mounted) {
             ErrorHelper.showError(context, 'Location permission permanently denied. Please enable in settings.');
          }
          return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );

      if (mounted) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          currentLocation = newLocation;
          _isLoadingLocation = false;
          _hasLocationPermission = true;
        });

        // Only animate to current location if user hasn't explicitly navigated elsewhere
        if (!_hasExplicitlyNavigated) {
          mapController.move(newLocation, 14.0);
        }

        // Rebuild markers to include location
        _loadUserPosts();
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _hasLocationPermission = false;
      });
      if (mounted) {
        ErrorHelper.showError(context, 'Error getting location: $e');
      }
    }
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final settings = await SupabaseService.getLocationPrivacySettings();
      if (mounted) {
        setState(() {
          _sharingMode = settings['sharing_mode'] as String;
          _isSharingLocation = _sharingMode != 'off';
        });
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    }
  }

  Future<void> _toggleLocationSharing(bool value) async {
    // Update sharing state
    setState(() {
      _isSharingLocation = value;
    });

    // Update backend based on current privacy mode
    try {
      if (value) {
        // Turn ON: Set to previous mode or default to 'public'
        final mode = _sharingMode == 'off' ? 'public' : _sharingMode;
        await SupabaseService.updateLocationSharingMode(mode);
        setState(() => _sharingMode = mode);
        
        // Update location in database
        if (_hasLocationPermission) {
          await SupabaseService.updateUserLocation(
            currentLocation.latitude,
            currentLocation.longitude,
          );
        }
      } else {
        // Turn OFF
        await SupabaseService.updateLocationSharingMode('off');
        setState(() => _sharingMode = 'off');
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating sharing: $e');
        // Revert slider on error
        setState(() => _isSharingLocation = !value);
      }
    }
  }

  Future<void> _openPrivacySettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const LocationPrivacyDialog(),
    );

    if (result == true) {
      // Reload settings after save
      await _loadPrivacySettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings updated'),
            backgroundColor: Color(0xFF00FF41),
          ),
        );
      }
    }
  }

  void _addSampleMarkers() {
    // Add sample markers around San Francisco
    _addMarkerToList(
      const LatLng(37.7749, -122.4194),
      'Downtown SF',
      'City Center',
      Colors.red,
    );
    _addMarkerToList(
      const LatLng(37.8044, -122.2712),
      'Golden Gate Bridge',
      'Famous landmark',
      Colors.orange,
    );
    _addMarkerToList(
      const LatLng(37.7694, -122.4862),
      'Ocean Beach',
      'Beautiful beach',
      Colors.green,
    );
  }

  void _addMarkerToList(
    LatLng location,
    String title,
    String subtitle,
    Color color, {
    String? postId,
    MapPost? post,
    bool isUserLocation = false,
    bool addToNonCluster = false,
    bool isFriend = false,
    int activePushers = 0,
  }) {
    final key = '${location.latitude},${location.longitude}';
    if (post != null) {
      markerPostMap[key] = post;
    }

    final marker = Marker(
      point: location,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          if (post != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpotDetailsScreen(post: post),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  activePushers > 0 
                      ? '$title - Active Pushers = $activePushers' 
                      : '$title - $subtitle'
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: isFriend ? Colors.red : null,
              ),
            );
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isFriend)
              // Friend Icon: Precise Pin
              Icon(
                Icons.person_pin_circle,
                color: color,
                size: 36,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            else if (!isUserLocation) ...[
              // Outer glow effect (only for pins, not user location)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Pin background
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: post != null ? const Color(0xFF00FF41) : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activePushers > 0 ? Colors.red : Colors.black, // Red highlight for active spots
                    width: activePushers > 0 ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: post != null
                          ? const Color(0xFF00FF41).withValues(alpha: 0.5)
                          : color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      post != null ? Icons.location_on_rounded : Icons.location_on,
                      color: Colors.black,
                      size: 20,
                    ),
                    if (activePushers > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '$activePushers',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              // User location: GPS crosshair icon
              Icon(
                Icons.my_location,
                color: const Color(0xFF00FF41),
                size: 32,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    setState(() {
      if (addToNonCluster) {
        nonClusterMarkers.add(marker);
      } else {
        markers.add(marker);
      }
    });
  }

  void _togglePinMode() {
    setState(() {
      _isPinMode = !_isPinMode;
    });
    if (_isPinMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap on the map to place a pin'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMapTap(LatLng location) {
    if (_isPinMode) {
      _showAddPostDialog(location);
    }
  }

  void _showAddPostDialog(LatLng location) {
    showDialog(
      context: context,
      builder: (context) => AddPostDialog(
        location: location,
        onPostAdded: () {
          _loadUserPosts();
          setState(() {
            _isPinMode = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    debugPrint('MapTab: Building with ${markers.length} markers');
    return Stack(
      children: [
        Column(
          children: [
            // App Name Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '> PUSHINN_',
                      style: TextStyle(
                        color: Color(0xFF00FF41),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const AdBanner(),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation,
                      initialZoom: 13.0,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                      onTap: (tapPosition, point) => _handleMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.prototype_0_0_1',
                        maxZoom: 19,
                      ),
                      MarkerLayer(markers: nonClusterMarkers), // Add non-clustered markers (user location)
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 120,
                          size: const Size(40, 40),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(50),
                          maxZoom: 15,
                          markers: markers,
                          builder: (context, markers) {
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF41),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  markers.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isLoadingLocation)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  
                  // Location Share Slider (Top Center)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSharingLocation ? Icons.visibility : Icons.visibility_off,
                                  size: 16,
                                  color: _isSharingLocation ? const Color(0xFF00FF41) : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isSharingLocation ? 'Visible to Others' : 'Hidden',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isSharingLocation ? const Color(0xFF00FF41) : Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 16,
                                  width: 28,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Switch(
                                      value: _isSharingLocation,
                                      onChanged: _toggleLocationSharing,
                                      activeThumbColor: const Color(0xFF00FF41),
                                      activeTrackColor: const Color(0xFF00FF41).withValues(alpha: 0.3),
                                      inactiveThumbColor: Colors.grey.shade600,
                                      inactiveTrackColor: Colors.grey.shade800,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.settings, size: 18),
                                  color: const Color(0xFF00FF41),
                                  onPressed: _openPrivacySettings,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Privacy Settings',
                                ),
                              ],
                            ),
                          ),
                      ),
                    ),
                  ),
                  
                  // Action buttons (Zoom & Search)
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMapButton(
                          icon: Icons.search_rounded,
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: PostSearchDelegate(userPosts),
                            );
                          },
                          backgroundColor: Colors.black.withValues(alpha: 0.8),
                          iconColor: const Color(0xFF00FF41),
                        ),
                        const SizedBox(height: 12),
                        _buildMapButton(
                          icon: Icons.add_rounded,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            );
                          },
                          backgroundColor: const Color(0xFF00FF41),
                          iconColor: Colors.black,
                        ),
                        const SizedBox(height: 12),
                        _buildMapButton(
                          icon: Icons.remove_rounded,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom - 1,
                            );
                          },
                          backgroundColor: const Color(0xFF00FF41),
                          iconColor: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  // Pin placement button
                  // Pin placement button - Centered above nav bar
                  Positioned(
                    bottom: 45, // Adjusted for shorter triangle
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // PhysicalShape for shadow and clip
                          PhysicalShape(
                            clipper: TriangleClipper(),
                            color: _isPinMode ? Colors.red.shade600 : const Color(0xFF00FF41),
                            elevation: 8,
                            shadowColor: (_isPinMode ? Colors.red : const Color(0xFF00FF41)).withValues(alpha: 0.4),
                            child: InkWell(
                              onTap: _togglePinMode,
                              child: Container(
                                width: 120, // Fatter (was 100)
                                height: 60, // Shorter (was 70)
                                alignment: Alignment.center,
                                padding: const EdgeInsets.only(top: 5), // Raised icon (was 10)
                                child: Icon(
                                  _isPinMode ? Icons.close_rounded : Icons.add_location_rounded,
                                  color: _isPinMode ? Colors.white : Colors.black,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          // Border
                          IgnorePointer(
                            child: CustomPaint(
                              size: const Size(120, 60), // Fatter and shorter
                              painter: TriangleBorderPainter(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Material(
      elevation: 6,
      shadowColor: backgroundColor == Colors.white 
          ? Colors.black.withValues(alpha: 0.2)
          : backgroundColor.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: backgroundColor == Colors.white
                    ? Colors.black.withValues(alpha: 0.1)
                    : backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
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
            // Navigate to post location
            // This requires a callback or access to map controller, 
            // but for now we just close. 
            // Ideally we'd return the post and handle it in MapTab.
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

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0); // Top center
    path.lineTo(size.width, size.height); // Bottom right
    path.lineTo(0, size.height); // Bottom left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TriangleBorderPainter extends CustomPainter {
  final Color color;
  final double width;

  TriangleBorderPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
