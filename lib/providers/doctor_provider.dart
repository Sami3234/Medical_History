import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/doctor_model.dart';
import '../services/doctor_service.dart';
import '../services/offline_data_service.dart';

class DoctorProvider extends ChangeNotifier {
  final _service = DoctorService();

  List<DoctorModel> _doctors = [];
  bool _loading = false;
  String? _error;

  List<DoctorModel> get doctors => _doctors;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _doctors.length;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  Future<bool> loadDoctors(String userId) async {
    // 1. Instant cache load (0ms)
    final cached = OfflineDataService.getDoctors(userId);
    if (cached.isNotEmpty) {
      _doctors = List.from(cached);
      notifyListeners();
    } else {
      _setLoading(true);
    }
    _error = null;

    // 2. Background revalidation
    try {
      final fresh = await _service.getAll(userId);
      _doctors = fresh;
      await OfflineDataService.saveDoctors(userId, fresh);
      notifyListeners();
      return true;
    } catch (e) {
      if (_doctors.isEmpty) {
        _error = _friendlyError(e);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addDoctor(Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      final uid = data['user_id'] ?? SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      data['user_id'] = uid;
      await _service.create(data);
      _doctors = await _service.getAll(uid);
      await OfflineDataService.saveDoctors(uid, _doctors);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateDoctor(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.update(id, data);
      final uid = SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      _doctors = await _service.getAll(uid);
      await OfflineDataService.saveDoctors(uid, _doctors);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDoctor(String id) async {
    _error = null;
    try {
      await _service.delete(id);
      _doctors.removeWhere((d) => d.id == id);
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        await OfflineDataService.saveDoctors(uid, _doctors);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleFavorite(DoctorModel doctor) async {
    final updated = !doctor.isFavorite;
    final ok = await updateDoctor(doctor.id, {'is_favorite': updated});
    return ok;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException') ||
        msg.contains('network') ||
        msg.contains('SocketException')) {
      return 'Network is slow. Check your connection and try again.';
    }
    if (msg.contains('permission') || msg.contains('403')) {
      return 'Permission denied. Please log in again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
