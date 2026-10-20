import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  User? get currentUser =>
      SupabaseConfig.isInitialized ? SupabaseConfig.auth?.currentUser : null;

  bool get isLoggedIn => currentUser != null;

  Stream<AuthState>? get authStream => SupabaseConfig.isInitialized
      ? SupabaseConfig.auth?.onAuthStateChange
      : null;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final auth = _requireAuth();
    return auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> resendVerificationEmail(String email) async {
    await _requireAuth().resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> updateEmail(String email) async {
    await _requireAuth().updateUser(UserAttributes(email: email.trim()));
  }

  Future<void> signIn({required String email, required String password}) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthException('Invalid login credentials');
    }
    final response = await _requireAuth().signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user == null || response.session == null) {
      throw const AuthException('Invalid login credentials');
    }
  }

  Future<void> signOut() async {
    await _requireAuth().signOut();
  }

  Future<void> signOutEverywhere() async {
    await _requireAuth().signOut(scope: SignOutScope.global);
  }

  Future<void> deleteAccount() async {
    final client = SupabaseConfig.db;
    if (client == null || currentUser == null) {
      throw StateError('Authentication service is not available.');
    }
    await client.rpc('delete_my_account');
    await _requireAuth().signOut();
  }

  Future<void> resetPassword(String email) async {
    await _requireAuth().resetPasswordForEmail(email);
  }

  Future<UserModel?> getProfile() async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final uid = currentUser?.id;
      if (uid == null) return null;
      final data = await SupabaseConfig.db!
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data != null) {
        return UserModel.fromMap(data);
      }

      // Auto-create profile record if it doesn't exist yet
      try {
        final email = currentUser?.email ?? '';
        final nameMeta = currentUser?.userMetadata?['full_name'] as String?;
        final defaultName = (nameMeta != null && nameMeta.isNotEmpty)
            ? nameMeta
            : (email.isNotEmpty ? email.split('@').first : 'User');
        final newProfile = {
          'id': uid,
          'email': email,
          'full_name': defaultName,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await SupabaseConfig.db!.from('profiles').insert(newProfile);
        return UserModel.fromMap(newProfile);
      } catch (e) {
        debugPrint('Auto-create profile note: $e');
      }
    }
    return null;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final uid = currentUser?.id;
      if (uid == null) return;
      final currentProfile = await SupabaseConfig.db!
          .from('profiles')
          .select('full_name')
          .eq('id', uid)
          .maybeSingle();
      final previousName = (currentProfile?['full_name'] as String?)?.trim();
      final profileUpdates = Map<String, dynamic>.from(updates)
        ..['updated_at'] = DateTime.now().toIso8601String();
      await SupabaseConfig.db!
          .from('profiles')
          .update(profileUpdates)
          .eq('id', uid);

      final ownerUpdates = <String, dynamic>{};
      if (updates.containsKey('full_name')) {
        ownerUpdates['name'] = updates['full_name'];
      }
      if (updates.containsKey('avatar_url')) {
        ownerUpdates['avatar_url'] = updates['avatar_url'];
      }
      if (ownerUpdates.isNotEmpty) {
        await SupabaseConfig.db!
            .from('members')
            .update(ownerUpdates)
            .ilike('relation', 'self');
      }
      final updatedName = (updates['full_name'] as String?)?.trim();
      if (updatedName != null &&
          updatedName.isNotEmpty &&
          previousName != null &&
          previousName.isNotEmpty &&
          updatedName != previousName) {
        final families = await SupabaseConfig.db!
            .from('families')
            .select('id, name')
            .eq('user_id', uid);
        for (final family in families) {
          final familyName = (family['name'] as String?)?.trim().toLowerCase();
          final oldName = previousName.toLowerCase();
          if (familyName == oldName || familyName == '$oldName family') {
            await SupabaseConfig.db!
                .from('families')
                .update({'name': '$updatedName Family'})
                .eq('id', family['id'] as String);
          }
        }
      }
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  GoTrueClient _requireAuth() {
    final auth = SupabaseConfig.auth;
    if (!SupabaseConfig.isInitialized || auth == null) {
      throw StateError('Supabase is not available. Please try again later.');
    }
    return auth;
  }
}
