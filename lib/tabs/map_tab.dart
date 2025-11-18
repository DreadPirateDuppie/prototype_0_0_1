import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';
import '../screens/spot_details_bottom_sheet.dart';
import '../widgets/ad_banner.dart';
import '../providers/error_provider.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late MapController mapController;
  List<Marker> markers = [];
  List<MapPost> userPosts = [];
  Map<String, MapPost> markerPostMap = {}; // Map marker location to post
  LatLng currentLocation = const LatLng(37.7749, -122.4194); // Default: SF
  bool _isLoading = true;
  bool _isPinMode = false;
  bool _isSharingLocation = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _getCurrentLocation();
    _addSampleMarkers();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        final posts = await SupabaseService.getUserMapPosts(user.id);
        if (mounted) {
          setState(() {
            userPosts = posts;
            // Clear all markers and rebuild from scratch
            markers.clear();
            markerPostMap.clear();
            _addSampleMarkers();
            // Add current location marker if available
            if (!_isLoading) {
              _addMarkerToList(
                currentLocation,
                'Your Location',
                'You are here',
                Colors.blue,
              );
            }
            _addUserPostMarkers();
          });
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _addUserPostMarkers() {
    for (final post in userPosts) {
      _addMarkerToList(
        LatLng(post.latitude, post.longitude),
        post.title,
        post.description,
        Colors.purple,
        postId: post.id,
        post: post,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
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
          _isLoading = false;
        });

        // Animate to current location
        mapController.move(newLocation, 14.0);

        // Add marker at current location
        _addMarkerToList(
          newLocation,
          'Your Location',
          'You are here',
          Colors.blue,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Provider.of<ErrorProvider>(
          context,
          listen: false,
        ).showError('Error getting location: $e');
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
  }) {
    final key = '${location.latitude},${location.longitude}';
    if (post != null) {
      markerPostMap[key] = post;
    }

    setState(() {
      markers.add(
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              if (post != null) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) => SpotDetailsBottomSheet(
                    post: post,
                    onClose: () => Navigator.pop(context),
                  ),
                );
              } else {
                Provider.of<ErrorProvider>(
                  context,
                  listen: false,
                ).showError('$title - $subtitle');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    });
  }

  void _togglePinMode() {
    setState(() {
      _isPinMode = !_isPinMode;
    });
    if (_isPinMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap on the map to place a pin'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _nearestSpotId(LatLng location, {double radiusMeters = 250}) {
    try {
      final d = Distance();
      String? nearestId;
      double nearest = double.infinity;
      for (final entry in markerPostMap.entries) {
        final parts = entry.key.split(',');
        if (parts.length != 2) continue;
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat == null || lng == null) continue;
        final dist = d(location, LatLng(lat, lng));
        if (dist < nearest) {
          nearest = dist;
          nearestId = entry.value.id;
        }
      }
      if (nearest <= radiusMeters) {
        return nearestId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _toggleShareLocation() async {
    final user = SupabaseService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to share your location')),
      );
      return;
    }

    setState(() {
      _isSharingLocation = !_isSharingLocation;
    });

    if (_isSharingLocation) {
      final spotId = _nearestSpotId(currentLocation);
      await SupabaseService.startLocationSharing(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        spotId: spotId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            spotId != null
                ? 'Sharing location at spot'
                : 'Sharing your current location',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      await SupabaseService.stopLocationSharing();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stopped sharing location'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMapTap(LatLng location) {
    if (_isPinMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pin location selected! Opening post dialog...'),
          duration: Duration(seconds: 2),
        ),
      );
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
    return Stack(
      children: [
        Column(
          children: [
            const AdBanner(),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation,
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) => _handleMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.prototype_0_0_1',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  // Location sharing slider at the top
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 3,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(
                            color: _isSharingLocation
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(100)
                                : Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _isSharingLocation
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_rounded,
                              color: _isSharingLocation
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).hintColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Share Location',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch.adaptive(
                                value: _isSharingLocation,
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                activeTrackColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (value) => _toggleShareLocation(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isLoading)
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
                  // Zoom buttons
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          mini: true,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            );
                          },
                          backgroundColor: Colors.deepPurple,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          mini: true,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom - 1,
                            );
                          },
                          backgroundColor: Colors.deepPurple,
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                  // Pin placement button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _togglePinMode,
                      backgroundColor: _isPinMode
                          ? Colors.red
                          : Colors.deepPurple,
                      child: Icon(_isPinMode ? Icons.close : Icons.location_on),
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

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
