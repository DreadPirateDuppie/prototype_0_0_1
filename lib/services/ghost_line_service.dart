import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../models/ghost_line.dart';
import '../config/service_locator.dart';

class GhostLineService {
  final SupabaseClient? _injectedClient;

  GhostLineService({SupabaseClient? client}) : _injectedClient = client;

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

  /// Fetch ghost lines for a specific spot
  Future<List<GhostLine>> getLinesAtSpot(String spotId) async {
    try {
      final response = await _client
          .from('ghost_lines')
          .select()
          .eq('spot_id', spotId)
          .order('created_at', ascending: false);
      
      return (response as List).map((e) => GhostLine.fromMap(e)).toList();
    } catch (e) {
      developer.log('Error fetching ghost lines: $e', name: 'GhostLineService');
      return [];
    }
  }

  /// Create a new ghost line
  Future<GhostLine?> createGhostLine({
    required String spotId,
    required String creatorId,
    required String videoUrl,
    String? thumbnailUrl,
    required List<GhostPathPoint> pathPoints,
    List<GhostTrickMarker> trickMarkers = const [],
    int? durationSeconds,
    double? distanceMeters,
  }) async {
    try {
      final response = await _client.from('ghost_lines').insert({
        'spot_id': spotId,
        'creator_id': creatorId,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'path_points': pathPoints.map((e) => e.toMap()).toList(),
        'trick_markers': trickMarkers.map((e) => e.toMap()).toList(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
      }).select().single();

      return GhostLine.fromMap(response);
    } catch (e) {
      developer.log('Error creating ghost line: $e', name: 'GhostLineService');
      return null;
    }
  }
}
