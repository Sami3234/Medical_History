import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/vital_model.dart';
import '../models/medication_model.dart';
import '../models/vaccine_model.dart';

class HealthProvider extends ChangeNotifier {
  final List<VitalModel> _vitals = [];
  final List<MedicationModel> _medications = [];
  final List<VaccineModel> _vaccines = [];
  bool _initialized = false;

  List<VitalModel> get vitals => List.unmodifiable(_vitals);
  List<MedicationModel> get medications => List.unmodifiable(_medications);
  List<VaccineModel> get vaccines => List.unmodifiable(_vaccines);

  HealthProvider() {
    init();
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromLocal();
    await _removeLegacyDemoRecords();
    _initialized = true;
    notifyListeners();
  }

  List<VitalModel> getVitalsByMember(String memberId) {
    return _vitals.where((v) => v.memberId == memberId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  VitalModel? getLatestVital(String memberId, String type) {
    final list =
        _vitals
            .where(
              (v) =>
                  v.memberId == memberId &&
                  v.type.toLowerCase().contains(type.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list.firstOrNull;
  }

  List<MedicationModel> getMedicationsByMember(String memberId) {
    return _medications.where((m) => m.memberId == memberId).toList();
  }

  List<VaccineModel> getVaccinesByMember(String memberId) {
    return _vaccines.where((v) => v.memberId == memberId).toList()
      ..sort((a, b) => b.administeredDate.compareTo(a.administeredDate));
  }

  // ── Vitals Management ────────────────────────────────────────────────
  Future<void> addVital(VitalModel vital) async {
    _vitals.insert(0, vital);
    notifyListeners();
    await _saveToLocal();

    // Supabase sync if online
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('vitals').insert(vital.toMap());
      } catch (_) {}
    }
  }

  Future<void> deleteVital(String vitalId) async {
    _vitals.removeWhere((v) => v.id == vitalId);
    notifyListeners();
    await _saveToLocal();

    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('vitals').delete().eq('id', vitalId);
      } catch (_) {}
    }
  }

  // ── Medications Management ───────────────────────────────────────────
  Future<void> addMedication(MedicationModel med) async {
    _medications.insert(0, med);
    notifyListeners();
    await _saveToLocal();

    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('medications').insert(med.toMap());
      } catch (_) {}
    }
  }

  Future<void> toggleMedicationTaken(String medId) async {
    final idx = _medications.indexWhere((m) => m.id == medId);
    if (idx != -1) {
      final old = _medications[idx];
      _medications[idx] = old.copyWith(takenToday: !old.takenToday);
      notifyListeners();
      await _saveToLocal();
    }
  }

  Future<void> deleteMedication(String medId) async {
    _medications.removeWhere((m) => m.id == medId);
    notifyListeners();
    await _saveToLocal();
  }

  // ── Vaccine Management ───────────────────────────────────────────────
  Future<void> addVaccine(VaccineModel vaccine) async {
    _vaccines.insert(0, vaccine);
    notifyListeners();
    await _saveToLocal();

    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('vaccines').insert(vaccine.toMap());
      } catch (_) {}
    }
  }

  Future<void> deleteVaccine(String vaccineId) async {
    _vaccines.removeWhere((v) => v.id == vaccineId);
    notifyListeners();
    await _saveToLocal();
  }

  // ── Persistence & Seed ───────────────────────────────────────────────
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vJson = jsonEncode(_vitals.map((e) => e.toMap()).toList());
      final mJson = jsonEncode(_medications.map((e) => e.toMap()).toList());
      final vcJson = jsonEncode(_vaccines.map((e) => e.toMap()).toList());

      await prefs.setString('mh_health_vitals', vJson);
      await prefs.setString('mh_health_meds', mJson);
      await prefs.setString('mh_health_vaccines', vcJson);
    } catch (_) {}
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vStr = prefs.getString('mh_health_vitals');
      if (vStr != null && vStr.isNotEmpty) {
        final List list = jsonDecode(vStr);
        _vitals.clear();
        _vitals.addAll(list.map((e) => VitalModel.fromMap(e)));
      }

      final mStr = prefs.getString('mh_health_meds');
      if (mStr != null && mStr.isNotEmpty) {
        final List list = jsonDecode(mStr);
        _medications.clear();
        _medications.addAll(list.map((e) => MedicationModel.fromMap(e)));
      }

      final vcStr = prefs.getString('mh_health_vaccines');
      if (vcStr != null && vcStr.isNotEmpty) {
        final List list = jsonDecode(vcStr);
        _vaccines.clear();
        _vaccines.addAll(list.map((e) => VaccineModel.fromMap(e)));
      }
    } catch (_) {}
  }

  Future<void> _removeLegacyDemoRecords() async {
    const legacyIds = {
      'vit-1',
      'vit-2',
      'vit-3',
      'vit-4',
      'med-1',
      'med-2',
      'vac-1',
      'vac-2',
      'vac-3',
    };
    final hadLegacyRecords =
        _vitals.any((item) => legacyIds.contains(item.id)) ||
        _medications.any((item) => legacyIds.contains(item.id)) ||
        _vaccines.any((item) => legacyIds.contains(item.id));
    if (!hadLegacyRecords) return;
    _vitals.removeWhere((item) => legacyIds.contains(item.id));
    _medications.removeWhere((item) => legacyIds.contains(item.id));
    _vaccines.removeWhere((item) => legacyIds.contains(item.id));
    await _saveToLocal();
  }
}
