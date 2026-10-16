import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import 'mock_data_service.dart';

class AuthService {
  final _mock = MockDataService();

  User? get currentUser =>
      SupabaseConfig.isInitialized ? SupabaseConfig.auth?.currentUser : null;

  bool get isLoggedIn =>
      SupabaseConfig.isInitialized ? currentUser != null : (_mock.currentUser != null);

  Stream<AuthState>? get authStream =>
      SupabaseConfig.isInitialized ? SupabaseConfig.auth?.onAuthStateChange : null;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.auth != null) {
      final res = await SupabaseConfig.auth!.signUp(email: email, password: password);
      if (res.user != null) {
        await SupabaseConfig.db!.from('profiles').insert({
          'id': res.user!.id,
          'email': email,
          'full_name': fullName,
        });
      }
    } else {
      _mock.currentUser = UserModel(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: fullName,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.auth != null) {
      await SupabaseConfig.auth!.signInWithPassword(email: email, password: password);
    } else {
      _mock.currentUser = UserModel(
        id: 'usr-100',
        email: email,
        fullName: 'Ahmed Khan',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      );
    }
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.auth != null) {
      await SupabaseConfig.auth!.signOut();
    } else {
      _mock.currentUser = null;
    }
  }

  Future<void> resetPassword(String email) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.auth != null) {
      await SupabaseConfig.auth!.resetPasswordForEmail(email);
    }
  }

  Future<UserModel?> getProfile() async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final uid = currentUser?.id;
      if (uid == null) return null;
      final data = await SupabaseConfig.db!.from('profiles').select().eq('id', uid).single();
      return UserModel.fromMap(data);
    }
    return _mock.currentUser;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final uid = currentUser?.id;
      if (uid == null) return;
      await SupabaseConfig.db!.from('profiles').update(updates).eq('id', uid);
    } else if (_mock.currentUser != null) {
      final cur = _mock.currentUser!;
      _mock.currentUser = UserModel(
        id: cur.id,
        email: updates['email'] ?? cur.email,
        fullName: updates['full_name'] ?? cur.fullName,
        phone: updates['phone'] ?? cur.phone,
        avatarUrl: updates['avatar_url'] ?? cur.avatarUrl,
        createdAt: cur.createdAt,
      );
    }
  }
}

