import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/nbd_clip.dart';

void main() {
  group('NbdClip', () {
    final fullMap = {
      'id': 'clip-1',
      'user_id': 'user-1',
      'video_url': 'https://cdn.example/nbd.mp4',
      'thumbnail_url': 'https://cdn.example/nbd.jpg',
      'trick_name': 'Nollie heel bigspin tailslide',
      'description': 'First ever on the Southbank 7',
      'latitude': 51.5065,
      'longitude': -0.1163,
      'spot_id': 'spot-1',
      'is_nbd': true,
      'status': 'approved',
      'approved_at': '2026-07-08T12:00:00Z',
      'bounty_points': 250,
      'bounty_paid': true,
      'created_at': '2026-07-08T10:00:00Z',
    };

    test('fromMap parses a full row', () {
      final clip = NbdClip.fromMap(fullMap);
      expect(clip.id, 'clip-1');
      expect(clip.userId, 'user-1');
      expect(clip.trickName, 'Nollie heel bigspin tailslide');
      expect(clip.latitude, closeTo(51.5065, 1e-9));
      expect(clip.longitude, closeTo(-0.1163, 1e-9));
      expect(clip.spotId, 'spot-1');
      expect(clip.isNbd, isTrue);
      expect(clip.isApproved, isTrue);
      expect(clip.isPending, isFalse);
      expect(clip.isRejected, isFalse);
      expect(clip.approvedAt, isNotNull);
      expect(clip.bountyPoints, 250.0);
      expect(clip.bountyPaid, isTrue);
    });

    test('fromMap defaults for a minimal pending row', () {
      final clip = NbdClip.fromMap({
        'user_id': 'user-1',
        'video_url': 'https://cdn.example/nbd.mp4',
        'trick_name': 'Switch flip',
        'latitude': 51.0,
        'longitude': 0.0,
        'created_at': '2026-07-08T10:00:00Z',
      });
      expect(clip.id, isNull);
      expect(clip.isNbd, isTrue);
      expect(clip.status, 'pending');
      expect(clip.isPending, isTrue);
      expect(clip.bountyPaid, isFalse);
      expect(clip.bountyPoints, isNull);
      expect(clip.spotId, isNull);
    });

    test('toMap round-trips the wire fields', () {
      final clip = NbdClip.fromMap(fullMap);
      final map = clip.toMap();
      expect(map['id'], 'clip-1');
      expect(map['trick_name'], fullMap['trick_name']);
      expect(map['latitude'], fullMap['latitude']);
      expect(map['status'], 'approved');
      expect(map['bounty_paid'], isTrue);
    });

    test('toMap omits id when unset (insert path)', () {
      final clip = NbdClip(
        userId: 'user-1',
        videoUrl: 'https://cdn.example/nbd.mp4',
        trickName: 'Switch flip',
        latitude: 51.0,
        longitude: 0.0,
        createdAt: DateTime.utc(2026, 7, 8),
      );
      expect(clip.toMap().containsKey('id'), isFalse);
    });
  });

  group('NbdReview', () {
    test('fromMap parses a verdict row', () {
      final review = NbdReview.fromMap({
        'id': 'rev-1',
        'clip_id': 'clip-1',
        'reviewer_id': 'vet-1',
        'verdict': 'approve',
        'notes': 'Clean landing, genuinely never been done there.',
        'created_at': '2026-07-08T11:00:00Z',
      });
      expect(review.clipId, 'clip-1');
      expect(review.reviewerId, 'vet-1');
      expect(review.verdict, 'approve');
      expect(review.notes, isNotEmpty);
    });
  });
}
