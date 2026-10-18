import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/appointment_model.dart';
import '../models/med_file_model.dart';
import '../services/cloudinary_service.dart';
import '../services/local_document_service.dart';
import '../services/mock_data_service.dart';

class RecordsProvider extends ChangeNotifier {
  final _mock = MockDataService();
  final _localDocuments = LocalDocumentService();

  List<MedFileModel> _files = [];
  List<AppointmentModel> _appointments = [];
  List<String> _recentSearches = [];
  bool _loading = false;

  List<MedFileModel> get files => _files;
  List<AppointmentModel> get appointments => _appointments;
  List<String> get recentSearches => _recentSearches;
  bool get loading => _loading;

  RecordsProvider() {
    loadAll();
  }

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _files = await _localDocuments.loadDocuments();
      if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
        final data = await SupabaseConfig.db!
            .from('appointments')
            .select('*, members(name)')
            .order('appointment_time');
        _appointments = data
            .map((item) => AppointmentModel.fromMap(item))
            .toList();
      } else {
        _appointments = List.from(_mock.appointments);
      }
      _recentSearches = List.from(_mock.recentSearches);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<MedFileModel> addDocument({
    required String memberId,
    required String title,
    required String fileType,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? visitId,
  }) async {
    final document = await _localDocuments.saveDocument(
      bytes: bytes,
      fileName: fileName,
      memberId: memberId,
      fileType: fileType,
      description: title,
      visitId: visitId,
      mimeType: mimeType,
    );
    _files = await _localDocuments.loadDocuments();
    notifyListeners();
    return document;
  }

  Future<void> deleteDocument(String id) async {
    await _localDocuments.deleteDocument(id);
    _files = await _localDocuments.loadDocuments();
    notifyListeners();
  }

  Future<bool> openDocument(MedFileModel document) =>
      _localDocuments.openDocument(document);

  Future<Uint8List> readDocumentBytes(MedFileModel document) =>
      _localDocuments.readBytes(document);

  Future<bool> backupDocumentToCloudinary(MedFileModel document) async {
    final result = await CloudinaryService.uploadDocument(
      bytes: await _localDocuments.readBytes(document),
      filename: document.fileName ?? document.description ?? 'medical_document',
    );
    if (!result.success || result.secureUrl == null) return false;
    await _localDocuments.setBackupUrl(document.id, result.secureUrl!);
    _files = await _localDocuments.loadDocuments();
    notifyListeners();
    return true;
  }

  Future<void> addAppointment(AppointmentModel appointment) async {
    final userId = SupabaseConfig.currentUserId;
    if (SupabaseConfig.isInitialized &&
        SupabaseConfig.db != null &&
        userId != null) {
      final data = await SupabaseConfig.db!
          .from('appointments')
          .insert(appointment.toMap(userId))
          .select('*, members(name)')
          .single();
      _appointments.add(AppointmentModel.fromMap(data));
      _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } else {
      _mock.appointments.add(appointment);
      _appointments = List.from(_mock.appointments);
    }
    notifyListeners();
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    _mock.recentSearches.remove(query);
    _mock.recentSearches.insert(0, query);
    if (_mock.recentSearches.length > 8) _mock.recentSearches.removeLast();
    _recentSearches = List.from(_mock.recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    _mock.recentSearches.clear();
    _recentSearches.clear();
    notifyListeners();
  }
}
