import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../models/trick_definition.dart';
import '../models/spot_video.dart';
import '../config/service_locator.dart';

class TrickService {
  final SupabaseClient? _injectedClient;

  TrickService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    if (_injectedClient != null) return _injectedClient!;
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Get trick suggestions based on user input
  Future<List<TrickDefinition>> getTrickSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Search in both definitions and aliases
      final response = await _client.rpc('search_tricks', params: {
        'search_query': query,
      });

      return (response as List)
          .map((data) => TrickDefinition.fromMap(data))
          .toList();
    } catch (e) {
      developer.log('Error getting trick suggestions: $e', name: 'TrickService');
      
      // Fallback simple search if RPC fails
      try {
        final response = await _client
            .from('trick_definitions')
            .select()
            .ilike('display_name', '%$query%')
            .limit(5);
        
        return (response as List)
            .map((data) => TrickDefinition.fromMap(data))
            .toList();
      } catch (fallbackError) {
        return [];
      }
    }
  }

  /// Submit a trick clip to a spot
  Future<void> submitTrick({
    required String spotId,
    required String userId,
    required String url,
    required String trickName,
    String? skaterName,
    String? description,
    required bool isOwnClip,
    required String stance,
    double difficultyMultiplier = 1.0,
    List<String> tags = const [],
  }) async {
    try {
      await _client.from('spot_videos').insert({
        'spot_id': spotId,
        'submitted_by': userId,
        'url': url,
        'trick_name': trickName,
        'skater_name': isOwnClip ? null : skaterName,
        'description': description,
        'is_own_clip': isOwnClip,
        'stance': stance,
        'difficulty_multiplier': difficultyMultiplier,
        'tags': tags,
        'status': 'approved', 
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // If it's a new trick name not in our registry, we could optionally add it to a 'community_tricks' table
      // for review, but for now we just store it in spot_videos.
    } catch (e) {
      developer.log('Error submitting trick: $e', name: 'TrickService');
      rethrow;
    }
  }

  /// Get trick archive for a spot
  Future<List<SpotVideo>> getSpotArchive(String spotId, {String? searchQuery, String? category}) async {
    try {
      var query = _client.from('spot_videos').select().eq('spot_id', spotId);
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('trick_name', '%$searchQuery%');
      }
      
      // Category filtering might require joining with trick_definitions
      // For MVP, we'll fetch all and filter client-side or use a more complex query
      final response = await query.order('created_at', ascending: false);
      
      return (response as List).map((data) => SpotVideo.fromMap(data)).toList();
    } catch (e) {
      developer.log('Error getting spot archive: $e', name: 'TrickService');
      return [];
    }
  }

  /// Get top clips (highlights) for a spot
  Future<List<SpotVideo>> getSpotHighlights(String spotId, {int limit = 3}) async {
    try {
      final response = await _client
          .from('spot_videos')
          .select()
          .eq('spot_id', spotId)
          .order('upvotes', ascending: false)
          .limit(limit);
          
      return (response as List).map((data) => SpotVideo.fromMap(data)).toList();
    } catch (e) {
      developer.log('Error getting spot highlights: $e', name: 'TrickService');
      return [];
    }
  }
}
