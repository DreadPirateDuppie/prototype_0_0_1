import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/borough.dart';
import '../config/service_locator.dart';

/// Service for the Territorial Capture ("Borough Turf") system.
///
/// All scoring is server-authoritative: this service only reads the
/// `borough_states` view and calls SECURITY DEFINER RPCs
/// (see supabase/migrations/20260706_territorial_capture.sql).
class TerritoryService {
  final SupabaseClient? _injectedClient;

  TerritoryService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) return injected;
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Fetch the live state of every borough (ownership, defense,
  /// destabilization, fragility) for the map layer.
  Future<List<BoroughState>> getBoroughStates() async {
    try {
      final response = await _client.from('borough_states').select();
      return (response as List)
          .map((row) => BoroughState.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('Error fetching borough states: $e',
          name: 'TerritoryService');
      return [];
    }
  }

  /// Report a newly created spot (map post) into the territory pipeline.
  /// Fire-and-forget safe: never throws.
  Future<Map<String, dynamic>?> reportSpotCreated(String postId) =>
      _reportActivity(referenceId: postId, activityType: 'spot_created');

  /// Report an uploaded clip (spot video) into the territory pipeline.
  /// Fire-and-forget safe: never throws.
  Future<Map<String, dynamic>?> reportClipUpload(String videoId) =>
      _reportActivity(referenceId: videoId, activityType: 'clip_upload');

  Future<Map<String, dynamic>?> _reportActivity({
    required String referenceId,
    required String activityType,
  }) async {
    try {
      final response = await _client.rpc('record_territory_activity', params: {
        'p_reference_id': referenceId,
        'p_activity_type': activityType,
      });
      if (response is Map<String, dynamic>) return response;
      return null;
    } catch (e) {
      // Territory reporting must never break the upload/post flow.
      AppLogger.log('Error reporting territory activity ($activityType): $e',
          name: 'TerritoryService');
      return null;
    }
  }

  /// The current user's crew (`{crew_id, crews: {id, name, color_hex}}`),
  /// or null if they ride solo.
  Future<Map<String, dynamic>?> getMyCrew() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _client
          .from('crew_members')
          .select('crew_id, role, crews(id, name, color_hex)')
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      AppLogger.log('Error fetching crew: $e', name: 'TerritoryService');
      return null;
    }
  }

  /// Create a crew (server enforces one-crew-per-user and name/colour rules).
  /// Returns the new crew id.
  Future<String> createCrew(String name, {String colorHex = '#00FF41'}) async {
    final response = await _client.rpc('create_crew', params: {
      'p_name': name,
      'p_color_hex': colorHex,
    });
    return response as String;
  }

  /// Join an existing crew (server enforces the member cap, default 6).
  Future<void> joinCrew(String crewId) async {
    await _client.rpc('join_crew', params: {'p_crew_id': crewId});
  }

  /// Leave the current crew (empty crews are dissolved server-side).
  Future<void> leaveCrew() async {
    await _client.rpc('leave_crew');
  }
}
