import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();
  StreamSubscription? _authSubscription;

  UserModel? _user;
  bool _loading = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _emailConfirmationRequired = false;

  UserModel? get user => _user;
  UserModel? get profile => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _service.isLoggedIn;
  bool get biometricAvailable => _biometricAvailable;
  bool get emailConfirmationRequired => _emailConfirmationRequired;
  String? get uid => _service.currentUser?.id;

  AuthProvider() {
    _authSubscription = _service.authStream?.listen((state) async {
      if (state.session == null) {
        _user = null;
      } else {
        await loadProfile();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

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
    final available = await BiometricAuthService.isAvailable();
    final enabled = await BiometricAuthService.isEnabled();
    _biometricAvailable = available && enabled && isLoggedIn;
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
      final response = await _service.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      _emailConfirmationRequired = response.session == null;
      if (!_emailConfirmationRequired) await loadProfile();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendVerificationEmail(String email) async {
    try {
      await _service.resendVerificationEmail(email);
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    }
  }

  Future<bool> updateEmail(String email) async {
    try {
      await _service.updateEmail(email);
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
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
      if (!isLoggedIn) {
        _error =
            'Sign in once with email and enable biometrics in Security settings.';
        notifyListeners();
        return false;
      }
      if (!await BiometricAuthService.isEnabled()) {
        _error = 'Biometric login is disabled in Security settings.';
        notifyListeners();
        return false;
      }
      if (!await BiometricAuthService.isAvailable()) {
        _error =
            'No enrolled fingerprint or biometric was found on this device.';
        notifyListeners();
        return false;
      }
      final ok = await BiometricAuthService.authenticate(
        reason: 'Verify your identity to access Medical History',
      );
      if (ok) {
        await loadProfile();
      } else {
        _error = 'Biometric authentication failed. Please try again.';
      }
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

  Future<bool> deleteAccount() async {
    try {
      await _service.deleteAccount();
      _user = null;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signOutEverywhere() async {
    try {
      await _service.signOutEverywhere();
      _user = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
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
    if (msg.contains('apiexception: 10') ||
        msg.contains('developer_error') ||
        msg.contains('configuration mismatch')) {
      return 'Google Sign-In configuration does not match this app build.';
    }
    if (msg.contains('supabase is not available') ||
        msg.contains('credentials are not configured')) {
      return 'Authentication service is not configured in this app build.';
    }
    if (msg.contains('invalid audience') || msg.contains('aud claim')) {
      return 'Google token was rejected because the OAuth client ID does not match.';
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
