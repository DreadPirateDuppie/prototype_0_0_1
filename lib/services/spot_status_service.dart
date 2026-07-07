import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/spot_status.dart';
import '../config/service_locator.dart';

/// Service for the Live Intelligence / Status Engine ("Waze for Skating").
///
/// Server-authoritative: this service only reads the `spot_current_status`
/// view and calls the `report_spot_status` SECURITY DEFINER RPC (see
/// supabase/migrations/20260707_spot_status_engine.sql). Clients never write
/// directly to `spot_status_reports`.
class SpotStatusService {
  final SupabaseClient? _injectedClient;

  SpotStatusService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) return injected;
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Fetch the current live status for one spot. Returns CLEAR (not null)
  /// when there is no unexpired report, matching the server's TTL semantics.
  Future<SpotStatus> getSpotStatus(String spotId) async {
    try {
      final response = await _client
          .from('spot_current_status')
          .select()
          .eq('spot_id', spotId)
          .maybeSingle();
      if (response == null) return SpotStatus.clearFor(spotId);
      return SpotStatus.fromMap(response);
    } catch (e) {
      AppLogger.log('Error fetching spot status: $e', name: 'SpotStatusService');
      return SpotStatus.clearFor(spotId);
    }
  }

  /// Bulk fetch of every spot with a currently active (non-expired) status,
  /// for map-layer badges. Spots not present in the result are CLEAR.
  Future<Map<String, SpotStatus>> getActiveStatuses() async {
    try {
      final response = await _client.from('spot_current_status').select();
      final statuses = <String, SpotStatus>{};
      for (final row in response as List) {
        final status = SpotStatus.fromMap(row as Map<String, dynamic>);
        statuses[status.spotId] = status;
      }
      return statuses;
    } catch (e) {
      AppLogger.log('Error fetching active spot statuses: $e',
          name: 'SpotStatusService');
      return {};
    }
  }

  /// Submit a Quick-Report. Server enforces the per-user cooldown and fires
  /// "Heads Up" notifications for SECURITY_ACTIVE / LOCKED_OFF escalations.
  /// Returns the RPC's result payload, or null on failure.
  Future<Map<String, dynamic>?> reportStatus(
    String spotId,
    SpotStatusType status,
  ) async {
    try {
      final response = await _client.rpc('report_spot_status', params: {
        'p_spot_id': spotId,
        'p_status': status.wireValue,
      });
      if (response is Map<String, dynamic>) return response;
      return null;
    } catch (e) {
      AppLogger.log('Error reporting spot status: $e', name: 'SpotStatusService');
      return null;
    }
  }

  /// Live updates for one spot's status reports (Quick-Report screen /
  /// Spot Detail banner). Mirrors the channel-per-resource pattern used by
  /// MessagingService.subscribeToMessages.
  Stream<SpotStatus> subscribeToSpotStatus(String spotId) {
    final controller = StreamController<SpotStatus>.broadcast();

    getSpotStatus(spotId).then((status) {
      if (!controller.isClosed) controller.add(status);
    });

    final channel = _client.channel('spot_status:$spotId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'spot_status_reports',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'spot_id',
        value: spotId,
      ),
      callback: (payload) async {
        final status = await getSpotStatus(spotId);
        if (!controller.isClosed) controller.add(status);
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  /// Distinct triple-pulse vibration pattern for `SECURITY_ACTIVE` Heads Up
  /// alerts, so a skater gets non-visual tactical awareness (spec: "Haptic
  /// Triggers"). Safe to call even on platforms without vibration hardware —
  /// HapticFeedback silently no-ops.
  static Future<void> triggerSecurityAlertHaptic() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.vibrate();
    } catch (_) {
      // Haptics are a nice-to-have; never let them crash the report flow.
    }
  }
}
