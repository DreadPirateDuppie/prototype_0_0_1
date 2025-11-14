import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late MapController mapController;
  List<Marker> markers = [];
  List<MapPost> userPosts = [];
  LatLng currentLocation = const LatLng(37.7749, -122.4194); // Default: SF
  bool _isLoading = true;

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
  }) {
    setState(() {
      markers.add(
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(subtitle),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
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

  void _showAddPostDialog(LatLng location) {
    showDialog(
      context: context,
      builder: (context) => AddPostDialog(
        location: location,
        onPostAdded: _loadUserPosts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onLongPressStart: (details) {
            // Get the map controller to convert screen coordinates to lat/lng
            final mapBox = context.findRenderObject() as RenderBox?;
            if (mapBox != null) {
              final tapPosition = details.localPosition;
              final mapSize = mapBox.size;
              
              // Get the visible bounds from the map
              final bounds = mapController.camera.visibleBounds;
              
              // Simple conversion - calculate lat/lng from tap position
              final mapCenter = mapController.camera.center;
              final latPerPixel = (bounds.north - bounds.south) / mapSize.height;
              final lngPerPixel = (bounds.east - bounds.west) / mapSize.width;
              
              final centerPixel = Offset(mapSize.width / 2, mapSize.height / 2);
              final deltaPixels = tapPosition - centerPixel;
              
              final newLat = mapCenter.latitude - (deltaPixels.dy * latPerPixel);
              final newLng = mapCenter.longitude + (deltaPixels.dx * lngPerPixel);
              
              _showAddPostDialog(LatLng(newLat, newLng));
            }
          },
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation,
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
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
      ],
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

