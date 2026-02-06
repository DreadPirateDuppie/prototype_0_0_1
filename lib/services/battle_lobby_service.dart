import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../config/service_locator.dart';
import 'auth_service.dart';

class BattleLobbyService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final AuthService _authService = getIt<AuthService>();

  /// Create a new lobby
  static Future<String> createLobby() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) throw Exception('Not logged in');

      // Generate a 6-character alphanumeric code
      final code = _generateRandomCode(6);

      final response = await _client.from('skate_lobbies').insert({
        'code': code,
        'host_id': user.id,
        'status': 'waiting',
      }).select('id').single();

      final lobbyId = response['id'] as String;

      // Add host as first player
      await _client.from('skate_lobby_players').insert({
        'lobby_id': lobbyId,
        'user_id': user.id,
        'is_host': true,
      });

      AppLogger.log('Lobby created: $code ($lobbyId)', name: 'BattleLobbyService');
      return lobbyId;
    } catch (e) {
      AppLogger.log('Error creating lobby: $e', name: 'BattleLobbyService');
      rethrow;
    }
  }

  /// Join an existing lobby via code
  static Future<String> joinLobby(String code) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) throw Exception('Not logged in');

      // Find lobby by code
      final lobby = await _client
          .from('skate_lobbies')
          .select('id, status')
          .eq('code', code.toUpperCase())
          .maybeSingle();

      if (lobby == null) throw Exception('Lobby not found');
      if (lobby['status'] != 'waiting') throw Exception('Lobby is no longer waiting');

      final lobbyId = lobby['id'] as String;

      // Add player (upsert to handle re-joining)
      await _client.from('skate_lobby_players').upsert({
        'lobby_id': lobbyId,
        'user_id': user.id,
        'is_host': false,
      });

      AppLogger.log('User ${user.id} joined lobby $code', name: 'BattleLobbyService');
      return lobbyId;
    } catch (e) {
      AppLogger.log('Error joining lobby: $e', name: 'BattleLobbyService');
      rethrow;
    }
  }

  /// Stream lobby data
  static Stream<Map<String, dynamic>> streamLobby(String lobbyId) {
    return _client
        .from('skate_lobbies')
        .stream(primaryKey: ['id'])
        .eq('id', lobbyId)
        .map((results) => results.isNotEmpty ? results.first : {});
  }

  /// Stream lobby players
  static Stream<List<Map<String, dynamic>>> streamLobbyPlayers(String lobbyId) {
    return _client
        .from('skate_lobby_players')
        .stream(primaryKey: ['lobby_id', 'user_id'])
        .eq('lobby_id', lobbyId);
  }

  /// Stream lobby events
  static Stream<Map<String, dynamic>> streamLobbyEvents(String lobbyId) {
    return _client
        .from('skate_lobby_events')
        .stream(primaryKey: ['id'])
        .eq('lobby_id', lobbyId)
        .map((results) => results.isNotEmpty ? results.last : {});
  }

  /// Leave a lobby
  static Future<void> leaveLobby(String lobbyId) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) return;

      // Check if user is host
      final player = await _client
          .from('skate_lobby_players')
          .select('is_host')
          .eq('lobby_id', lobbyId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (player != null && player['is_host'] == true) {
        // Close lobby if host leaves
        await _client
            .from('skate_lobbies')
            .update({'status': 'completed'})
            .eq('id', lobbyId);
      }

      // Remove player
      await _client
          .from('skate_lobby_players')
          .delete()
          .eq('lobby_id', lobbyId)
          .eq('user_id', user.id);

    } catch (e) {
      AppLogger.log('Error leaving lobby: $e', name: 'BattleLobbyService');
    }
  }

  /// Update player letters (e.g., S-K-A-T-E)
  static Future<void> updatePlayerLetters(String lobbyId, List<String> letters) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) return;

      await _client
          .from('skate_lobby_players')
          .update({'letters': letters.join('')})
          .eq('lobby_id', lobbyId)
          .eq('user_id', user.id);
    } catch (e) {
      AppLogger.log('Error updating letters: $e', name: 'BattleLobbyService');
    }
  }

  /// Send an event to the lobby
  static Future<void> sendLobbyEvent(String lobbyId, String type, Map<String, dynamic> data) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) return;

      await _client.from('skate_lobby_events').insert({
        'lobby_id': lobbyId,
        'user_id': user.id,
        'event_type': type,
        'data': data.toString(), // Convert to string as per schema (TEXT)
      });
    } catch (e) {
      AppLogger.log('Error sending lobby event: $e', name: 'BattleLobbyService');
    }
  }

  /// Generate a random alphanumeric code
  static String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude ambiguous chars
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return String.fromCharCodes(Iterable.generate(
      length, 
      (i) => chars.codeUnitAt((rnd + (i * 37)) % chars.length)
    ));
  }
}
