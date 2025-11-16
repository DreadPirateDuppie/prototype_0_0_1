# Refactoring Examples: Before & After

This document provides concrete examples of how duplicate and redundant code can be refactored.

---

## Example 1: User Avatar Widget

### ❌ BEFORE (Duplicated 4 times)

**Location:** `feed_tab.dart`, `profile_tab.dart`, `spot_details_bottom_sheet.dart`

```dart
CircleAvatar(
  radius: 20,
  backgroundColor: Colors.deepPurple,
  child: Text(
    (post.userName?.isNotEmpty ?? false)
        ? post.userName![0].toUpperCase()
        : (post.userEmail?.isNotEmpty ?? false)
            ? post.userEmail![0].toUpperCase()
            : '?',
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  ),
)
```

### ✅ AFTER (Create reusable widget)

**New file:** `lib/widgets/user_avatar.dart`

```dart
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final double radius;
  final double fontSize;

  const UserAvatar({
    super.key,
    this.userName,
    this.userEmail,
    this.radius = 20,
    this.fontSize = 16,
  });

  String get _initial {
    if (userName?.isNotEmpty ?? false) {
      return userName![0].toUpperCase();
    }
    if (userEmail?.isNotEmpty ?? false) {
      return userEmail![0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
```

**Usage in `feed_tab.dart`:**
```dart
UserAvatar(
  userName: post.userName,
  userEmail: post.userEmail,
  radius: 20,
)
```

**Benefits:**
- Single source of truth for avatar logic
- Consistent behavior across app
- Easy to modify appearance everywhere
- Uses theme colors instead of hardcoded

---

## Example 2: Loading Button Widget

### ❌ BEFORE (Duplicated 6 times)

**Location:** All dialog files and auth screens

```dart
ElevatedButton(
  onPressed: _isLoading ? null : _submitAction,
  child: _isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Submit'),
)
```

### ✅ AFTER (Create reusable widget)

**New file:** `lib/widgets/loading_button.dart`

```dart
import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;

  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon),
            label: _buildChild(),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: _buildChild(),
          );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return Text(label);
  }
}
```

**Usage:**
```dart
LoadingButton(
  label: 'Submit',
  onPressed: _submitAction,
  isLoading: _isLoading,
  icon: Icons.save,
)
```

---

## Example 3: Network Image with Fallback

### ❌ BEFORE (Duplicated 4 times)

```dart
if (post.photoUrl != null) ...[
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      post.photoUrl!,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 200,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported),
          ),
        );
      },
    ),
  ),
  const SizedBox(height: 12),
],
```

### ✅ AFTER (Create reusable widget)

**New file:** `lib/widgets/network_image_with_fallback.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const NetworkImageWithFallback({
    super.key,
    this.imageUrl,
    this.height = 200,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        height: height,
        width: double.infinity,
        fit: fit,
        placeholder: (context, url) => Container(
          height: height,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 48,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
```

**Usage:**
```dart
NetworkImageWithFallback(
  imageUrl: post.photoUrl,
  height: 200,
),
const SizedBox(height: 12),
```

**Benefits:**
- Includes caching (using existing dependency)
- Consistent error handling
- Loading placeholder
- Cleaner code

---

## Example 4: Constants File

### ❌ BEFORE (Scattered throughout codebase)

```dart
// In various files:
const SizedBox(height: 8)
const SizedBox(height: 12)
const SizedBox(height: 16)
const SizedBox(height: 24)

Colors.deepPurple
'Unknown User'
'Coming soon!'
```

### ✅ AFTER (Centralized constants)

**New file:** `lib/constants/app_constants.dart`

```dart
import 'package:flutter/material.dart';

/// Spacing constants for consistent layout
class Spacing {
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Convenience methods
  static SizedBox vertical(double height) => SizedBox(height: height);
  static SizedBox horizontal(double width) => SizedBox(width: width);
  
  static const vXS = SizedBox(height: xs);
  static const vSmall = SizedBox(height: small);
  static const vMedium = SizedBox(height: medium);
  static const vLarge = SizedBox(height: large);
  static const vXL = SizedBox(height: xl);
  
  static const hSmall = SizedBox(width: small);
  static const hMedium = SizedBox(width: medium);
  static const hLarge = SizedBox(width: large);
}

/// Border radius constants
class Radii {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double circular = 20.0;
}

/// String constants
class Strings {
  // User related
  static const unknownUser = 'Unknown User';
  static const notAvailable = 'Not available';
  
  // UI Messages
  static const comingSoon = 'Coming soon!';
  static const loading = 'Loading...';
  static const noConnection = 'No internet connection';
  
  // Error messages
  static const errorGeneric = 'An error occurred';
  static const errorLoading = 'Error loading data';
  static const errorCreatingPost = 'Error creating post';
  static const errorUpdatingPost = 'Error updating post';
  static const errorDeletingPost = 'Error deleting post';
  static const errorPickingImage = 'Error picking image';
  
  // Validation messages
  static const fieldRequired = 'This field is required';
  static const emailInvalid = 'Please enter a valid email';
  static const passwordsNoMatch = 'Passwords do not match';
}

/// Icon size constants
class IconSizes {
  static const double small = 16.0;
  static const double medium = 20.0;
  static const double large = 24.0;
  static const double xl = 32.0;
}
```

**Usage:**
```dart
// Instead of: const SizedBox(height: 16)
Spacing.vLarge

// Instead of: 'Unknown User'
Strings.unknownUser

// Instead of: BorderRadius.circular(8)
BorderRadius.circular(Radii.small)
```

---

## Example 5: Validation Utilities

### ❌ BEFORE (Duplicated validation)

```dart
// In multiple files:
if (_titleController.text.trim().isEmpty || 
    _descriptionController.text.trim().isEmpty) {
  // show error
}

if (username.isEmpty) {
  setState(() {
    _errorMessage = 'Username cannot be empty';
  });
  return;
}
```

### ✅ AFTER (Centralized validation)

**New file:** `lib/utils/validators.dart`

```dart
class Validators {
  /// Validates that a string is not empty
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validates email format
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validates username format
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 20) {
      return 'Username must be 20 characters or less';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, dashes, and underscores';
    }
    return null;
  }

  /// Validates password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates that two passwords match
  static String? passwordMatch(String? value, String? matchValue) {
    if (value != matchValue) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates minimum length
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.length < min) {
      return '${fieldName ?? 'This field'} must be at least $min characters';
    }
    return null;
  }

  /// Validates maximum length
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value != null && value.length > max) {
      return '${fieldName ?? 'This field'} must be $max characters or less';
    }
    return null;
  }
}
```

**Usage:**
```dart
TextField(
  controller: _emailController,
  decoration: InputDecoration(
    labelText: 'Email',
    errorText: Validators.email(_emailController.text),
  ),
)

// Or in form validation:
String? error = Validators.required(_titleController.text, fieldName: 'Title');
if (error != null) {
  setState(() => _errorMessage = error);
  return;
}
```

---

## Example 6: Environment Configuration

### ❌ BEFORE (Hardcoded credentials)

**Location:** `lib/main.dart`

```dart
await Supabase.initialize(
  url: 'https://vgcdednbyjdkyjysvctm.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
);
```

### ✅ AFTER (Environment variables)

**New file:** `.env` (in project root, add to .gitignore)

```env
SUPABASE_URL=https://vgcdednbyjdkyjysvctm.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Update:** `.gitignore`

```gitignore
# Add to existing .gitignore
.env
*.env
```

**New file:** `lib/config/environment.dart`

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }
}
```

**Update:** `lib/main.dart`

```dart
import 'config/environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await Environment.load();
  
  ErrorService.initialize();
  
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );
  
  await ConnectivityService.initialize();
  
  runApp(/* ... */);
}
```

**Update:** `pubspec.yaml` (add to assets)

```yaml
flutter:
  assets:
    - .env
```

---

## Example 7: Split God Object

### ❌ BEFORE (God Object)

**Location:** `lib/services/supabase_service.dart` (352 lines, 30+ methods)

```dart
class SupabaseService {
  // Auth methods
  static Future<AuthResponse> signUp(...) {}
  static Future<AuthResponse> signIn(...) {}
  static Future<void> signOut() {}
  
  // Profile methods
  static Future<String?> getUserDisplayName(...) {}
  static Future<void> saveUserDisplayName(...) {}
  
  // Post methods
  static Future<MapPost?> createMapPost(...) {}
  static Future<List<MapPost>> getAllMapPosts() {}
  static Future<void> deleteMapPost(...) {}
  
  // Rating methods
  static Future<void> rateMapPost(...) {}
  static Future<void> likeMapPost(...) {}
  
  // Moderation methods
  static Future<void> reportPost(...) {}
  static Future<List<Map>> getReportedPosts() {}
  
  // Upload methods
  static Future<String> uploadPostImage(...) {}
}
```

### ✅ AFTER (Separated services)

**New file:** `lib/services/auth_service.dart`

```dart
class AuthService {
  final SupabaseClient _client;
  
  AuthService(this._client);
  
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }
  
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(OAuthProvider.google);
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
```

**New file:** `lib/services/user_profile_service.dart`

```dart
class UserProfileService {
  final SupabaseClient _client;
  
  UserProfileService(this._client);
  
  Future<String?> getDisplayName(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      return response?['display_name'];
    } catch (e) {
      return null;
    }
  }
  
  Future<String?> getUsername(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      return response?['username'];
    } catch (e) {
      return null;
    }
  }
  
  Future<void> saveDisplayName(String userId, String displayName) async {
    await _client.from('user_profiles').upsert({
      'id': userId,
      'display_name': displayName,
    });
  }
  
  Future<void> saveUsername(String userId, String username) async {
    await _client.from('user_profiles').upsert({
      'id': userId,
      'username': username.toLowerCase().trim(),
    });
  }
  
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('username', username);
      return (response as List).isEmpty;
    } catch (e) {
      return true;
    }
  }
}
```

**New file:** `lib/services/post_service.dart`

```dart
class PostService {
  final SupabaseClient _client;
  
  PostService(this._client);
  
  Future<MapPost?> createPost({
    required String userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    String? photoUrl,
    String? userName,
    String? userEmail,
  }) async {
    final response = await _client.from('map_posts').insert({
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
      'likes': 0,
      'photo_url': photoUrl,
    }).select().single();

    return MapPost.fromMap(response);
  }
  
  Future<List<MapPost>> getAllPosts() async {
    final response = await _client
        .from('map_posts')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((post) => MapPost.fromMap(post)).toList();
  }
  
  Future<List<MapPost>> getUserPosts(String userId) async {
    final response = await _client
        .from('map_posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((post) => MapPost.fromMap(post)).toList();
  }
  
  Future<void> deletePost(String postId) async {
    await _client.from('map_posts').delete().eq('id', postId);
  }
  
  Future<MapPost?> updatePost({
    required String postId,
    required String title,
    required String description,
    String? photoUrl,
  }) async {
    final updateData = {
      'title': title,
      'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
    };

    final response = await _client
        .from('map_posts')
        .update(updateData)
        .eq('id', postId)
        .select()
        .single();

    return MapPost.fromMap(response);
  }
  
  Future<void> likePost(String postId, int currentLikes) async {
    await _client
        .from('map_posts')
        .update({'likes': currentLikes + 1})
        .eq('id', postId);
  }
  
  Future<void> ratePost({
    required String postId,
    required double popularityRating,
    required double securityRating,
    required double qualityRating,
  }) async {
    await _client.from('map_posts').update({
      'popularity_rating': popularityRating,
      'security_rating': securityRating,
      'quality_rating': qualityRating,
    }).eq('id', postId);
  }
}
```

**New file:** `lib/services/storage_service.dart`

```dart
class StorageService {
  final SupabaseClient _client;
  
  StorageService(this._client);
  
  Future<String> uploadImage(File imageFile, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'post_${userId}_$timestamp.jpg';
    
    final bytes = await imageFile.readAsBytes();
    await _client.storage.from('post_images').uploadBinary(
      filename,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );

    return _client.storage.from('post_images').getPublicUrl(filename);
  }
}
```

**New file:** `lib/services/moderation_service.dart`

```dart
class ModerationService {
  final SupabaseClient _client;
  
  ModerationService(this._client);
  
  Future<void> reportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
    String? details,
  }) async {
    await _client.from('post_reports').insert({
      'post_id': postId,
      'reporter_user_id': reporterUserId,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  Future<List<Map<String, dynamic>>> getReportedPosts() async {
    final response = await _client
        .from('post_reports')
        .select('*, map_posts(*)')
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }
}
```

**New file:** `lib/services/service_locator.dart` (Dependency Injection)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();
  
  late final SupabaseClient _client;
  
  // Services
  late final AuthService auth;
  late final UserProfileService userProfile;
  late final PostService post;
  late final StorageService storage;
  late final ModerationService moderation;
  
  void initialize() {
    _client = Supabase.instance.client;
    
    auth = AuthService(_client);
    userProfile = UserProfileService(_client);
    post = PostService(_client);
    storage = StorageService(_client);
    moderation = ModerationService(_client);
  }
}

// Global accessor
final services = ServiceLocator();
```

**Usage:**
```dart
// In main.dart, after Supabase.initialize()
services.initialize();

// In your widgets:
final user = services.auth.currentUser;
final posts = await services.post.getAllPosts();
await services.post.likePost(postId, likes);
```

---

## Summary of Benefits

| Refactoring | Lines Saved | Maintainability | Testability |
|-------------|-------------|-----------------|-------------|
| UserAvatar widget | ~60 lines | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| LoadingButton widget | ~100 lines | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| NetworkImage widget | ~80 lines | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Constants file | ~200 lines | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Validators | ~50 lines | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Environment config | Security++ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Split services | -50 lines | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Total estimated reduction:** ~500-600 lines of code  
**Overall code quality improvement:** From C+ (6.5/10) to A- (8.5/10)

---

**Note:** These are suggested refactorings. Test thoroughly after implementing each change!
