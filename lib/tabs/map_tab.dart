import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';
import '../screens/spot_details_bottom_sheet.dart';
import '../widgets/ad_banner.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => SpotDetailsBottomSheet(
                    post: post,
                    onClose: () => Navigator.pop(context),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title - $subtitle'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 20),
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
    return Stack(
      children: [
        Column(
          children: [
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.prototype_0_0_1',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: markers,
            ),
          ],
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
            backgroundColor: _isPinMode ? Colors.red : Colors.deepPurple,
            child: Icon(_isPinMode ? Icons.close : Icons.location_on),
          ),
        ),
                ],
              ),
            ),
          ],
        ),
        // Ad banner overlay at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 20,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
              ),
              const AdBanner(),
            ],
          ),
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

