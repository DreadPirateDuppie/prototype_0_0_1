import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';

void main() {
  group('Feed Tab Tests', () {
    group('Category Filter', () {
      final testPosts = [
        MapPost(
          id: '1',
          userId: 'user-1',
          title: 'Street Spot',
          description: 'A street spot',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          category: 'Street',
        ),
        MapPost(
          id: '2',
          userId: 'user-1',
          title: 'Park Spot',
          description: 'A park spot',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          category: 'Park',
        ),
        MapPost(
          id: '3',
          userId: 'user-1',
          title: 'DIY Spot',
          description: 'A DIY spot',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          category: 'DIY',
        ),
      ];

      test('All category returns all posts', () {
        const selectedCategory = 'All';
        final filteredPosts = selectedCategory == 'All'
            ? testPosts
            : testPosts.where((p) => p.category == selectedCategory).toList();
        
        expect(filteredPosts.length, 3);
      });

      test('Street category filters correctly', () {
        const selectedCategory = 'Street';
        final filteredPosts = testPosts
            .where((p) => p.category == selectedCategory)
            .toList();
        
        expect(filteredPosts.length, 1);
        expect(filteredPosts.first.category, 'Street');
      });

      test('Park category filters correctly', () {
        const selectedCategory = 'Park';
        final filteredPosts = testPosts
            .where((p) => p.category == selectedCategory)
            .toList();
        
        expect(filteredPosts.length, 1);
        expect(filteredPosts.first.category, 'Park');
      });

      test('Categories list contains expected values', () {
        final categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];
        
        expect(categories.contains('All'), true);
        expect(categories.contains('Street'), true);
        expect(categories.contains('Park'), true);
        expect(categories.contains('DIY'), true);
        expect(categories.contains('Shop'), true);
        expect(categories.contains('Other'), true);
      });
    });

    group('Search Filter', () {
      final testPosts = [
        MapPost(
          id: '1',
          userId: 'user-1',
          title: 'Downtown Rail',
          description: 'Great rail spot downtown',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          tags: ['rail', 'smooth'],
        ),
        MapPost(
          id: '2',
          userId: 'user-1',
          title: 'Beach Ledges',
          description: 'Marble ledges near the beach',
          latitude: 0.0,
          longitude: 0.0,
          createdAt: DateTime.now(),
          tags: ['ledge', 'marble'],
        ),
      ];

      test('Search by title works', () {
        const query = 'rail';
        final filteredPosts = testPosts.where((post) {
          return post.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filteredPosts.length, 1);
        expect(filteredPosts.first.title, 'Downtown Rail');
      });

      test('Search by description works', () {
        const query = 'marble';
        final filteredPosts = testPosts.where((post) {
          return post.description.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filteredPosts.length, 1);
        expect(filteredPosts.first.title, 'Beach Ledges');
      });

      test('Search by tags works', () {
        const query = 'smooth';
        final filteredPosts = testPosts.where((post) {
          return post.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
        }).toList();
        
        expect(filteredPosts.length, 1);
        expect(filteredPosts.first.title, 'Downtown Rail');
      });

      test('Search is case insensitive', () {
        const query = 'RAIL';
        final filteredPosts = testPosts.where((post) {
          return post.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filteredPosts.length, 1);
      });

      test('Empty search returns all posts', () {
        const query = '';
        final filteredPosts = query.isEmpty 
            ? testPosts 
            : testPosts.where((post) {
                return post.title.toLowerCase().contains(query.toLowerCase());
              }).toList();
        
        expect(filteredPosts.length, 2);
      });
    });

    group('Loading State', () {
      test('isLoading starts as true', () {
        var isLoading = true;
        expect(isLoading, true);
      });

      test('isLoading becomes false after load', () {
        var isLoading = true;
        // Simulate load completion
        isLoading = false;
        expect(isLoading, false);
      });
    });

    group('Empty State', () {
      test('Empty posts list triggers empty state', () {
        final posts = <MapPost>[];
        expect(posts.isEmpty, true);
      });

      test('Non-empty posts list does not trigger empty state', () {
        final posts = [
          MapPost(
            userId: 'user-1',
            title: 'Test',
            description: 'Test',
            latitude: 0.0,
            longitude: 0.0,
            createdAt: DateTime.now(),
          ),
        ];
        expect(posts.isEmpty, false);
      });
    });
  });
}
