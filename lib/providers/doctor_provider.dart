import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/doctor_model.dart';
import '../services/doctor_service.dart';

class DoctorProvider extends ChangeNotifier {
  final _service = DoctorService();

  List<DoctorModel> _doctors = [];
  bool _loading = false;

  List<DoctorModel> get doctors => _doctors;
  bool get loading => _loading;
  int get count => _doctors.length;

  Future<void> loadDoctors(String userId) async {
    _loading = true;
    notifyListeners();
    _doctors = await _service.getAll(userId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addDoctor(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    final uid = data['user_id'] ?? SupabaseConfig.currentUserId ?? 'usr-100';
    data['user_id'] = uid;
    await _service.create(data);
    _doctors = await _service.getAll(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> updateDoctor(String id, Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    await _service.update(id, data);
    final uid = SupabaseConfig.currentUserId ?? 'usr-100';
    _doctors = await _service.getAll(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteDoctor(String id) async {
    await _service.delete(id);
    _doctors.removeWhere((d) => d.id == id);
    notifyListeners();
  }
}

