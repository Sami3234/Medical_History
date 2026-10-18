import '../config/supabase_config.dart';
import '../models/visit_model.dart';
import '../models/medication_model.dart';
import 'mock_data_service.dart';

class VisitService {
  final _mock = MockDataService();

  Future<List<VisitModel>> getByMember(String memberId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('visits')
          .select('*, members(name), doctors(name)')
          .eq('member_id', memberId)
          .order('visit_date', ascending: false);
      return data.map((e) => VisitModel.fromMap(e)).toList();
    }
    return _mock.visits.where((v) => v.memberId == memberId).toList();
  }

  Future<List<VisitModel>> getRecent(String userId, {int limit = 5}) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('visits')
          .select(
            '*, members!inner(name, family_id, families!inner(user_id)), doctors(name)',
          )
          .eq('members.families.user_id', userId)
          .order('visit_date', ascending: false)
          .limit(limit);
      return data.map((e) => VisitModel.fromMap(e)).toList();
    }
    final sorted = List<VisitModel>.from(_mock.visits)
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return sorted.take(limit).toList();
  }

  Future<List<VisitModel>> getUpcoming(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final now = DateTime.now().toIso8601String();
      final data = await SupabaseConfig.db!
          .from('visits')
          .select(
            '*, members!inner(name, family_id, families!inner(user_id)), doctors(name)',
          )
          .eq('members.families.user_id', userId)
          .gte('follow_up_date', now)
          .order('follow_up_date');
      return data.map((e) => VisitModel.fromMap(e)).toList();
    }
    return _mock.visits.where((v) => v.followUpDate != null).toList();
  }

  Future<VisitModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('visits')
          .select('*, members(name), doctors(name)')
          .eq('id', id)
          .single();
      return VisitModel.fromMap(data);
    }
    return _mock.visits.firstWhere(
      (v) => v.id == id,
      orElse: () => _mock.visits.first,
    );
  }

  Future<void> create(Map<String, dynamic> visit) async {
    final visitData = Map<String, dynamic>.from(visit);
    final coreData = <String, dynamic>{
      'member_id': visitData['member_id'],
      if (visitData['doctor_id'] != null) 'doctor_id': visitData['doctor_id'],
      'visit_date': visitData['visit_date'] ?? DateTime.now().toIso8601String(),
      if (visitData['symptoms'] != null) 'symptoms': visitData['symptoms'],
      if (visitData['diagnosis'] != null) 'diagnosis': visitData['diagnosis'],
      if (visitData['treatment'] != null) 'treatment': visitData['treatment'],
      if (visitData['notes'] != null) 'notes': visitData['notes'],
      if (visitData['follow_up_date'] != null)
        'follow_up_date': visitData['follow_up_date'],
    };

    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('visits').insert(visitData);
      } catch (_) {
        await SupabaseConfig.db!.from('visits').insert(coreData);
      }
    } else {
      String? memberName;
      final mIdx = _mock.members.indexWhere((m) => m.id == visit['member_id']);
      if (mIdx != -1) memberName = _mock.members[mIdx].name;

      String? doctorName;
      if (visit['doctor_id'] != null) {
        final dIdx = _mock.doctors.indexWhere(
          (d) => d.id == visit['doctor_id'],
        );
        if (dIdx != -1) doctorName = _mock.doctors[dIdx].name;
      }

      final newVisit = VisitModel(
        id: 'vis-${DateTime.now().millisecondsSinceEpoch}',
        memberId:
            visit['member_id'] ??
            (_mock.members.isNotEmpty ? _mock.members.first.id : 'mem-1'),
        doctorId: visit['doctor_id'],
        visitDate: visit['visit_date'] != null
            ? DateTime.parse(visit['visit_date'])
            : DateTime.now(),
        symptoms: visit['symptoms'],
        diagnosis: visit['diagnosis'],
        treatment: visit['treatment'],
        notes: visit['notes'],
        followUpDate: visit['follow_up_date'] != null
            ? DateTime.tryParse(visit['follow_up_date'])
            : null,
        createdAt: DateTime.now(),
        memberName: memberName ?? 'Member',
        doctorName: doctorName ?? (visit['doctor_name'] as String? ?? 'Doctor'),
        hospital: visit['hospital'] as String?,
      );
      _mock.visits.insert(0, newVisit);
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('visits').update(updates).eq('id', id);
    } else {
      final idx = _mock.visits.indexWhere((v) => v.id == id);
      if (idx != -1) {
        final old = _mock.visits[idx];
        _mock.visits[idx] = VisitModel(
          id: old.id,
          memberId: updates['member_id'] ?? old.memberId,
          doctorId: updates['doctor_id'] ?? old.doctorId,
          visitDate: updates['visit_date'] != null
              ? DateTime.parse(updates['visit_date'])
              : old.visitDate,
          symptoms: updates['symptoms'] ?? old.symptoms,
          diagnosis: updates['diagnosis'] ?? old.diagnosis,
          treatment: updates['treatment'] ?? old.treatment,
          notes: updates['notes'] ?? old.notes,
          followUpDate: updates['follow_up_date'] != null
              ? DateTime.parse(updates['follow_up_date'])
              : old.followUpDate,
          createdAt: old.createdAt,
          memberName: old.memberName,
          doctorName: old.doctorName,
          hospital: updates['hospital'] ?? old.hospital,
        );
      }
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('visits').delete().eq('id', id);
    } else {
      _mock.visits.removeWhere((v) => v.id == id);
    }
  }

  // Medications
  Future<List<MedicationModel>> getMedications(String visitId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('medications')
          .select()
          .eq('visit_id', visitId);
      return data.map((e) => MedicationModel.fromMap(e)).toList();
    }
    return _mock.medications.where((m) => m.visitId == visitId).toList();
  }

  Future<void> addMedication(Map<String, dynamic> med) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('medications').insert(med);
    } else {
      final newMed = MedicationModel(
        id: 'med-${DateTime.now().millisecondsSinceEpoch}',
        visitId: med['visit_id'] ?? '',
        name: med['name'] ?? '',
        dosage: med['dosage'],
        frequency: med['frequency'],
        duration: med['duration'],
        notes: med['notes'],
      );
      _mock.medications.add(newMed);
    }
  }

  Future<void> deleteMedication(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('medications').delete().eq('id', id);
    } else {
      _mock.medications.removeWhere((m) => m.id == id);
    }
  }

  Future<int> getVisitCount(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('visits')
          .select('id, members!inner(family_id, families!inner(user_id))')
          .eq('members.families.user_id', userId);
      return data.length;
    }
    return _mock.visits.length;
  }
}
