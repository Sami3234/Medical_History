import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/visit_model.dart';
import '../services/visit_service.dart';

class VisitProvider extends ChangeNotifier {
  final _service = VisitService();

  List<VisitModel> _visits = [];
  List<VisitModel> _upcoming = [];
  bool _loading = false;
  String? _error;

  List<VisitModel> get visits => _visits;
  List<VisitModel> get upcoming => _upcoming;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _visits.length;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  Future<bool> loadByMember(String memberId) async {
    _setLoading(true);
    _error = null;
    try {
      _visits = await _service.getByMember(memberId);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadRecent(String userId) async {
    _error = null;
    try {
      _visits = await _service.getRecent(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadUpcoming(String userId) async {
    _error = null;
    try {
      _upcoming = await _service.getUpcoming(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addVisit(Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.create(data);
      final uid = SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      if (data['member_id'] != null) {
        _visits = await _service.getByMember(data['member_id']);
      } else {
        _visits = await _service.getRecent(uid);
      }
      _upcoming = await _service.getUpcoming(uid);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateVisit(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.update(id, data);
      final uid = SupabaseConfig.currentUserId;
      if (uid == null) throw StateError('Sign in is required.');
      if (data['member_id'] != null) {
        _visits = await _service.getByMember(data['member_id']);
      } else {
        _visits = await _service.getRecent(uid);
      }
      _upcoming = await _service.getUpcoming(uid);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteVisit(String id) async {
    _error = null;
    try {
      await _service.delete(id);
      _visits.removeWhere((v) => v.id == id);
      _upcoming.removeWhere((v) => v.id == id);
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
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'Network error. Please check your connection.';
    }
    if (msg.contains('permission') || msg.contains('403')) {
      return 'Permission denied. Please log in again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
