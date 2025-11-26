import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';
import 'package:prototype_0_0_1/services/post_service.dart';

void main() {
  group('PostService', () {
    setUp(() {
      // Create service without client for unit tests
      // Integration tests would use mock client
    });

    group('Model Operations', () {
      test('MapPost can be created with required fields', () {
        final post = MapPost(
          userId: 'user-1',
          title: 'Test Spot',
          description: 'A test skate spot',
          latitude: 40.7128,
          longitude: -74.0060,
          createdAt: DateTime.now(),
        );

        expect(post.userId, 'user-1');
        expect(post.title, 'Test Spot');
        expect(post.description, 'A test skate spot');
        expect(post.latitude, 40.7128);
        expect(post.longitude, -74.0060);
      });

      test('MapPost has correct default values', () {
        final post = MapPost(
          userId: 'user-1',
          title: 'Test',
          description: 'Test',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
        );

        expect(post.likes, 0);
        expect(post.popularityRating, 0.0);
        expect(post.securityRating, 0.0);
        expect(post.qualityRating, 0.0);
        expect(post.upvotes, 0);
        expect(post.downvotes, 0);
        expect(post.voteScore, 0);
        expect(post.category, 'Other');
        expect(post.tags, isEmpty);
      });

      test('MapPost fromMap parses JSON correctly', () {
        final json = {
          'id': 'post-123',
          'user_id': 'user-1',
          'user_name': 'TestUser',
          'title': 'Cool Spot',
          'description': 'A cool spot to skate',
          'latitude': 34.0522,
          'longitude': -118.2437,
          'created_at': '2024-01-15T10:30:00.000Z',
          'category': 'Street',
          'tags': ['rail', 'ledge'],
          'likes': 42,
          'popularity_rating': 4.5,
        };

        final post = MapPost.fromMap(json);

        expect(post.id, 'post-123');
        expect(post.userId, 'user-1');
        expect(post.userName, 'TestUser');
        expect(post.title, 'Cool Spot');
        expect(post.category, 'Street');
        expect(post.tags, ['rail', 'ledge']);
        expect(post.likes, 42);
        expect(post.popularityRating, 4.5);
      });

      test('MapPost toMap serializes correctly', () {
        final now = DateTime.now();
        final post = MapPost(
          userId: 'user-1',
          userName: 'TestUser',
          title: 'Test Spot',
          description: 'Description',
          latitude: 40.0,
          longitude: -74.0,
          createdAt: now,
          category: 'Park',
          tags: ['smooth'],
          likes: 10,
        );

        final map = post.toMap();

        expect(map['user_id'], 'user-1');
        expect(map['user_name'], 'TestUser');
        expect(map['title'], 'Test Spot');
        expect(map['description'], 'Description');
        expect(map['latitude'], 40.0);
        expect(map['longitude'], -74.0);
        expect(map['category'], 'Park');
        expect(map['tags'], ['smooth']);
        expect(map['likes'], 10);
        expect(map.containsKey('id'), false);
      });

      test('MapPost handles missing optional fields in fromMap', () {
        final json = {
          'id': 'post-1',
          'user_id': 'user-1',
          'title': 'Basic',
          'description': 'Basic spot',
          'latitude': 0.0,
          'longitude': 0.0,
          'created_at': '2024-01-01T00:00:00.000Z',
        };

        final post = MapPost.fromMap(json);

        expect(post.userName, null);
        expect(post.userEmail, null);
        expect(post.photoUrl, null);
        expect(post.category, 'Other');
        expect(post.tags, isEmpty);
        expect(post.userVote, null);
      });

      test('MapPost handles integer ratings in fromMap', () {
        final json = {
          'id': 'post-1',
          'user_id': 'user-1',
          'title': 'Test',
          'description': 'Test',
          'latitude': 0.0,
          'longitude': 0.0,
          'created_at': '2024-01-01T00:00:00.000Z',
          'popularity_rating': 4,
          'security_rating': 3,
          'quality_rating': 5,
        };

        final post = MapPost.fromMap(json);

        expect(post.popularityRating, 4.0);
        expect(post.securityRating, 3.0);
        expect(post.qualityRating, 5.0);
      });
    });

    group('PostService instantiation', () {
      test('can be created without client', () {
        final service = PostService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = PostService(client: null);
        expect(service, isNotNull);
      });
    });
  });
}
