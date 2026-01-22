import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/points_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../services/location_service.dart';
import '../services/trick_service.dart';

import '../services/ghost_line_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Set up the service locator with production dependencies.
/// Call this in main() after Supabase/Firebase initialization.
void setupServiceLocator() {
  // Register Supabase client
  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Register services
  getIt.registerLazySingleton<PostService>(
    () => PostService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<UserService>(
    () => UserService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<PointsService>(
    () => PointsService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<AdminService>(
    () => AdminService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<AuthService>(
    () => AuthService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<SocialService>(
    () => SocialService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<LocationService>(
    () => LocationService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<TrickService>(
    () => TrickService(client: getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<GhostLineService>(
    () => GhostLineService(client: getIt<SupabaseClient>()),
  );
}

/// Set up the service locator for testing with mock dependencies.
/// [mockSupabaseClient] - optional mock Supabase client for testing
Future<void> setupServiceLocatorForTesting({SupabaseClient? mockSupabaseClient}) async {
  // Reset all registrations to start fresh
  await getIt.reset();

  // Register mock client if provided
  if (mockSupabaseClient != null) {
    getIt.registerSingleton<SupabaseClient>(mockSupabaseClient);
  }

  // Register services with optional mock client
  getIt.registerLazySingleton<PostService>(
    () => PostService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<UserService>(
    () => UserService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<PointsService>(
    () => PointsService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<AdminService>(
    () => AdminService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<AuthService>(
    () => AuthService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<SocialService>(
    () => SocialService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<LocationService>(
    () => LocationService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<TrickService>(
    () => TrickService(client: mockSupabaseClient),
  );

  getIt.registerLazySingleton<GhostLineService>(
    () => GhostLineService(client: mockSupabaseClient),
  );
}

/// Reset the service locator (useful for testing cleanup)
Future<void> resetServiceLocator() async {
  await getIt.reset();
}
