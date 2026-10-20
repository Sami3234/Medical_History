import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';

class MemberProvider extends ChangeNotifier {
  final _service = MemberService();

  List<MemberModel> _members = [];
  bool _loading = false;
  String? _error;

  List<MemberModel> get members => _members;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _members.length;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  Future<bool> loadByFamily(String familyId) async {
    _setLoading(true);
    _error = null;
    try {
      _members = await _service.getByFamily(familyId);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadAll(String userId) async {
    _setLoading(true);
    _error = null;
    try {
      _members = await _service.getAll(userId);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addMember(Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      final newMember = await _service.create(data);
      // Ensure the member is in local list immediately
      _members.removeWhere((m) => m.id == newMember.id);
      _members.add(newMember);

      final uid = SupabaseConfig.currentUserId;
      if (uid != null) _members = await _service.getAll(uid);

      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateMember(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.update(id, data);
      final idx = _members.indexWhere((m) => m.id == id);
      if (idx != -1) {
        final old = _members[idx];
        _members[idx] = MemberModel(
          id: old.id,
          familyId: data['family_id'] ?? old.familyId,
          name: data['name'] ?? old.name,
          relation: data['relation'] ?? old.relation,
          dob: data['dob'] != null ? DateTime.tryParse(data['dob']) : old.dob,
          gender: data['gender'] ?? old.gender,
          bloodGroup: data['blood_group'] ?? old.bloodGroup,
          allergies: data['allergies'] ?? old.allergies,
          notes: data['notes'] ?? old.notes,
          avatarUrl: data['avatar_url'] ?? old.avatarUrl,
          createdAt: old.createdAt,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteMember(String id) async {
    _error = null;
    try {
      await _service.delete(id);
      _members.removeWhere((m) => m.id == id);
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
    if (msg.contains('duplicate') || msg.contains('23505')) {
      return 'A member with this data already exists.';
    }
    return 'Something went wrong. Please try again.';
  }
}
