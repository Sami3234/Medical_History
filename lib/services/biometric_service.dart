import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for fingerprint / face-id biometric authentication
class BiometricAuthService {
  static final _auth = LocalAuthentication();

  /// Check if the device supports biometrics and has them enrolled
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('BiometricAuthService.isAvailable error: $e');
      return false;
    }
  }

  /// Returns the list of available biometric types (fingerprint, face, iris)
  static Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Authenticate using biometrics. Returns true on success.
  /// [reason] is the message shown in the system dialog.
  static Future<bool> authenticate({
    String reason = 'Verify your identity to access your medical records',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('BiometricAuthService.authenticate error: $e');
      return false;
    }
  }

  /// Cancel any in-progress authentication
  static Future<void> stopAuthentication() async {
    await _auth.stopAuthentication();
  }
}
