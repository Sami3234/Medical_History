import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';
import '../services/offline_data_service.dart';

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
    // 1. Instant cache load (0ms)
    final cached = OfflineDataService.getMembers(userId);
    if (cached.isNotEmpty) {
      _members = List.from(cached);
      notifyListeners();
    } else {
      _setLoading(true);
    }
    _error = null;

    // 2. Background revalidation
    try {
      final fresh = await _service.getAll(userId);
      _members = fresh;
      await OfflineDataService.saveMembers(userId, fresh);
      notifyListeners();
      return true;
    } catch (e) {
      if (_members.isEmpty) {
        _error = _friendlyError(e);
      }
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
      _members.removeWhere((m) => m.id == newMember.id);
      _members.add(newMember);

      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        _members = await _service.getAll(uid);
        await OfflineDataService.saveMembers(uid, _members);
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
          dob: data['dob'] != null
              ? DateTime.tryParse(data['dob'] as String)
              : old.dob,
          gender: data['gender'] ?? old.gender,
          bloodGroup: data['blood_group'] ?? old.bloodGroup,
          allergies: data.containsKey('allergies')
              ? data['allergies'] as String?
              : old.allergies,
          notes: data.containsKey('notes')
              ? data['notes'] as String?
              : old.notes,
          avatarUrl: data['avatar_url'] ?? old.avatarUrl,
          emergencyContact: data.containsKey('emergency_contact')
              ? data['emergency_contact'] as String?
              : old.emergencyContact,
          parentId: data.containsKey('parent_id')
              ? data['parent_id'] as String?
              : old.parentId,
          createdAt: old.createdAt,
        );
      }
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        await OfflineDataService.saveMembers(uid, _members);
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
      final memberIndex = _members.indexWhere((item) => item.id == id);
      final member = memberIndex == -1 ? null : _members[memberIndex];
      if (member?.relation.toLowerCase().trim() == 'self') {
        _error = 'The Self owner profile cannot be deleted.';
        notifyListeners();
        return false;
      }
      await _service.delete(id);
      _members.removeWhere((m) => m.id == id);
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        await OfflineDataService.saveMembers(uid, _members);
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
      return 'A member with this data already exists.';
    }
    if (msg.contains('member_relation_limit') || msg.contains('23514')) {
      return 'This family relationship has reached its maximum allowed limit.';
    }
    return 'Something went wrong. Please try again.';
  }
}
