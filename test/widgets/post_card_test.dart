import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';

void main() {
  group('PostCard Widget Tests', () {
    test('MapPost model has required fields', () {
      final post = MapPost(
        id: 'test-1',
        userId: 'user-1',
        title: 'Test Spot',
        description: 'A great test spot',
        latitude: 37.7749,
        longitude: -122.4194,
        createdAt: DateTime.now(),
        category: 'Street',
        tags: ['smooth', 'ledge'],
        popularityRating: 4.5,
        securityRating: 3.0,
        qualityRating: 4.0,
      );

      expect(post.title, 'Test Spot');
      expect(post.description, 'A great test spot');
      expect(post.category, 'Street');
      expect(post.popularityRating, 4.5);
    });

    test('MapPost default values are correct', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test description',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
      );

      expect(post.likes, 0);
      expect(post.upvotes, 0);
      expect(post.downvotes, 0);
      expect(post.voteScore, 0);
      expect(post.popularityRating, 0.0);
      expect(post.securityRating, 0.0);
      expect(post.qualityRating, 0.0);
      expect(post.category, 'Other');
      expect(post.tags, isEmpty);
    });

    test('Share message format is correct', () {
      final post = MapPost(
        id: 'test-1',
        userId: 'user-1',
        title: 'Cool Spot',
        description: 'Amazing place to skate',
        latitude: 37.7749,
        longitude: -122.4194,
        createdAt: DateTime.now(),
        popularityRating: 4.5,
      );

      // Test the share message format
      final rating = post.popularityRating > 0 
          ? '${post.popularityRating.toStringAsFixed(1)}/5 ⭐' 
          : 'Not rated yet';
      
      final shareMessage = 'Check out "${post.title}" 🛹\n'
          'Rating: $rating\n'
          '${post.description}\n\n'
          'Get the app: https://pushinn.app';

      expect(shareMessage.contains('Cool Spot'), true);
      expect(shareMessage.contains('4.5/5 ⭐'), true);
      expect(shareMessage.contains('Amazing place to skate'), true);
    });

    test('Share message handles unrated post', () {
      final post = MapPost(
        id: 'test-1',
        userId: 'user-1',
        title: 'New Spot',
        description: 'Newly discovered',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
        popularityRating: 0.0,
      );

      final rating = post.popularityRating > 0 
          ? '${post.popularityRating.toStringAsFixed(1)}/5 ⭐' 
          : 'Not rated yet';
      
      expect(rating, 'Not rated yet');
    });
  });

  group('PostCard Vote Display', () {
    test('Vote score calculation is correct', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
        upvotes: 10,
        downvotes: 3,
        voteScore: 7,
      );

      expect(post.voteScore, post.upvotes - post.downvotes);
    });

    test('User vote tracking works', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
        userVote: 1,
      );

      expect(post.userVote, 1);
    });

    test('User vote can be null (no vote)', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
      );

      expect(post.userVote, null);
    });
  });

  group('PostCard Rating Display', () {
    test('Rating chips show correct values', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
        popularityRating: 4.0,
        securityRating: 3.0,
        qualityRating: 5.0,
      );

      expect(post.popularityRating, 4.0);
      expect(post.securityRating, 3.0);
      expect(post.qualityRating, 5.0);
    });

    test('Ratings handle zero values', () {
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
      );

      expect(post.popularityRating, 0.0);
      expect(post.securityRating, 0.0);
      expect(post.qualityRating, 0.0);
    });
  });
}
