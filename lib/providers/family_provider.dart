import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/family_model.dart';
import '../services/family_service.dart';
import '../services/offline_data_service.dart';

class FamilyProvider extends ChangeNotifier {
  final _service = FamilyService();

  List<FamilyModel> _families = [];
  bool _loading = false;
  String? _error;

  List<FamilyModel> get families => _families;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _families.length;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  Future<bool> loadFamilies(String userId) async {
    // 1. Instant cache load (0ms)
    final cached = OfflineDataService.getFamilies(userId);
    if (cached.isNotEmpty) {
      _families = List.from(cached);
      notifyListeners();
    } else {
      _setLoading(true);
    }
    _error = null;

    // 2. Background revalidation
    try {
      final fresh = await _service.getAll(userId);
      _families = fresh;
      await OfflineDataService.saveFamilies(userId, fresh);
      notifyListeners();
      return true;
    } catch (e) {
      if (_families.isEmpty) {
        _error = _friendlyError(e);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addFamily(Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      final uid = data['user_id'] ?? SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      data['user_id'] = uid;
      await _service.create(data);
      _families = await _service.getAll(uid);
      await OfflineDataService.saveFamilies(uid, _families);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateFamily(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.update(id, data);
      final uid = SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      _families = await _service.getAll(uid);
      await OfflineDataService.saveFamilies(uid, _families);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteFamily(String id) async {
    _error = null;
    try {
      await _service.delete(id);
      _families.removeWhere((f) => f.id == id);
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        await OfflineDataService.saveFamilies(uid, _families);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
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
    if (msg.contains('duplicate') || msg.contains('23505')) {
      return 'This family already exists.';
    }
    if (msg.contains('permanent Self profile')) {
      return 'Your main family contains the permanent Self profile and cannot be deleted.';
    }
    return 'Something went wrong. Please try again.';
  }
}
