import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  UserModel? _user;
  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;

  UserModel? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _service.isLoggedIn;
  bool get biometricAvailable => _biometricAvailable;
  String? get uid => _service.currentUser?.id;

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check biometric availability on startup
  Future<void> checkBiometrics() async {
    _biometricAvailable = await BiometricAuthService.isAvailable();
    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _setLoading(true);
      _error = null;
      await _service.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      await loadProfile();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _setLoading(true);
      _error = null;
      await _service.signIn(email: email, password: password);
      await loadProfile();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Google Sign-In via Supabase OAuth
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _error = null;
      final result = await GoogleAuthService.signInWithGoogle();
      if (result == null) {
        _error = null; // user cancelled – not an error
        return false;
      }
      await loadProfile();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Biometric authentication (fingerprint / face-id)
  Future<bool> authenticateWithBiometrics() async {
    try {
      _error = null;
      final ok = await BiometricAuthService.authenticate(
        reason: 'Verify your identity to access Medical History',
      );
      if (!ok) _error = 'Biometric authentication failed. Please try again.';
      notifyListeners();
      return ok;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleAuthService.signOut();
    } catch (_) {
      await _service.signOut();
    }
    _user = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _error = null;
      await _service.resetPassword(email);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProfile() async {
    try {
      _user = await _service.getProfile();
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      await _service.updateProfile(updates);
      await loadProfile();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid credentials') ||
        msg.contains('invalid_grant') ||
        msg.contains('invalid username or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email already') || msg.contains('user_already_exists')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (msg.contains('network') ||
        msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('authretryablefetchexception') ||
        msg.contains('no address associated') ||
        msg.contains('connection refused') ||
        msg.contains('unreachable') ||
        msg.contains('timed out')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
    if (msg.contains('cancelled') || msg.contains('user cancelled')) {
      return 'Sign-in was cancelled.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address to continue.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Authentication failed. Please verify your details and try again.';
  }
}
