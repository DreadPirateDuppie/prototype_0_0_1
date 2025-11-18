import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';

class VsTab extends StatefulWidget {
  const VsTab({super.key});

  @override
  State<VsTab> createState() => _VsTabState();
}

class _VsTabState extends State<VsTab> {
  List<Map<String, dynamic>> _activeSkaters = [];
  final Map<String, MapPost> _postById = {};
  LatLng? _currentLocation;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadPostsIndex();
    _subscribePresence();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadPostsIndex() async {
    try {
      final posts = await SupabaseService.getAllMapPosts();
      setState(() {
        for (final p in posts) {
          if (p.id != null) {
            _postById[p.id!] = p;
          }
        }
      });
    } catch (e) {
      // ignore
    }
  }

  void _subscribePresence() {
    _channel = Supabase.instance.client
        .channel('active_skaters', opts: const RealtimeChannelConfig(self: true));
    _channel!.onPresenceSync((_) {
      final state = SupabaseService.getActiveSkatersPresence();
      setState(() {
        _activeSkaters = state;
      });
    });
    _channel!.subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VS Mode'),
      ),
      body: _activeSkaters.isEmpty
          ? const Center(child: Text('No active skaters sharing location'))
          : ListView.separated(
              itemCount: _activeSkaters.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _activeSkaters[index];
                final username = (entry['username'] as String?) ?? 'Skater';
                final lat = (entry['lat'] as num?)?.toDouble();
                final lng = (entry['lng'] as num?)?.toDouble();
                final spotId = entry['spot_id'] as String?;
                final spotTitle = spotId != null && _postById.containsKey(spotId)
                    ? _postById[spotId]!.title
                    : null;

                String subtitle;
                if (spotTitle != null) {
                  subtitle = 'At: $spotTitle';
                } else if (lat != null && lng != null) {
                  subtitle = 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
                } else {
                  subtitle = 'Location unknown';
                }

                String? distanceText;
                if (_currentLocation != null && lat != null && lng != null) {
                  final d = Distance();
                  final meters = d(
                    _currentLocation!,
                    LatLng(lat, lng),
                  );
                  distanceText = '${meters.toStringAsFixed(0)} m';
                }

                return ListTile(
                  leading: const Icon(Icons.person_pin_circle),
                  title: Text(username),
                  subtitle: Text(subtitle),
                  trailing: distanceText != null ? Text(distanceText) : null,
                );
              },
            ),
    );
  }
}