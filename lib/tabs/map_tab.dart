import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';
import '../screens/spot_details_screen.dart';
import '../screens/location_privacy_dialog.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';
import '../providers/navigation_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => MapTabState();
}

class MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true; // Keep this tab alive in the background

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _autoDisableTimer?.cancel();
    super.dispose();
  }
  
  late MapController mapController;
  List<Marker> markers = [];
  List<Marker> nonClusterMarkers = [];
  List<MapPost> userPosts = [];
  Map<String, MapPost> markerPostMap = {}; // Map marker location to post
  LatLng currentLocation = const LatLng(37.7749, -122.4194); // Default: SF
  bool _isLoadingLocation = false;
  bool _isMapReady = false; // Flag to track if map is rendered
  bool _isPinMode = false;
  bool _isSharingLocation = false; // Slider: Others can see you
  bool _hasLocationPermission = false; // User's location is visible to self
  String _sharingMode = 'off';
  DateTime? _lastLocationUpdate;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _autoDisableTimer;

  List<Map<String, dynamic>> _onlineFriendsFeed = []; // All online friends for feed


  final String _selectedCategory = 'All';
  bool _hasExplicitlyNavigated = false; // Track if user has manually navigated

  void moveToLocation(LatLng location) {
    _hasExplicitlyNavigated = true; // Mark that we've manually navigated
    if (_isMapReady) {
      mapController.move(location, 17.0); // Increased zoom for better detail
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to app: Reset the auto-disable timer if sharing is active
      if (_isSharingLocation) {
        _resetAutoDisableTimer();
      }
      // Check if we need to auto-disable (in case it expired while backgrounded)
      _checkAutoDisable();
    }
  }

  void _resetAutoDisableTimer() {
    _autoDisableTimer?.cancel();
    // Restart the 1-hour timer
    _autoDisableTimer = Timer(const Duration(minutes: 60), _autoDisableLocationSharing);
    
    // Reschedule notification (cancel old one first)
    NotificationService.cancelLocationSharingReminder(); 
    NotificationService.scheduleLocationSharingReminder();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mapController = MapController();
    _addSampleMarkers();
    _loadUserPosts();
    // Automatically get location and privacy settings
    _getCurrentLocation();
    _loadPrivacySettings();
    
    // Initialize notifications
    NotificationService.initialize();
    
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
      
      // Filter by mutual friends AND distance (10 miles)
      // Filter by mutual friends AND distance (10 miles)
      final onlineFriends = visibleLocations.where((user) {
        final isFriend = friends.any((friend) => friend['id'] == user['id']);
        // debugPrint('DEBUG: User ${user['username']} is visible but not a mutual friend');
        return isFriend;
      }).toList();


      
      debugPrint('DEBUG: Final online friends count: ${onlineFriends.length}');

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
          const distanceThreshold = 100.0; // meters

          // Prepare feed data
          final List<Map<String, dynamic>> feedItems = [];

          for (final friend in onlineFriends) {
            if (friend['current_latitude'] != null && friend['current_longitude'] != null) {
              final friendLoc = LatLng(friend['current_latitude'], friend['current_longitude']);
              bool isAtSpot = false;
              String statusText = 'Online';
              String? spotName;

              for (final post in posts) {
                if (post.latitude == null || post.longitude == null) continue;
                
                final postLoc = LatLng(post.latitude!, post.longitude!);
                final distance = const Distance().as(LengthUnit.Meter, friendLoc, postLoc);
                
                if (distance <= distanceThreshold && post.id != null) {
                  spotSessionCounts[post.id!] = (spotSessionCounts[post.id!] ?? 0) + 1;
                  isAtSpot = true;
                  statusText = 'At ${post.title}';
                  spotName = post.title;
                  break; // Only count for the first matching spot
                }
              }

              // Add to feed regardless of spot status
              final feedItem = Map<String, dynamic>.from(friend);
              feedItem['status_text'] = statusText;
              feedItem['spot_name'] = spotName;
              feedItem['location'] = friendLoc;
              feedItems.add(feedItem);

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
          _onlineFriendsFeed = feedItems; // Update state
          debugPrint('MapTab: Updated markers. Friends in feed: ${_onlineFriendsFeed.length}');
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
        if (!_hasExplicitlyNavigated && _isMapReady) {
          mapController.move(newLocation, 14.0);
        }

        // If sharing is enabled, force update now that we have permission
        if (_isSharingLocation) {
          _forceLocationUpdate();
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
        
        // Check if sharing was enabled and check elapsed time
        if (_isSharingLocation) {
          _checkSharingElapsedTime();
          _startLocationTracking(); // Resume tracking if sharing is on
          _forceLocationUpdate(); // Force immediate update on app start
        }
        _loadUserPosts(); // Refresh feed based on new settings
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    }
  }

  /// Check if location sharing has been on for more than 1 hour
  Future<void> _checkSharingElapsedTime() async {
    // Get last location update time from database
    try {
      final profile = await SupabaseService.getCurrentUserProfile();
      final lastUpdate = profile?['location_updated_at'] as String?;
      
      if (lastUpdate != null) {
        final lastUpdateTime = DateTime.parse(lastUpdate);
        final elapsed = DateTime.now().difference(lastUpdateTime);
        
        // If more than 1 hour, auto-disable
        if (elapsed.inHours >= 1) {
          await _autoDisableLocationSharing();
        } else {
          // Re-start timer for remaining time
          final remaining = const Duration(hours: 1) - elapsed;
          _startAutoDisableTimer(remaining);
        }
      }
    } catch (e) {
      debugPrint('Error checking sharing elapsed time: $e');
    }
  }

  // Alias for _checkSharingElapsedTime to match the call in didChangeAppLifecycleState
  Future<void> _checkAutoDisable() => _checkSharingElapsedTime();

  void _startAutoDisableTimer([Duration? customDuration]) {
    _autoDisableTimer?.cancel();
    
    final duration = customDuration ?? const Duration(hours: 1);
    
    // Schedule reminder notification (5 min before disable) 
    if (duration.inMinutes >= 5) {
      NotificationService.scheduleLocationSharingReminder();
    }
    
    // Start auto-disable timer
    _autoDisableTimer = Timer(duration, () async {
      await _autoDisableLocationSharing();
    });
    
    debugPrint('Auto-disable timer started for ${duration.inMinutes} minutes');
  }

  Future<void> _autoDisableLocationSharing() async {
    if (!_isSharingLocation) return; // Already disabled
    
    try {
      // Turn OFF sharing
      await SupabaseService.updateLocationSharingMode('off');
      
      // Stop tracking
      _stopLocationTracking();
      _autoDisableTimer?.cancel();
      
      // Show notification
      await NotificationService.showLocationSharingDisabled();
      
      if (mounted) {
        setState(() {
          _isSharingLocation = false;
          _sharingMode = 'off';
        });
      }
      
      debugPrint('Location sharing auto-disabled after 1 hour');
    } catch (e) {
      debugPrint('Error auto-disabling location sharing: $e');
    }
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      final newLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        currentLocation = newLocation;
      });

      // Update database if sharing is enabled (Throttled to every 5 minutes)
      if (_isSharingLocation) {
        final now = DateTime.now();
        if (_lastLocationUpdate == null || 
            now.difference(_lastLocationUpdate!) >= const Duration(minutes: 5)) {
          try {
            await SupabaseService.updateUserLocation(
              position.latitude,
              position.longitude,
            );
            _lastLocationUpdate = now;
          } catch (e) {
            debugPrint('Error updating location: $e');
          }
        }
      }

      // Refresh markers to show updated position
      _loadUserPosts();
    });

  }

  Future<void> _forceLocationUpdate() async {
    try {
      // Ensure we have permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('Cannot force location update: Permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      await SupabaseService.updateUserLocation(
        position.latitude,
        position.longitude,
      );
      
      _lastLocationUpdate = DateTime.now();
      debugPrint('Forced location update successful: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error forcing location update: $e');
    }
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
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
        
        // Update initial location in database
        if (_hasLocationPermission) {
          await _forceLocationUpdate();
          // Start continuous tracking
          _startLocationTracking();
          // Start auto-disable timer (1 hour)
          _startAutoDisableTimer();
        }
        _loadUserPosts(); // Refresh feed to show self card
      } else {
        // Turn OFF
        await SupabaseService.updateLocationSharingMode('off');
        setState(() => _sharingMode = 'off');
        // Stop continuous tracking
        _stopLocationTracking();
        // Cancel auto-disable timer and notifications
        _autoDisableTimer?.cancel();
        await NotificationService.cancelAllLocationNotifications();
        _loadUserPosts(); // Refresh feed to remove self card
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating sharing: $e', screenName: 'MapTab');
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
        child: Builder(
          builder: (context) {
            final isMvp = post != null && post.mvpUserId != null && post.mvpUserId == SupabaseService.getCurrentUser()?.id;
            final borderColor = isMvp ? Colors.amber : (activePushers > 0 ? Colors.red : Colors.black);
            final borderWidth = isMvp ? 3.0 : (activePushers > 0 ? 2.5 : 1.5);

            return Stack(
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
                    width: isMvp ? 48 : 40,
                    height: isMvp ? 48 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isMvp ? Colors.amber.withValues(alpha: 0.6) : color.withValues(alpha: 0.4),
                          blurRadius: isMvp ? 16 : 12,
                          spreadRadius: isMvp ? 4 : 2,
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
                        color: borderColor,
                        width: borderWidth,
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
                        if (isMvp)
                          const Positioned(
                            top: -4,
                            right: -4,
                            child: Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        if (activePushers > 0 && !isMvp)
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
            );
          }
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
                color: Colors.transparent, // Show global Matrix
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
                      onMapReady: () {
                        if (mounted) {
                          setState(() {
                            _isMapReady = true;
                          });
                        }
                      },
                    ),
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.1, 0, 0, 0, 0,
                          0, 2.2, 0, 0, 10,
                          0, 0, 0.1, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.pushinn.app',
                          maxZoom: 19,
                        ),
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
                          color: Colors.black.withValues(alpha: 0.8), // Darkened for readability
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  
                  // Search Bar & Notch Layout (Custom Painted)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: CustomPaint(
                      painter: SearchNotchPainter(),
                      child: SizedBox(
                        height: 86, // 50 (bar) + 36 (notch)
                        child: Stack(
                          children: [
                            // 1. Search Bar Content (Top)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 50,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    showSearch(
                                      context: context,
                                      delegate: PostSearchDelegate(userPosts),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(25),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          color: const Color(0xFF00FF41).withValues(alpha: 0.8),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Search spots...',
                                          style: TextStyle(
                                            color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                                            fontSize: 16,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // 2. Notch Content (Location Slider)
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 200, // Matches painter notch width
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isSharingLocation ? Icons.visibility : Icons.visibility_off,
                                        size: 16,
                                        color: _isSharingLocation ? const Color(0xFF00FF41) : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isSharingLocation ? 'Visible' : 'Hidden',
                                        style: TextStyle(
                                          color: _isSharingLocation ? const Color(0xFF00FF41) : Colors.grey.shade500,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 20,
                                        width: 36,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: Switch(
                                            value: _isSharingLocation,
                                            onChanged: _toggleLocationSharing,
                                            activeThumbColor: const Color(0xFF00FF41),
                                            activeTrackColor: const Color(0xFF00FF41).withValues(alpha: 0.3),
                                            inactiveThumbColor: Colors.grey.shade600,
                                            inactiveTrackColor: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _openPrivacySettings,
                                        child: Icon(
                                          Icons.settings_outlined,
                                          size: 16,
                                          color: const Color(0xFF00FF41).withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // My Location Button (Bottom Left)
                  Positioned(
                    bottom: 80, // Lowered from 100
                    left: 16,
                    child: _buildVerticalMapButton(
                      icon: Icons.my_location,
                      onPressed: () {
                        mapController.move(currentLocation, 15.0);
                      },
                    ),
                  ),

                  // Zoom Controls (Bottom Right)
                  Positioned(
                    bottom: 80, // Lowered from 100
                    right: 16,
                    child: Column(
                      children: [
                        _buildVerticalMapButton(
                          icon: Icons.add,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildVerticalMapButton(
                          icon: Icons.remove,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom - 1,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // OpenStreetMap Attribution (Required by ODbL License)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          // Open OSM copyright page
                          final uri = Uri.parse('https://www.openstreetmap.org/copyright');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Online Friends Cards (Bottom)


                  // Pin placement button
                  // Pin placement button - Centered above nav bar
                  Positioned(
                    bottom: 40, // Raised from 30
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // PhysicalShape for shadow and clip
                          PhysicalShape(
                            clipper: PinClipper(),
                            color: _isPinMode ? Colors.red.shade600 : const Color(0xFF00FF41),
                            elevation: 8,
                            shadowColor: (_isPinMode ? Colors.red : const Color(0xFF00FF41)).withValues(alpha: 0.4),
                            child: InkWell(
                              onTap: _togglePinMode,
                              child: Container(
                                width: 90, // Wider (was 70)
                                height: 90, // Taller for pin
                                alignment: Alignment.center,
                                padding: const EdgeInsets.only(bottom: 25), // Center icon in the round part
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
                              size: const Size(90, 90), // Wider (was 70)
                              painter: PinBorderPainter(
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


  Widget _buildVerticalMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    const matrixGreen = Color(0xFF00FF41);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: matrixGreen.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: matrixGreen,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class SearchNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00FF41).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Dimensions
    final searchBarHeight = 50.0;
    final notchWidth = 180.0; // Width of the notch area
    final notchHeight = 36.0; // Height of the notch hanging down
    final cornerRadius = 25.0; // Radius for search bar ends
    final smoothRadius = 12.0; // Radius for the smooth transition
    
    // Start top-left of search bar
    path.moveTo(cornerRadius, 0);
    
    // Top line
    path.lineTo(size.width - cornerRadius, 0);
    
    // Top-right corner
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    
    // Right side of search bar
    path.lineTo(size.width, searchBarHeight - cornerRadius);
    
    // Bottom-right corner of search bar
    path.arcToPoint(
      Offset(size.width - cornerRadius, searchBarHeight),
      radius: Radius.circular(cornerRadius),
    );
    
    // Bottom line to notch start (Right side)
    final notchRightStart = (size.width + notchWidth) / 2;
    path.lineTo(notchRightStart + smoothRadius, searchBarHeight);
    
    // Smooth transition to notch (Right)
    path.cubicTo(
      notchRightStart, searchBarHeight, // Control point 1
      notchRightStart, searchBarHeight, // Control point 2
      notchRightStart, searchBarHeight + smoothRadius, // End point
    );
    
    // Right side of notch
    path.lineTo(notchRightStart, searchBarHeight + notchHeight - smoothRadius);
    
    // Bottom-right corner of notch
    path.arcToPoint(
      Offset(notchRightStart - smoothRadius, searchBarHeight + notchHeight),
      radius: Radius.circular(smoothRadius),
    );
    
    // Bottom of notch
    final notchLeftStart = (size.width - notchWidth) / 2;
    path.lineTo(notchLeftStart + smoothRadius, searchBarHeight + notchHeight);
    
    // Bottom-left corner of notch
    path.arcToPoint(
      Offset(notchLeftStart, searchBarHeight + notchHeight - smoothRadius),
      radius: Radius.circular(smoothRadius),
    );
    
    // Left side of notch
    path.lineTo(notchLeftStart, searchBarHeight + smoothRadius);
    
    // Smooth transition from notch (Left)
    path.cubicTo(
      notchLeftStart, searchBarHeight, // Control point 1
      notchLeftStart, searchBarHeight, // Control point 2
      notchLeftStart - smoothRadius, searchBarHeight, // End point
    );
    
    // Bottom line to start (Left side)
    path.lineTo(cornerRadius, searchBarHeight);
    
    // Bottom-left corner of search bar
    path.arcToPoint(
      Offset(0, searchBarHeight - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    
    // Left side of search bar
    path.lineTo(0, cornerRadius);
    
    // Top-left corner
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );
    
    path.close();
    
    // Draw shadow
    canvas.drawShadow(path, Colors.black, 8.0, true);
    
    // Draw fill
    canvas.drawPath(path, paint);
    
    // Draw border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class PinClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.cubicTo(
      size.width, size.height * 0.6,
      size.width, 0,
      size.width / 2, 0,
    );
    path.cubicTo(
      0, 0,
      0, size.height * 0.6,
      size.width / 2, size.height,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class PinBorderPainter extends CustomPainter {
  final Color color;
  final double width;

  PinBorderPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.cubicTo(
      size.width, size.height * 0.6,
      size.width, 0,
      size.width / 2, 0,
    );
    path.cubicTo(
      0, 0,
      0, size.height * 0.6,
      size.width / 2, size.height,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
