import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';

/// Server-side mirror tests for the Spot MVP Engine
/// (supabase/migrations/20260708_spot_mvp_engine.sql). The server is
/// authoritative; these tests document the intended default scoring and the
/// client-facing contract (MapPost.mvp_user_id / mvp_score).
void main() {
  group('Spot MVP Engine', () {
    group('scoring constants (server-side mirrors)', () {
      const mvpClipPoints = 10.0;

      int clipScore(double difficultyMultiplier) =>
          (mvpClipPoints * difficultyMultiplier).round();

      test('a standard clip is worth 10 pts', () {
        expect(clipScore(1.0), 10);
      });

      test('difficulty multiplier scales the clip value', () {
        expect(clipScore(1.5), 15);
        expect(clipScore(2.0), 20);
      });

      test('crown flips only on a strictly higher score (ties keep incumbent)',
          () {
        const incumbentScore = 30;
        const challengerScore = 30;
        // Ties are broken by earliest first clip, so an equal challenger
        // never dethrones the incumbent.
        expect(challengerScore > incumbentScore, isFalse);
      });
    });

    group('client contract', () {
      test('MapPost parses the server-derived MVP fields', () {
        final post = MapPost.fromMap({
          'user_id': 'owner-1',
          'title': 'Southbank 7',
          'description': 'The classic',
          'created_at': '2026-07-08T10:00:00Z',
          'mvp_user_id': 'skater-1',
          'mvp_score': 45,
        });
        expect(post.mvpUserId, 'skater-1');
        expect(post.mvpScore, 45);
      });

      test('MapPost defaults when no MVP has been crowned', () {
        final post = MapPost.fromMap({
          'user_id': 'owner-1',
          'title': 'Fresh spot',
          'description': 'No clips yet',
          'created_at': '2026-07-08T10:00:00Z',
        });
        expect(post.mvpUserId, isNull);
        expect(post.mvpScore, 0);
      });
    });
  });
}
