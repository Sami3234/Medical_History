import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service for Google OAuth sign-in via Supabase
class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Sign in with Google. Returns [AuthResponse] on success or throws.
  static Future<AuthResponse?> signInWithGoogle() async {
    if (!SupabaseConfig.isInitialized) {
      throw Exception('Supabase is not initialized. Cannot use Google sign-in.');
    }

    try {
      // Trigger the Google sign-in flow
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID token.');
      }

      // Pass Google tokens to Supabase
      final response = await SupabaseConfig.auth!.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Ensure profile row exists for new users
      if (response.user != null) {
        final uid = response.user!.id;
        final existing = await SupabaseConfig.db!
            .from('profiles')
            .select('id')
            .eq('id', uid)
            .maybeSingle();

        if (existing == null) {
          await SupabaseConfig.db!.from('profiles').insert({
            'id': uid,
            'email': googleUser.email,
            'full_name': googleUser.displayName ?? googleUser.email.split('@').first,
            'avatar_url': googleUser.photoUrl,
          });
        }
      }

      return response;
    } catch (e) {
      debugPrint('GoogleAuthService.signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Supabase
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    if (SupabaseConfig.isInitialized) {
      await SupabaseConfig.auth?.signOut();
    }
  }
}
