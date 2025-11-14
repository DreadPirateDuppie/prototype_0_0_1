import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Get current user session
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // Get current session
  static Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  // Get user display name
  static Future<String?> getUserDisplayName(String userId) async {
    final response = await _client
        .from('user_profiles')
        .select('display_name')
        .eq('id', userId)
        .maybeSingle();
    return response?['display_name'];
  }

  // Save user display name
  static Future<void> saveUserDisplayName(
    String userId,
    String displayName,
  ) async {
    await _client.from('user_profiles').upsert({
      'id': userId,
      'display_name': displayName,
    });
  }

  // Sign up with email and password
  static Future<AuthResponse> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (displayName != null && response.user != null) {
      await saveUserDisplayName(response.user!.id, displayName);
    }

    return response;
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with Google via Supabase
  static Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Listen to auth state changes
  static Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }
}



