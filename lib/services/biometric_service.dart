import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for fingerprint / face-id biometric authentication
class BiometricAuthService {
  static final _auth = LocalAuthentication();
  static const _enabledKey = 'biometrics_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Check if the device supports biometrics and has them enrolled
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricAuthService.isAvailable error: $e');
      return false;
    }
  }

  /// Returns the list of available biometric types (fingerprint, face, iris)
  static Future<List<BiometricType>> availableTypes() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Authenticate using biometrics. Returns true on success.
  /// [reason] is the message shown in the system dialog.
  static Future<bool> authenticate({
    String reason = 'Verify your identity to access your medical records',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('BiometricAuthService.authenticate error: $e');
      return false;
    }
  }

  /// Cancel any in-progress authentication
  static Future<void> stopAuthentication() async {
    if (kIsWeb) return;
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
