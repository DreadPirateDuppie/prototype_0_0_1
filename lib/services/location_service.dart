import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'dart:math' as math;
import '../config/service_locator.dart';
import 'auth_service.dart';
import 'social_service.dart';

/// Service responsible for location operations and privacy
class LocationService {
  final SupabaseClient? _injectedClient;
  final AuthService _authService = getIt<AuthService>();
  final SocialService _socialService = getIt<SocialService>();

  LocationService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) {
      return injected;
    }
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Update user's current location
  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return;

      await _client.from('user_profiles').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentUser.id);
      
    } catch (e) {
      AppLogger.log('Error updating user location: $e', name: 'LocationService');
    }
  }

  /// Update location sharing mode (off, public, friends)
  Future<void> updateLocationSharingMode(String mode) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');

      if (!['off', 'public', 'friends'].contains(mode)) {
        throw Exception('Invalid sharing mode: $mode');
      }

      await _client.from('user_profiles').update({
        'location_sharing_mode': mode,
      }).eq('id', currentUser.id);

      AppLogger.log('Updated location sharing mode to $mode for user ${currentUser.id}', name: 'LocationService');
    } catch (e) {
      throw Exception('Failed to update sharing mode: $e');
    }
  }

  /// Update location blacklist
  Future<void> updateLocationBlacklist(List<String> blacklist) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) throw Exception('User not logged in');

      await _client.from('user_profiles').update({
        'location_blacklist': blacklist,
      }).eq('id', currentUser.id);

      AppLogger.log('Updated location blacklist for user ${currentUser.id}', name: 'LocationService');
    } catch (e) {
      throw Exception('Failed to update blacklist: $e');
    }
  }

  /// Get user's current location privacy settings
  Future<Map<String, dynamic>> getLocationPrivacySettings() async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        return {
          'sharing_mode': 'off',
          'blacklist': <String>[],
        };
      }

      final response = await _client
          .from('user_profiles')
          .select('location_sharing_mode, location_blacklist')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (response == null) {
        return {
          'sharing_mode': 'off',
          'blacklist': <String>[],
        };
      }

      return {
        'sharing_mode': response['location_sharing_mode'] ?? 'off',
        'blacklist': (response['location_blacklist'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      };
    } catch (e) {
      AppLogger.log('Error getting privacy settings: $e', name: 'LocationService');
      return {
        'sharing_mode': 'off',
        'blacklist': <String>[],
      };
    }
  }

  /// Get visible user locations near a specific coordinate based on privacy settings
  /// Now uses server-side spatial filtering for massive scalability.
  Future<List<Map<String, dynamic>>> getVisibleUserLocations({
    double? latitude,
    double? longitude,
    double radiusInMeters = 50000.0, // Default to 50km
  }) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return [];

      // If coordinates aren't provided, use the current user's last known location
      double finalLat = latitude ?? 0.0;
      double finalLng = longitude ?? 0.0;

      if (latitude == null || longitude == null) {
        final profile = await _client
            .from('user_profiles')
            .select('current_latitude, current_longitude')
            .eq('id', currentUser.id)
            .maybeSingle();
        
        if (profile != null && profile['current_latitude'] != null) {
          finalLat = profile['current_latitude'] as double;
          finalLng = profile['current_longitude'] as double;
        } else {
          return []; // Cannot search without a center point
        }
      }

      // Call the high-performance Postgres spatial function
      final response = await _client.rpc('get_nearby_users', params: {
        'p_latitude': finalLat,
        'p_longitude': finalLng,
        'p_radius_meters': radiusInMeters,
      });

      final users = (response as List).cast<Map<String, dynamic>>();
      final visibleUsers = <Map<String, dynamic>>[];

      // Fetch following list for 'friends' mode filtering
      final following = await _socialService.getFollowing(currentUser.id);
      final followingIds = following.map((f) => f['id'] as String).toSet();

      for (final user in users) {
        final userId = user['id'] as String;
        if (userId == currentUser.id) continue;

        final sharingMode = user['location_sharing_mode'] as String;
        final blacklist = (user['location_blacklist'] as List<dynamic>?)?.cast<String>() ?? <String>[];

        // Ensure current user isn't blacklisted by the target user
        if (blacklist.contains(currentUser.id)) continue;

        if (sharingMode == 'public') {
          visibleUsers.add(user);
        } else if (sharingMode == 'friends' && followingIds.contains(userId)) {
          visibleUsers.add(user);
        }
      }

      return visibleUsers;
    } catch (e) {
      AppLogger.log('Error getting visible user locations: $e', name: 'LocationService');
      return [];
    }
  }

  /// Get online users near a specific location
  /// @deprecated Use getVisibleUserLocations directly as it now handles spatial filtering
  Future<List<Map<String, dynamic>>> getNearbyOnlineUsers(
    double latitude,
    double longitude, {
    double radiusInMeters = 100.0,
  }) async {
    return getVisibleUserLocations(
      latitude: latitude,
      longitude: longitude,
      radiusInMeters: radiusInMeters,
    );
  }

  /// Calculate distance between two coordinates in meters using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
