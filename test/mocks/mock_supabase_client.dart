import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePostgrestTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final T _result;
  FakePostgrestTransformBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) async {
    return onValue(_result);
  }
}

/// Mock classes for Supabase client components
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}

/// Helper class to build mock Supabase client configurations
class MockSupabaseBuilder {
  /// Creates a basic mock SupabaseClient with common operations stubbed
  static MockSupabaseClient createMock({
    User? currentUser,
    Session? currentSession,
    List<Map<String, dynamic>>? selectResult,
    Map<String, dynamic>? singleResult,
    Exception? throwError,
  }) {
    final mockClient = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    final mockStorage = MockSupabaseStorageClient();

    // Setup auth
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(currentUser);
    when(() => mockAuth.currentSession).thenReturn(currentSession);

    // Setup storage
    when(() => mockClient.storage).thenReturn(mockStorage);

    return mockClient;
  }

  /// Creates a mock user
  static User createMockUser({
    String id = 'test-user-id',
    String email = 'test@example.com',
    Map<String, dynamic>? userMetadata,
  }) {
    final mockUser = MockUser();
    when(() => mockUser.id).thenReturn(id);
    when(() => mockUser.email).thenReturn(email);
    when(() => mockUser.userMetadata).thenReturn(userMetadata ?? {});
    return mockUser;
  }

  /// Creates a mock session
  static Session createMockSession({
    String accessToken = 'mock-access-token',
    String refreshToken = 'mock-refresh-token',
    User? user,
  }) {
    final mockSession = MockSession();
    when(() => mockSession.accessToken).thenReturn(accessToken);
    when(() => mockSession.refreshToken).thenReturn(refreshToken);
    if (user != null) {
      when(() => mockSession.user).thenReturn(user);
    }
    return mockSession;
  }

  /// Helper to setup a successful select query that returns a list
  static void setupSelectQuery(
    MockSupabaseClient client,
    String tableName,
    List<Map<String, dynamic>> results,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockFilterBuilder = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.select(any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.eq(any(), any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.order(any(), ascending: any(named: 'ascending')))
        .thenReturn(FakePostgrestTransformBuilder(results));
  }

  /// Helper to setup a select query that returns a single result
  static void setupSelectSingle(
    MockSupabaseClient client,
    String tableName,
    Map<String, dynamic>? result,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockFilterBuilder = MockPostgrestFilterBuilder<PostgrestList>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.select(any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.eq(any(), any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.maybeSingle()).thenReturn(FakePostgrestTransformBuilder(result));
  }

  /// Helper to setup an insert query
  static void setupInsertQuery(
    MockSupabaseClient client,
    String tableName,
    Map<String, dynamic> returnedData,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockListFilterBuilder = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.insert(any())).thenReturn(mockListFilterBuilder);
    when(() => mockListFilterBuilder.select()).thenReturn(mockListFilterBuilder);
    when(() => mockListFilterBuilder.single()).thenReturn(FakePostgrestTransformBuilder(returnedData));
  }

  /// Helper to setup an update query
  static void setupUpdateQuery(
    MockSupabaseClient client,
    String tableName,
    Map<String, dynamic>? returnedData,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockListFilterBuilder = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.update(any())).thenReturn(mockListFilterBuilder);
    when(() => mockListFilterBuilder.eq(any(), any())).thenReturn(mockListFilterBuilder);
    if (returnedData != null) {
      when(() => mockListFilterBuilder.select()).thenReturn(mockListFilterBuilder);
      when(() => mockListFilterBuilder.single()).thenReturn(FakePostgrestTransformBuilder(returnedData));
    }
  }

  /// Helper to setup a delete query
  static void setupDeleteQuery(
    MockSupabaseClient client,
    String tableName,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockListFilterBuilder = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.delete()).thenReturn(mockListFilterBuilder);
    when(() => mockListFilterBuilder.eq(any(), any())).thenReturn(mockListFilterBuilder);
  }

  /// Helper to setup an upsert query
  static void setupUpsertQuery(
    MockSupabaseClient client,
    String tableName,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    final mockFilterBuilder = MockPostgrestFilterBuilder<void>();

    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.upsert(any(), onConflict: any(named: 'onConflict')))
        .thenReturn(mockFilterBuilder);
  }

  /// Helper to setup an error response
  static void setupErrorQuery(
    MockSupabaseClient client,
    String tableName,
    Exception error,
  ) {
    final mockQueryBuilder = MockSupabaseQueryBuilder();
    
    when(() => client.from(tableName)).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.select(any())).thenThrow(error);
    when(() => mockQueryBuilder.insert(any())).thenThrow(error);
    when(() => mockQueryBuilder.update(any())).thenThrow(error);
    when(() => mockQueryBuilder.delete()).thenThrow(error);
  }
}
