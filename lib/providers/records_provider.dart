import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../config/supabase_config.dart';
import '../models/appointment_model.dart';
import '../models/med_file_model.dart';
import '../services/cloudinary_service.dart';
import '../services/local_document_service.dart';

class RecordsProvider extends ChangeNotifier {
  final _localDocuments = LocalDocumentService();
  static const _recentSearchesKey = 'recent_health_searches_v1';

  List<MedFileModel> _files = [];
  List<MedFileModel> _drafts = [];
  List<AppointmentModel> _appointments = [];
  final List<String> _recentSearches = [];
  bool _loading = false;

  List<MedFileModel> get files => _files;
  List<MedFileModel> get drafts => _drafts;
  List<AppointmentModel> get appointments => _appointments;
  List<String> get recentSearches => _recentSearches;
  bool get loading => _loading;

  RecordsProvider() {
    _loadRecentSearches();
    loadAll();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches
      ..clear()
      ..addAll(prefs.getStringList(_recentSearchesKey) ?? const []);
    notifyListeners();
  }

  Future<void> _persistRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _files = await _localDocuments.loadDocuments();
      _drafts = await _localDocuments.loadDrafts();
      if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
        try {
          final data = await SupabaseConfig.db!
              .from('appointments')
              .select('*, members(name)')
              .order('appointment_time')
              .timeout(AppNetwork.quickTimeout);
          _appointments = (data as List)
              .map((item) => AppointmentModel.fromMap(item))
              .toList();
        } catch (_) {
          // Keep existing appointments or empty on slow network
        }
      } else {
        _appointments = [];
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<MedFileModel> addDraft({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final draft = await _localDocuments.saveDraft(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    _drafts = await _localDocuments.loadDrafts();
    notifyListeners();
    return draft;
  }

  Future<void> deleteDraft(String id) async {
    await _localDocuments.deleteDraft(id);
    _drafts = await _localDocuments.loadDrafts();
    notifyListeners();
  }

  Future<MedFileModel> organizeDraft(
    MedFileModel draft, {
    required String memberId,
    required String fileType,
    required String title,
  }) async {
    final document = await _localDocuments.promoteDraft(
      draft,
      memberId: memberId,
      fileType: fileType,
      title: title,
    );
    _drafts = await _localDocuments.loadDrafts();
    _files = await _localDocuments.loadDocuments();
    notifyListeners();
    return document;
  }

  Future<MedFileModel> addDocument({
    required String memberId,
    required String title,
    required String fileType,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? visitId,
    String? ocrText,
  }) async {
    final document = await _localDocuments.saveDocument(
      bytes: bytes,
      fileName: fileName,
      memberId: memberId,
      fileType: fileType,
      description: title,
      visitId: visitId,
      mimeType: mimeType,
      ocrText: ocrText,
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

  Future<AppointmentModel> addAppointment(AppointmentModel appointment) async {
    final userId = SupabaseConfig.currentUserId;
    if (SupabaseConfig.isInitialized &&
        SupabaseConfig.db != null &&
        userId != null) {
      final data = await SupabaseConfig.db!
          .from('appointments')
          .insert(appointment.toMap(userId))
          .select('*, members(name)')
          .single();
      final created = AppointmentModel.fromMap(data);
      _appointments.add(created);
      _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      notifyListeners();
      return created;
    } else {
      throw StateError('Sign in is required before adding an appointment.');
    }
  }

  Future<AppointmentModel> updateAppointment(
    AppointmentModel appointment,
  ) async {
    final userId = SupabaseConfig.currentUserId;
    if (!SupabaseConfig.isInitialized ||
        SupabaseConfig.db == null ||
        userId == null) {
      throw StateError('Sign in is required before updating an appointment.');
    }
    final data = await SupabaseConfig.db!
        .from('appointments')
        .update(appointment.toMap(userId))
        .eq('id', appointment.id)
        .select('*, members(name)')
        .single();
    final updated = AppointmentModel.fromMap(data);
    final index = _appointments.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      _appointments.add(updated);
    } else {
      _appointments[index] = updated;
    }
    _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    notifyListeners();
    return updated;
  }

  Future<void> cancelAppointment(String appointmentId) async {
    final appointment = _appointments.firstWhere(
      (item) => item.id == appointmentId,
    );
    await updateAppointment(appointment.copyWith(status: 'cancelled'));
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final userId = SupabaseConfig.currentUserId;
    if (!SupabaseConfig.isInitialized ||
        SupabaseConfig.db == null ||
        userId == null) {
      throw StateError('Sign in is required before deleting an appointment.');
    }
    await SupabaseConfig.db!
        .from('appointments')
        .delete()
        .eq('id', appointmentId)
        .eq('user_id', userId);
    _appointments.removeWhere((item) => item.id == appointmentId);
    notifyListeners();
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 8) _recentSearches.removeLast();
    _persistRecentSearches();
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    _persistRecentSearches();
    notifyListeners();
  }

  void removeRecentSearch(String query) {
    _recentSearches.remove(query);
    _persistRecentSearches();
    notifyListeners();
  }
}
