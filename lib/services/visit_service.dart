import '../config/supabase_config.dart';
import '../models/visit_model.dart';
import '../models/medication_model.dart';

class VisitService {
  Future<List<VisitModel>> getByMember(String memberId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('visits')
          .select('*, members(name), doctors(name)')
          .eq('member_id', memberId)
          .order('visit_date', ascending: false);
      return data.map((e) => VisitModel.fromMap(e)).toList();
    }
    return [];
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
    return [];
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
    return [];
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
    throw StateError('Supabase is not available. Please try again later.');
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
      throw StateError('Sign in is required before adding a visit.');
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('visits').update(updates).eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('visits').delete().eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
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
    return [];
  }

  Future<void> addMedication(Map<String, dynamic> med) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('medications').insert(med);
    } else {
      throw StateError('Sign in is required before adding medication.');
    }
  }

  Future<void> deleteMedication(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('medications').delete().eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
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
    return 0;
  }
}
