import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../utils/logger.dart';
import 'dart:async' as async;
import 'error_types.dart';
import '../config/service_locator.dart';

/// Service responsible for authentication operations
class AuthService {
  final SupabaseClient? _injectedClient;

  AuthService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) {
      return injected;
    }
    if (getIt.isRegistered<SupabaseClient>()) {
      return getIt<SupabaseClient>();
    }
    return Supabase.instance.client;
  }

  /// Get current user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? displayName,
    String? username,
    int? age,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final profileData = <String, dynamic>{'id': userId};
        
        if (username != null) {
          profileData['username'] = username.toLowerCase().trim();
          profileData['display_name'] = username.trim();
        } else if (displayName != null) {
          profileData['display_name'] = displayName.trim();
        }
        
        if (age != null) {
          profileData['age'] = age;
        }

        if (profileData.length > 1) {
          await _client.from('user_profiles').upsert(profileData);
        }
      }

      return response;
    } catch (e) {
      AppLogger.log('Sign up failed: $e', name: 'AuthService');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AppAuthException(
        'Authentication failed: ${e.message}',
        userMessage: 'Invalid email or password. Please try again.',
        originalError: e,
      );
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error during sign in',
        originalError: e,
      );
    } on async.TimeoutException catch (e) {
      throw AppTimeoutException(
        'Sign in request timed out',
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        'Sign in failed: $e',
        userMessage: 'Unable to sign in. Please check your credentials.',
        originalError: e,
      );
    }
  }

  /// Sign in with Google via Supabase
  Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(OAuthProvider.google);
    } on SocketException catch (e) {
      throw AppNetworkException(
        'Network error during Google sign in',
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        'Google Sign-In failed: $e',
        userMessage: 'Unable to sign in with Google. Please try again.',
        originalError: e,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  /// Delete current user account
  /// This calls the secure RPC function delete_user_account
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_user_account');
      await signOut(); // Sign out locally after deletion
    } catch (e) {
      AppLogger.log('Account deletion failed: $e', name: 'AuthService');
      throw Exception('Failed to delete account. Please try again later.');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  /// Update user's last active timestamp
  Future<void> updateLastActive() async {
    final user = getCurrentUser();
    if (user == null) return;
    
    try {
      await _client.from('user_profiles').update({
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      AppLogger.log('Failed to update last active: $e', name: 'AuthService');
    }
  }
}
