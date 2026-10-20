import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../config/constants.dart';
import 'local_document_service.dart';

class DriveBackupMetadata {
  final String fileId;
  final String fileName;
  final DateTime modifiedTime;
  final int sizeBytes;

  DriveBackupMetadata({
    required this.fileId,
    required this.fileName,
    required this.modifiedTime,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BackupService {
  static const String _backupFileName = 'medical_history_backup.json';
  static const String _prefLastBackupKey = 'last_google_drive_backup_iso';
  final LocalDocumentService _localDocuments = LocalDocumentService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kIsWeb || AppStrings.googleWebClientId.isEmpty
        ? null
        : AppStrings.googleWebClientId,
    scopes: [drive.DriveApi.driveAppdataScope, drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isConnected => _currentUser != null;

  /// Connect Google Account with Drive scopes
  Future<GoogleSignInAccount?> connectGoogleDrive() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account;
    } catch (e) {
      // Return null on user cancel or failure
      return null;
    }
  }

  /// Silently reconnect if previously signed in
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      _currentUser = account;
      return account;
    } catch (_) {
      return null;
    }
  }

  /// Disconnect Google Drive account
  Future<void> disconnectGoogleDrive() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Get authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      final account = await connectGoogleDrive();
      if (account == null) return null;
      final retryClient = await _googleSignIn.authenticatedClient();
      if (retryClient == null) return null;
      return drive.DriveApi(retryClient);
    }
    return drive.DriveApi(client);
  }

  /// Get existing backup details from Drive AppData folder (WhatsApp style)
  Future<DriveBackupMetadata?> getLatestBackupInfo() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return null;

      final f = files.first;
      return DriveBackupMetadata(
        fileId: f.id ?? '',
        fileName: f.name ?? _backupFileName,
        modifiedTime: f.modifiedTime ?? DateTime.now(),
        sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Creates full JSON backup and uploads to Google Drive appDataFolder
  Future<DriveBackupMetadata> createBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Please sign in to Google Drive first.');
    }

    final userId = SupabaseConfig.auth?.currentUser?.id ?? 'local_user';

    // 1. Gather all data from Supabase
    final backupData = await gatherBackupData(userId);
    final jsonString = jsonEncode(backupData);
    final bytes = utf8.encode(jsonString);

    // 2. Check if a backup already exists in appDataFolder
    final existingInfo = await getLatestBackupInfo();

    drive.File uploadedFile;
    final mediaStream = Stream<List<int>>.value(bytes);
    final media = drive.Media(mediaStream, bytes.length);

    if (existingInfo != null) {
      // Update existing file
      final fileMetadata = drive.File()..modifiedTime = DateTime.now();
      uploadedFile = await driveApi.files.update(
        fileMetadata,
        existingInfo.fileId,
        uploadMedia: media,
      );
    } else {
      // Create new file inside hidden appDataFolder
      final newFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..mimeType = 'application/json'
        ..description = 'Medical History private AppData backup';

      uploadedFile = await driveApi.files.create(newFile, uploadMedia: media);
    }

    // Save timestamp locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastBackupKey, DateTime.now().toIso8601String());

    return DriveBackupMetadata(
      fileId: uploadedFile.id ?? existingInfo?.fileId ?? '',
      fileName: _backupFileName,
      modifiedTime: DateTime.now(),
      sizeBytes: bytes.length,
    );
  }

  /// Restores data from the Google Drive appDataFolder backup
  Future<Map<String, dynamic>> restoreBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Please connect to Google Drive first.');
    }

    final backupInfo = await getLatestBackupInfo();
    if (backupInfo == null) {
      throw Exception('No existing backup found in your Google Drive AppData.');
    }

    // Download file content
    final drive.Media downloadedMedia =
        await driveApi.files.get(
              backupInfo.fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> dataBytes = [];
    await for (final chunk in downloadedMedia.stream) {
      dataBytes.addAll(chunk);
    }

    final jsonString = utf8.decode(dataBytes);
    final Map<String, dynamic> backupMap = jsonDecode(jsonString);

    final localDocuments = backupMap['local_documents'];
    if (localDocuments is List) {
      await _localDocuments.restoreFromBackup(localDocuments);
    }

    // Restore account data to Supabase when available.
    await _restoreDataToSupabase(backupMap);

    return backupMap;
  }

  /// Collects all tables from Supabase into structured Map
  Future<Map<String, dynamic>> gatherBackupData(String userId) async {
    final Map<String, dynamic> data = {
      'app': 'Medical History',
      'version': '1.0.0',
      'created_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'local_documents': await _localDocuments.exportForBackup(),
    };

    if (!SupabaseConfig.isInitialized) {
      data['records'] = [];
      return data;
    }

    try {
      final client = SupabaseConfig.client;
      if (client == null) return data;

      final families = await client
          .from('families')
          .select()
          .eq('user_id', userId);
      final members = await client.from('members').select();
      final doctors = await client
          .from('doctors')
          .select()
          .eq('user_id', userId);
      final visits = await client.from('visits').select();
      final medications = await client.from('medications').select();
      final vitals = await client.from('vitals').select();
      final vaccines = await client.from('vaccines').select();
      final appointments = await client.from('appointments').select();

      data['families'] = families;
      data['members'] = members;
      data['doctors'] = doctors;
      data['visits'] = visits;
      data['medications'] = medications;
      data['vitals'] = vitals;
      data['vaccines'] = vaccines;
      data['appointments'] = appointments;
    } catch (_) {
      // Fallback empty if tables don't exist yet
      data['families'] = [];
      data['members'] = [];
      data['doctors'] = [];
      data['visits'] = [];
      data['medications'] = [];
      data['vitals'] = [];
      data['vaccines'] = [];
      data['appointments'] = [];
    }

    return data;
  }

  /// Restore downloaded JSON tables into Supabase
  Future<void> _restoreDataToSupabase(Map<String, dynamic> backupMap) async {
    if (!SupabaseConfig.isInitialized) return;
    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      if (backupMap['families'] is List &&
          (backupMap['families'] as List).isNotEmpty) {
        await client.from('families').upsert(backupMap['families']);
      }
      if (backupMap['members'] is List &&
          (backupMap['members'] as List).isNotEmpty) {
        await client.from('members').upsert(backupMap['members']);
      }
      if (backupMap['doctors'] is List &&
          (backupMap['doctors'] as List).isNotEmpty) {
        await client.from('doctors').upsert(backupMap['doctors']);
      }
      if (backupMap['visits'] is List &&
          (backupMap['visits'] as List).isNotEmpty) {
        await client.from('visits').upsert(backupMap['visits']);
      }
      if (backupMap['medications'] is List &&
          (backupMap['medications'] as List).isNotEmpty) {
        await client.from('medications').upsert(backupMap['medications']);
      }
      if (backupMap['vitals'] is List &&
          (backupMap['vitals'] as List).isNotEmpty) {
        await client.from('vitals').upsert(backupMap['vitals']);
      }
      if (backupMap['vaccines'] is List &&
          (backupMap['vaccines'] as List).isNotEmpty) {
        await client.from('vaccines').upsert(backupMap['vaccines']);
      }
      if (backupMap['appointments'] is List &&
          (backupMap['appointments'] as List).isNotEmpty) {
        await client.from('appointments').upsert(backupMap['appointments']);
      }
    } catch (e) {
      throw Exception('Data restoration failed: $e');
    }
  }
}
