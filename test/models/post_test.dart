import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';

void main() {
  group('MapPost Model', () {
    test('fromMap() creates valid MapPost from JSON', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'user_name': 'TestUser',
        'user_email': 'test@example.com',
        'title': 'Awesome Spot',
        'description': 'Great place to skate',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'created_at': '2024-01-15T10:30:00.000Z',
        'category': 'Street',
        'tags': ['smooth', 'ledge'],
        'likes': 10,
        'popularity_rating': 4.5,
        'security_rating': 3.0,
        'quality_rating': 4.0,
        'upvotes': 15,
        'downvotes': 2,
        'vote_score': 13,
      };

      final post = MapPost.fromMap(json);

      expect(post.id, 'post-1');
      expect(post.userId, 'user-1');
      expect(post.userName, 'TestUser');
      expect(post.title, 'Awesome Spot');
      expect(post.description, 'Great place to skate');
      expect(post.latitude, 37.7749);
      expect(post.longitude, -122.4194);
      expect(post.category, 'Street');
      expect(post.tags, ['smooth', 'ledge']);
      expect(post.likes, 10);
      expect(post.popularityRating, 4.5);
      expect(post.securityRating, 3.0);
      expect(post.qualityRating, 4.0);
      expect(post.upvotes, 15);
      expect(post.downvotes, 2);
      expect(post.voteScore, 13);
    });

    test('fromMap() handles null/missing optional fields', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'title': 'Basic Spot',
        'description': 'A basic spot',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'created_at': '2024-01-15T10:30:00.000Z',
      };

      final post = MapPost.fromMap(json);

      expect(post.id, 'post-1');
      expect(post.userName, null);
      expect(post.userEmail, null);
      expect(post.photoUrl, null);
      expect(post.category, 'Other');
      expect(post.tags, isEmpty);
      expect(post.likes, 0);
      expect(post.popularityRating, 0.0);
      expect(post.securityRating, 0.0);
      expect(post.qualityRating, 0.0);
      expect(post.upvotes, 0);
      expect(post.downvotes, 0);
      expect(post.voteScore, 0);
      expect(post.userVote, null);
    });

    test('toMap() serializes MapPost correctly', () {
      final now = DateTime.now();
      final post = MapPost(
        id: 'post-1',
        userId: 'user-1',
        userName: 'TestUser',
        userEmail: 'test@example.com',
        title: 'Awesome Spot',
        description: 'Great place to skate',
        latitude: 37.7749,
        longitude: -122.4194,
        createdAt: now,
        category: 'Street',
        tags: ['smooth', 'ledge'],
        likes: 10,
        photoUrl: 'https://example.com/photo.jpg',
        popularityRating: 4.5,
        securityRating: 3.0,
        qualityRating: 4.0,
        upvotes: 15,
        downvotes: 2,
        voteScore: 13,
      );

      final json = post.toMap();

      expect(json['user_id'], 'user-1');
      expect(json['user_name'], 'TestUser');
      expect(json['user_email'], 'test@example.com');
      expect(json['title'], 'Awesome Spot');
      expect(json['description'], 'Great place to skate');
      expect(json['latitude'], 37.7749);
      expect(json['longitude'], -122.4194);
      expect(json['category'], 'Street');
      expect(json['tags'], ['smooth', 'ledge']);
      expect(json['likes'], 10);
      expect(json['photo_url'], 'https://example.com/photo.jpg');
      expect(json['popularity_rating'], 4.5);
      expect(json['security_rating'], 3.0);
      expect(json['quality_rating'], 4.0);
    });

    test('toMap() does not include id field', () {
      final post = MapPost(
        id: 'post-1',
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
      );

      final json = post.toMap();

      expect(json.containsKey('id'), false);
    });

    test('fromMap() handles numeric ratings correctly', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'title': 'Test Spot',
        'description': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
        'created_at': '2024-01-15T10:30:00.000Z',
        'popularity_rating': 3, // int instead of double
        'security_rating': 4, // int instead of double
        'quality_rating': 5, // int instead of double
      };

      final post = MapPost.fromMap(json);

      expect(post.popularityRating, 3.0);
      expect(post.securityRating, 4.0);
      expect(post.qualityRating, 5.0);
    });

    test('MapPost default values are set correctly', () {
      final now = DateTime.now();
      final post = MapPost(
        userId: 'user-1',
        title: 'Test Spot',
        description: 'A test spot',
        latitude: 51.5074,
        longitude: -0.1278,
        createdAt: now,
      );

      expect(post.id, null);
      expect(post.userName, null);
      expect(post.userEmail, null);
      expect(post.likes, 0);
      expect(post.photoUrl, null);
      expect(post.popularityRating, 0.0);
      expect(post.securityRating, 0.0);
      expect(post.qualityRating, 0.0);
      expect(post.upvotes, 0);
      expect(post.downvotes, 0);
      expect(post.voteScore, 0);
      expect(post.userVote, null);
      expect(post.category, 'Other');
      expect(post.tags, isEmpty);
    });

    test('fromMap() parses created_at datetime correctly', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'title': 'Test',
        'description': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
        'created_at': '2024-06-15T14:30:00.000Z',
      };

      final post = MapPost.fromMap(json);

      expect(post.createdAt.year, 2024);
      expect(post.createdAt.month, 6);
      expect(post.createdAt.day, 15);
    });

    test('fromMap() handles tags list correctly', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'title': 'Test',
        'description': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
        'created_at': '2024-01-15T10:30:00.000Z',
        'tags': ['ledge', 'rail', 'flatground'],
      };

      final post = MapPost.fromMap(json);

      expect(post.tags.length, 3);
      expect(post.tags.contains('ledge'), true);
      expect(post.tags.contains('rail'), true);
      expect(post.tags.contains('flatground'), true);
    });

    test('toMap() includes created_at as ISO string', () {
      final now = DateTime(2024, 7, 20, 12, 0, 0);
      final post = MapPost(
        userId: 'user-1',
        title: 'Test',
        description: 'Test',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: now,
      );

      final json = post.toMap();

      expect(json['created_at'], now.toIso8601String());
    });
  });
}
