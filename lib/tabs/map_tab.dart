import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../screens/add_post_dialog.dart';
import '../screens/spot_details_bottom_sheet.dart';
import '../widgets/ad_banner.dart';
import '../utils/error_helper.dart';
import 'feed_tab.dart';

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
  bool _isLoading = false;
  bool _isPinMode = false;
  bool _isSharingLocation = false; // Slider state

  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _addSampleMarkers();
    _loadUserPosts();
    // Automatically try to get location on startup
    _getCurrentLocation();
  }

  Future<void> _loadUserPosts() async {
    try {
      // Load posts with filter
      final posts = await SupabaseService.getAllMapPosts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          userPosts = posts;
          // Clear all markers and rebuild from scratch
          markers.clear();
          markerPostMap.clear();
          _addSampleMarkers();
          // Add current location marker if available and sharing is on
          if (!_isLoading && _isSharingLocation) {
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
    } catch (e) {
      debugPrint('Error loading posts: $e');
      // Silently fail
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _loadUserPosts();
                      Navigator.pop(context);
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  void _addUserPostMarkers() {
    for (final post in userPosts) {
      _addMarkerToList(
        LatLng(post.latitude, post.longitude),
        post.title,
        post.description,
        Colors.green,
        postId: post.id,
        post: post,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
           setState(() {
            _isLoading = false;
            _isSharingLocation = false; // Turn off slider if denied
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
         setState(() {
            _isLoading = false;
            _isSharingLocation = false; // Turn off slider if denied
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
          _isLoading = false;
          _isSharingLocation = true; // Enable slider on success
        });

        // Animate to current location
        mapController.move(newLocation, 14.0);

        // Rebuild markers to include location
        _loadUserPosts();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSharingLocation = false;
      });
      if (mounted) {
        ErrorHelper.showError(context, 'Error getting location: $e');
      }
    }
  }

  void _toggleLocationSharing(bool value) {
    setState(() {
      _isSharingLocation = value;
    });

    if (value) {
      _getCurrentLocation();
    } else {
      // Remove location marker by reloading posts (which checks _isSharingLocation)
      _loadUserPosts();
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
                      MarkerLayer(markers: markers),
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
                  
                  // Location Share Slider (Top Center)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Center(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => _toggleLocationSharing(!_isSharingLocation),
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6, // Slimmer vertical padding
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _isSharingLocation
                                    ? Colors.green
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSharingLocation
                                      ? Icons.my_location
                                      : Icons.location_disabled,
                                  size: 18,
                                  color: _isSharingLocation
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSharingLocation
                                      ? 'Sharing Location'
                                      : 'Location Hidden',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _isSharingLocation
                                        ? Colors.green
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 20,
                                  width: 30,
                                  child: Switch(
                                    value: _isSharingLocation,
                                    onChanged: _toggleLocationSharing,
                                    activeThumbColor: Colors.green,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                  ),

                  // Action buttons (Zoom) - Removed Location FAB
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          mini: true,
                          heroTag: 'search',
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: PostSearchDelegate(userPosts),
                            );
                          },
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.search),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          mini: true,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            );
                          },
                          backgroundColor: Colors.green,
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
                          backgroundColor: Colors.green,
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
                          : Colors.green,
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
