import 'package:flutter/material.dart';
import '../models/med_file_model.dart';
import '../services/mock_data_service.dart';

class RecordsProvider extends ChangeNotifier {
  final _mock = MockDataService();

  List<MedFileModel> _files = [];
  List<AppointmentModel> _appointments = [];
  List<String> _recentSearches = [];
  bool _loading = false;
  bool _driveConnected = false;
  bool _isBackingUp = false;
  DateTime? _lastBackupTime = DateTime.now().subtract(const Duration(days: 2));

  List<MedFileModel> get files => _files;
  List<AppointmentModel> get appointments => _appointments;
  List<String> get recentSearches => _recentSearches;
  bool get loading => _loading;
  bool get driveConnected => _driveConnected;
  bool get isBackingUp => _isBackingUp;
  DateTime? get lastBackupTime => _lastBackupTime;

  RecordsProvider() {
    loadAll();
  }

  void loadAll() {
    _loading = true;
    _files = List.from(_mock.files);
    _appointments = List.from(_mock.appointments);
    _recentSearches = List.from(_mock.recentSearches);
    _loading = false;
    notifyListeners();
  }

  void addDocument({
    required String memberId,
    required String title,
    required String fileType,
    String? visitId,
    String? fileUrl,
  }) {
    final newFile = MedFileModel(
      id: 'file-${DateTime.now().millisecondsSinceEpoch}',
      visitId: visitId,
      memberId: memberId,
      fileUrl: fileUrl ?? 'assets/docs/$title',
      fileType: fileType,
      description: title,
      createdAt: DateTime.now(),
    );
    _mock.files.insert(0, newFile);
    _files = List.from(_mock.files);
    notifyListeners();
  }

  void deleteDocument(String id) {
    _mock.files.removeWhere((f) => f.id == id);
    _files = List.from(_mock.files);
    notifyListeners();
  }

  void addAppointment(AppointmentModel appointment) {
    _mock.appointments.add(appointment);
    _appointments = List.from(_mock.appointments);
    notifyListeners();
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    _mock.recentSearches.remove(query);
    _mock.recentSearches.insert(0, query);
    if (_mock.recentSearches.length > 8) {
      _mock.recentSearches.removeLast();
    }
    _recentSearches = List.from(_mock.recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    _mock.recentSearches.clear();
    _recentSearches.clear();
    notifyListeners();
  }

  void toggleDriveConnection() {
    _driveConnected = !_driveConnected;
    notifyListeners();
  }

  Future<void> triggerBackup() async {
    _isBackingUp = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _lastBackupTime = DateTime.now();
    _isBackingUp = false;
    notifyListeners();
  }
}
