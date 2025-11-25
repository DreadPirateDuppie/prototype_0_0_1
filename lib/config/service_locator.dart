import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/points_service.dart';
import '../services/admin_service.dart';

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
}

/// Set up the service locator for testing with mock dependencies.
/// [mockSupabaseClient] - optional mock Supabase client for testing
void setupServiceLocatorForTesting({SupabaseClient? mockSupabaseClient}) {
  // Reset any existing registrations
  if (getIt.isRegistered<SupabaseClient>()) {
    getIt.unregister<SupabaseClient>();
  }
  if (getIt.isRegistered<PostService>()) {
    getIt.unregister<PostService>();
  }
  if (getIt.isRegistered<UserService>()) {
    getIt.unregister<UserService>();
  }
  if (getIt.isRegistered<PointsService>()) {
    getIt.unregister<PointsService>();
  }
  if (getIt.isRegistered<AdminService>()) {
    getIt.unregister<AdminService>();
  }

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
}

/// Reset the service locator (useful for testing cleanup)
Future<void> resetServiceLocator() async {
  await getIt.reset();
}
