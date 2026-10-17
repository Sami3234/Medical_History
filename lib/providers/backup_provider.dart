import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';

class BackupProvider extends ChangeNotifier {
  final BackupService _service = BackupService();

  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingInfo = false;
  DriveBackupMetadata? _backupMetadata;
  String? _error;
  String _autoBackupFrequency = 'Daily';

  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get isLoadingInfo => _isLoadingInfo;
  bool get isConnected => _service.isConnected;
  GoogleSignInAccount? get currentUser => _service.currentUser;
  DriveBackupMetadata? get backupMetadata => _backupMetadata;
  String? get error => _error;
  String get autoBackupFrequency => _autoBackupFrequency;

  BackupProvider() {
    init();
  }

  Future<void> init() async {
    _isLoadingInfo = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoBackupFrequency = prefs.getString('auto_backup_frequency') ?? 'Daily';

      // Silent sign-in if already logged in
      final account = await _service.signInSilently();
      if (account != null) {
        _backupMetadata = await _service.getLatestBackupInfo();
      }
    } catch (_) {
      // Ignored on initial launch
    } finally {
      _isLoadingInfo = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> connectDrive() async {
    _error = null;
    _isLoadingInfo = true;
    notifyListeners();

    try {
      final account = await _service.connectGoogleDrive();
      if (account != null) {
        _backupMetadata = await _service.getLatestBackupInfo();
        _isLoadingInfo = false;
        notifyListeners();
        return true;
      }
      _isLoadingInfo = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google Drive connection failed: ${e.toString()}';
      _isLoadingInfo = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectDrive() async {
    await _service.disconnectGoogleDrive();
    _backupMetadata = null;
    notifyListeners();
  }

  Future<bool> triggerBackup() async {
    if (!isConnected) {
      final ok = await connectDrive();
      if (!ok) return false;
    }

    _isBackingUp = true;
    _error = null;
    notifyListeners();

    try {
      final meta = await _service.createBackup();
      _backupMetadata = meta;
      _isBackingUp = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Backup failed: ${e.toString()}';
      _isBackingUp = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> triggerRestore() async {
    if (!isConnected) {
      final ok = await connectDrive();
      if (!ok) return false;
    }

    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      await _service.restoreBackup();
      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Restore failed: ${e.toString()}';
      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> setAutoBackupFrequency(String frequency) async {
    _autoBackupFrequency = frequency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_frequency', frequency);
  }
}
