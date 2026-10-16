import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/member_model.dart';
import '../services/member_service.dart';

class MemberProvider extends ChangeNotifier {
  final _service = MemberService();

  List<MemberModel> _members = [];
  bool _loading = false;

  List<MemberModel> get members => _members;
  bool get loading => _loading;
  int get count => _members.length;

  Future<void> loadByFamily(String familyId) async {
    _loading = true;
    notifyListeners();
    _members = await _service.getByFamily(familyId);
    _loading = false;
    notifyListeners();
  }

  Future<void> loadAll(String userId) async {
    _loading = true;
    notifyListeners();
    _members = await _service.getAll(userId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addMember(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.create(data);
    if (data['family_id'] != null) {
      _members = await _service.getByFamily(data['family_id']);
    } else {
      _members = await _service.getAll(SupabaseConfig.currentUserId ?? 'usr-100');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.update(id, data);
    if (data['family_id'] != null) {
      _members = await _service.getByFamily(data['family_id']);
    } else {
      _members = await _service.getAll(SupabaseConfig.currentUserId ?? 'usr-100');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteMember(String id) async {
    await _service.delete(id);
    _members.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}

