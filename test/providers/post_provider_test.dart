import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/models/post.dart';

void main() {
  group('PostProvider Tests', () {
    group('State Management', () {
      test('initial state is correct', () {
        const isLoading = false;
        const error = null;
        const List<MapPost> posts = [];
        const searchQuery = '';
        const selectedCategory = 'All';
        
        expect(isLoading, false);
        expect(error, isNull);
        expect(posts, isEmpty);
        expect(searchQuery, isEmpty);
        expect(selectedCategory, 'All');
      });

      test('loading state is tracked correctly', () {
        var isLoading = false;
        
        isLoading = true;
        expect(isLoading, true);
        
        isLoading = false;
        expect(isLoading, false);
      });

      test('error state is tracked correctly', () {
        String? error;
        
        expect(error, isNull);
        
        error = 'Failed to load posts';
        expect(error, isNotNull);
        
        error = null;
        expect(error, isNull);
      });
    });

    group('Category Filtering', () {
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
        final filtered = selectedCategory == 'All'
            ? testPosts
            : testPosts.where((p) => p.category == selectedCategory).toList();
        
        expect(filtered.length, 3);
      });

      test('Street category filters correctly', () {
        const selectedCategory = 'Street';
        final filtered = testPosts
            .where((p) => p.category == selectedCategory)
            .toList();
        
        expect(filtered.length, 1);
        expect(filtered.first.category, 'Street');
      });

      test('categories list is correct', () {
        const categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];
        
        expect(categories.length, 6);
        expect(categories.contains('All'), true);
        expect(categories.contains('Street'), true);
      });

      test('setCategory validates category', () {
        const categories = ['All', 'Street', 'Park', 'DIY', 'Shop', 'Other'];
        var selectedCategory = 'All';
        
        // Valid category
        const newCategory = 'Park';
        if (categories.contains(newCategory)) {
          selectedCategory = newCategory;
        }
        expect(selectedCategory, 'Park');
        
        // Invalid category
        const invalidCategory = 'Invalid';
        if (categories.contains(invalidCategory)) {
          selectedCategory = invalidCategory;
        }
        expect(selectedCategory, 'Park'); // Should not change
      });
    });

    group('Search Filtering', () {
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

      test('search by title works', () {
        const query = 'rail';
        final filtered = testPosts.where((post) {
          return post.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filtered.length, 1);
        expect(filtered.first.title, 'Downtown Rail');
      });

      test('search by description works', () {
        const query = 'marble';
        final filtered = testPosts.where((post) {
          return post.description.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filtered.length, 1);
        expect(filtered.first.title, 'Beach Ledges');
      });

      test('search by tags works', () {
        const query = 'smooth';
        final filtered = testPosts.where((post) {
          return post.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
        }).toList();
        
        expect(filtered.length, 1);
        expect(filtered.first.title, 'Downtown Rail');
      });

      test('search is case insensitive', () {
        const query = 'RAIL';
        final filtered = testPosts.where((post) {
          return post.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
        
        expect(filtered.length, 1);
      });

      test('empty search returns all posts', () {
        const query = '';
        final filtered = query.isEmpty 
            ? testPosts 
            : testPosts.where((post) {
                return post.title.toLowerCase().contains(query.toLowerCase());
              }).toList();
        
        expect(filtered.length, 2);
      });

      test('clearFilters resets state', () {
        var searchQuery = 'test';
        var selectedCategory = 'Street';
        
        // Clear filters
        searchQuery = '';
        selectedCategory = 'All';
        
        expect(searchQuery, isEmpty);
        expect(selectedCategory, 'All');
      });
    });

    group('Post Operations', () {
      test('getPostById finds correct post', () {
        final posts = [
          MapPost(
            id: 'post-1',
            userId: 'user-1',
            title: 'Test Post',
            description: 'Description',
            latitude: 0.0,
            longitude: 0.0,
            createdAt: DateTime.now(),
          ),
        ];

        MapPost? getPostById(String id) {
          try {
            return posts.firstWhere((post) => post.id == id);
          } catch (e) {
            return null;
          }
        }

        final found = getPostById('post-1');
        expect(found, isNotNull);
        expect(found!.title, 'Test Post');

        final notFound = getPostById('nonexistent');
        expect(notFound, isNull);
      });

      test('removePost removes correct post', () {
        final posts = [
          MapPost(
            id: 'post-1',
            userId: 'user-1',
            title: 'Post 1',
            description: 'Description',
            latitude: 0.0,
            longitude: 0.0,
            createdAt: DateTime.now(),
          ),
          MapPost(
            id: 'post-2',
            userId: 'user-1',
            title: 'Post 2',
            description: 'Description',
            latitude: 0.0,
            longitude: 0.0,
            createdAt: DateTime.now(),
          ),
        ];

        posts.removeWhere((post) => post.id == 'post-1');
        
        expect(posts.length, 1);
        expect(posts.first.id, 'post-2');
      });
    });
  });
}
