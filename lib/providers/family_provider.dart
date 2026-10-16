import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/family_model.dart';
import '../services/family_service.dart';

class FamilyProvider extends ChangeNotifier {
  final _service = FamilyService();

  List<FamilyModel> _families = [];
  bool _loading = false;

  List<FamilyModel> get families => _families;
  bool get loading => _loading;
  int get count => _families.length;

  Future<void> loadFamilies(String userId) async {
    _loading = true;
    notifyListeners();
    _families = await _service.getAll(userId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addFamily(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    final uid = data['user_id'] ?? SupabaseConfig.currentUserId ?? 'usr-100';
    data['user_id'] = uid;
    await _service.create(data);
    _families = await _service.getAll(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> updateFamily(String id, Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.update(id, data);
    final uid = SupabaseConfig.currentUserId ?? 'usr-100';
    _families = await _service.getAll(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteFamily(String id) async {
    await _service.delete(id);
    _families.removeWhere((f) => f.id == id);
    notifyListeners();
  }
}

