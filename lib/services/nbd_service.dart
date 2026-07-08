import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/nbd_clip.dart';
import 'error_types.dart';
import '../config/service_locator.dart';

/// Service for the NBD ("Never Been Done") Registry — Master Blueprint §3.3.
///
/// Server-authoritative: clips are INSERT-only for clients (immutable once
/// submitted — "permanently locked"); all state transitions (approve/reject/
/// bounty payout) happen through the `submit_nbd_review` SECURITY DEFINER RPC
/// (see supabase/migrations/20260708_nbd_registry.sql).
class NbdService {
  final SupabaseClient? _injectedClient;

  NbdService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) return injected;
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Upload a raw NBD clip video to storage. Reuses the post_videos bucket
  /// (same pipeline as PostService.uploadPostVideo) with an nbd_ prefix.
  Future<String> uploadNbdVideo(File videoFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'nbd_${userId}_$timestamp.mp4';

      final bytes = await videoFile.readAsBytes();
      await _client.storage.from('post_videos').uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );

      return _client.storage.from('post_videos').getPublicUrl(filename);
    } catch (e) {
      throw AppStorageException(
        'Failed to upload NBD video: $e',
        userMessage: 'Video upload failed. Please try again.',
        originalError: e,
      );
    }
  }

  /// Submit a new NBD claim, pinned to exact coordinates. The clip enters
  /// the peer-review queue as 'pending' and is immutable from here on.
  Future<NbdClip?> submitNbdClip({
    required String userId,
    required String videoUrl,
    required String trickName,
    required double latitude,
    required double longitude,
    String? thumbnailUrl,
    String? description,
    String? spotId,
  }) async {
    try {
      final response = await _client
          .from('clips')
          .insert({
            'user_id': userId,
            'video_url': videoUrl,
            'thumbnail_url': thumbnailUrl,
            'trick_name': trickName,
            'description': description,
            'latitude': latitude,
            'longitude': longitude,
            'spot_id': spotId,
            'is_nbd': true,
            'status': 'pending',
          })
          .select()
          .single();

      return NbdClip.fromMap(response);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error while submitting NBD clip',
        originalError: e,
      );
    } catch (e) {
      throw AppServerException(
        'Failed to submit NBD clip: $e',
        userMessage: 'Unable to submit NBD claim. Please try again.',
        originalError: e,
      );
    }
  }

  /// The public registry: approved clips permanently locked to the map,
  /// newest first.
  Future<List<NbdClip>> getRegistry({int page = 1, int pageSize = 20}) async {
    try {
      final from = (page - 1) * pageSize;
      final response = await _client
          .from('clips')
          .select()
          .eq('status', 'approved')
          .order('approved_at', ascending: false)
          .range(from, from + pageSize - 1);

      return (response as List)
          .map((row) => NbdClip.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('Error fetching NBD registry: $e', name: 'NbdService');
      return [];
    }
  }

  /// The caller's own submissions (any status), newest first.
  Future<List<NbdClip>> getMyClips(String userId) async {
    try {
      final response = await _client
          .from('clips')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => NbdClip.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('Error fetching own NBD clips: $e', name: 'NbdService');
      return [];
    }
  }

  /// Whether the current user is on the NBD review panel (or an admin).
  /// Reviewer status is granted server-side (user_profiles.is_nbd_reviewer).
  Future<bool> isReviewer(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('is_nbd_reviewer, is_admin')
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return false;
      return (response['is_nbd_reviewer'] as bool? ?? false) ||
          (response['is_admin'] as bool? ?? false);
    } catch (e) {
      return false;
    }
  }

  /// Pending clips awaiting the caller's verdict (reviewers only — RLS hides
  /// the queue from everyone else). Excludes the reviewer's own submissions.
  Future<List<NbdClip>> getReviewQueue(String reviewerId) async {
    try {
      final response = await _client
          .from('clips')
          .select()
          .eq('status', 'pending')
          .neq('user_id', reviewerId)
          .order('created_at', ascending: true);

      final clips = (response as List)
          .map((row) => NbdClip.fromMap(row as Map<String, dynamic>))
          .toList();
      if (clips.isEmpty) return clips;

      // Hide clips this reviewer has already voted on.
      final reviewed = await _client
          .from('nbd_reviews')
          .select('clip_id')
          .eq('reviewer_id', reviewerId);
      final reviewedIds = (reviewed as List)
          .map((r) => r['clip_id'] as String)
          .toSet();

      return clips.where((c) => !reviewedIds.contains(c.id)).toList();
    } catch (e) {
      AppLogger.log('Error fetching NBD review queue: $e', name: 'NbdService');
      return [];
    }
  }

  /// Cast a verdict on a pending clip. The server validates the reviewer
  /// role, blocks self-review and double-votes, and — atomically — approves/
  /// rejects the clip and pays the bounty once the threshold is met.
  /// Returns the RPC payload: {status, approvals, rejections,
  /// approvals_required}, or null on failure.
  Future<Map<String, dynamic>?> submitReview({
    required String clipId,
    required bool approve,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc('submit_nbd_review', params: {
        'p_clip_id': clipId,
        'p_verdict': approve ? 'approve' : 'reject',
        if (notes != null) 'p_notes': notes,
      });
      if (response is Map<String, dynamic>) return response;
      return null;
    } catch (e) {
      AppLogger.log('Error submitting NBD review: $e', name: 'NbdService');
      rethrow;
    }
  }
}
