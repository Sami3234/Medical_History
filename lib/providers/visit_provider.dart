import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/visit_model.dart';
import '../services/visit_service.dart';

class VisitProvider extends ChangeNotifier {
  final _service = VisitService();

  List<VisitModel> _visits = [];
  List<VisitModel> _upcoming = [];
  bool _loading = false;

  List<VisitModel> get visits => _visits;
  List<VisitModel> get upcoming => _upcoming;
  bool get loading => _loading;
  int get count => _visits.length;

  Future<void> loadByMember(String memberId) async {
    _loading = true;
    notifyListeners();
    _visits = await _service.getByMember(memberId);
    _loading = false;
    notifyListeners();
  }

  Future<void> loadRecent(String userId) async {
    _visits = await _service.getRecent(userId);
    notifyListeners();
  }

  Future<void> loadUpcoming(String userId) async {
    _upcoming = await _service.getUpcoming(userId);
    notifyListeners();
  }

  Future<void> addVisit(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.create(data);
    final uid = SupabaseConfig.currentUserId ?? 'usr-100';
    if (data['member_id'] != null) {
      _visits = await _service.getByMember(data['member_id']);
    } else {
      _visits = await _service.getRecent(uid);
    }
    _upcoming = await _service.getUpcoming(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> updateVisit(String id, Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.update(id, data);
    final uid = SupabaseConfig.currentUserId ?? 'usr-100';
    if (data['member_id'] != null) {
      _visits = await _service.getByMember(data['member_id']);
    } else {
      _visits = await _service.getRecent(uid);
    }
    _upcoming = await _service.getUpcoming(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteVisit(String id) async {
    await _service.delete(id);
    _visits.removeWhere((v) => v.id == id);
    _upcoming.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}

