import '../config/constants.dart';
import '../config/supabase_config.dart';
import '../models/doctor_model.dart';

class DoctorService {
  Future<List<DoctorModel>> getAll(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('doctors')
          .select()
          .eq('user_id', userId)
          .order('name')
          .timeout(AppNetwork.dataTimeout);
      return data.map((e) => DoctorModel.fromMap(e)).toList();
    }
    return [];
  }

  Future<DoctorModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('doctors')
          .select()
          .eq('id', id)
          .single();
      return DoctorModel.fromMap(data);
    }
    throw StateError('Supabase is not available. Please try again later.');
  }

  Future<void> create(Map<String, dynamic> doctor) async {
    final docData = Map<String, dynamic>.from(doctor);
    final uid = docData['user_id'] ?? SupabaseConfig.currentUserId;
    if (uid != null) docData['user_id'] = uid;

    if (SupabaseConfig.isInitialized &&
        SupabaseConfig.db != null &&
        docData['user_id'] != null) {
      await SupabaseConfig.db!.from('doctors').insert(docData);
    } else {
      throw StateError('Sign in is required before adding a doctor.');
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('doctors').update(updates).eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('doctors').delete().eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }
}
