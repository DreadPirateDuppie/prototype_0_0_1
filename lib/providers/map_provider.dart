import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../models/post.dart';

class MapProvider extends ChangeNotifier {
  List<Marker> _markers = [];
  List<Marker> _nonClusterMarkers = [];
  List<MapPost> _userPosts = [];
  final Map<String, MapPost> _markerPostMap = {};
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  bool _isLoadingLocation = false;
  bool _isSharingLocation = false;
  bool _hasLocationPermission = false;
  String _sharingMode = 'off';
  DateTime? _lastLocationUpdate;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _autoDisableTimer;
  List<Map<String, dynamic>> _onlineFriendsFeed = [];
  String _selectedCategory = 'All';
  String? _error;

  // Getters
  List<Marker> get markers => _markers;
  List<Marker> get nonClusterMarkers => _nonClusterMarkers;
  List<MapPost> get userPosts => _userPosts;
  Map<String, MapPost> get markerPostMap => _markerPostMap;
  LatLng get currentLocation => _currentLocation;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isSharingLocation => _isSharingLocation;
  bool get hasLocationPermission => _hasLocationPermission;
  String get sharingMode => _sharingMode;
  List<Map<String, dynamic>> get onlineFriendsFeed => _onlineFriendsFeed;
  String get selectedCategory => _selectedCategory;
  String? get error => _error;

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    loadUserPosts();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _loadPrivacySettings();
    await getCurrentLocation();
    await loadUserPosts();
  }

  Future<void> loadUserPosts({String? category}) async {
    try {
      final targetCategory = category ?? _selectedCategory;
      final posts = await SupabaseService.getAllMapPosts(
        category: targetCategory == 'All' ? null : targetCategory,
      );
      
      final friends = await SupabaseService.getMutualFollowers();
      final visibleLocations = await SupabaseService.getVisibleUserLocations();
      
      final onlineFriends = visibleLocations.where((user) {
        return friends.any((friend) => friend['id'] == user['id']);
      }).toList();

      _userPosts = posts;
      _markers = [];
      _nonClusterMarkers = [];
      _markerPostMap.clear();
      
      // Add user location if permission granted
      if (_hasLocationPermission) {
        _addMarkerToList(
          _currentLocation,
          'Your Location',
          'You are here',
          Colors.blue,
          isUserLocation: true,
          addToNonCluster: true,
        );
      }
      
      final Map<String, int> spotSessionCounts = {};
      const distanceThreshold = 100.0;
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
              break;
            }
          }

          final feedItem = Map<String, dynamic>.from(friend);
          feedItem['status_text'] = statusText;
          feedItem['spot_name'] = spotName;
          feedItem['location'] = friendLoc;
          feedItems.add(feedItem);

          if (!isAtSpot) {
            _addMarkerToList(
              friendLoc,
              friend['display_name'] ?? friend['username'] ?? 'Friend',
              'Online now',
              Colors.red,
              addToNonCluster: true,
              isUserLocation: false,
              isFriend: true,
            );
          }
        }
      }

      for (final post in _userPosts) {
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
      
      _onlineFriendsFeed = feedItems;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading posts: $e';
      notifyListeners();
    }
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
      _markerPostMap[key] = post;
    }

    // Note: Marker UI logic should ideally stay in the widget or a UI helper,
    // but for now we'll keep it consistent with the existing implementation.
    // We'll pass a builder or use a custom marker widget later.
    // For now, we just store the data needed to build markers.
  }

  // This is a placeholder for the actual marker building logic which will be in the Tab
  void updateMarkers(List<Marker> markers, List<Marker> nonClusterMarkers) {
    _markers = markers;
    _nonClusterMarkers = nonClusterMarkers;
    notifyListeners();
  }

  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    notifyListeners();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          _isLoadingLocation = false;
          _hasLocationPermission = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLoadingLocation = false;
        _hasLocationPermission = false;
        _error = 'Location permission permanently denied.';
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
      _hasLocationPermission = true;

      if (_isSharingLocation) {
        await forceLocationUpdate();
      }

      await loadUserPosts();
    } catch (e) {
      _isLoadingLocation = false;
      _hasLocationPermission = false;
      _error = 'Error getting location: $e';
      notifyListeners();
    }
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final settings = await SupabaseService.getLocationPrivacySettings();
      _sharingMode = settings['sharing_mode'] as String;
      _isSharingLocation = _sharingMode != 'off';
      
      if (_isSharingLocation) {
        await _checkSharingElapsedTime();
        startLocationTracking();
        await forceLocationUpdate();
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error loading privacy settings: $e';
      notifyListeners();
    }
  }

  Future<void> _checkSharingElapsedTime() async {
    try {
      final profile = await SupabaseService.getCurrentUserProfile();
      final lastUpdate = profile?['location_updated_at'] as String?;
      
      if (lastUpdate != null) {
        final lastUpdateTime = DateTime.parse(lastUpdate);
        final elapsed = DateTime.now().difference(lastUpdateTime);
        
        if (elapsed.inHours >= 1) {
          await autoDisableLocationSharing();
        } else {
          final remaining = const Duration(hours: 1) - elapsed;
          _startAutoDisableTimer(remaining);
        }
      }
    } catch (e) {
      _error = 'Error checking sharing elapsed time: $e';
      notifyListeners();
    }
  }

  void _startAutoDisableTimer([Duration? customDuration]) {
    _autoDisableTimer?.cancel();
    final duration = customDuration ?? const Duration(hours: 1);
    
    if (duration.inMinutes >= 5) {
      NotificationService.scheduleLocationSharingReminder();
    }
    
    _autoDisableTimer = Timer(duration, () async {
      await autoDisableLocationSharing();
    });
  }

  Future<void> autoDisableLocationSharing() async {
    if (!_isSharingLocation) return;
    
    try {
      await SupabaseService.updateLocationSharingMode('off');
      stopLocationTracking();
      _autoDisableTimer?.cancel();
      await NotificationService.showLocationSharingDisabled();
      
      _isSharingLocation = false;
      _sharingMode = 'off';
      notifyListeners();
    } catch (e) {
      _error = 'Error auto-disabling location sharing: $e';
      notifyListeners();
    }
  }

  void startLocationTracking() {
    _locationSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      _currentLocation = LatLng(position.latitude, position.longitude);
      
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
            _error = 'Error updating location: $e';
          }
        }
      }
      await loadUserPosts();
    });
  }

  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<void> forceLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      await SupabaseService.updateUserLocation(
        position.latitude,
        position.longitude,
      );
      
      _lastLocationUpdate = DateTime.now();
      notifyListeners();
    } catch (e) {
      _error = 'Error forcing location update: $e';
      notifyListeners();
    }
  }

  Future<void> toggleLocationSharing(bool value) async {
    _isSharingLocation = value;
    notifyListeners();

    try {
      if (value) {
        final mode = _sharingMode == 'off' ? 'public' : _sharingMode;
        await SupabaseService.updateLocationSharingMode(mode);
        _sharingMode = mode;
        
        if (_hasLocationPermission) {
          await forceLocationUpdate();
          startLocationTracking();
          _startAutoDisableTimer();
        }
      } else {
        await SupabaseService.updateLocationSharingMode('off');
        _sharingMode = 'off';
        stopLocationTracking();
        _autoDisableTimer?.cancel();
        await NotificationService.cancelAllLocationNotifications();
      }
      await loadUserPosts();
    } catch (e) {
      _isSharingLocation = !value;
      _error = 'Error updating sharing: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _autoDisableTimer?.cancel();
    super.dispose();
  }
}
