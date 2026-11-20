import '../config/constants.dart';
import '../config/supabase_config.dart';
import '../models/family_model.dart';

class FamilyService {
  Future<List<FamilyModel>> getAll(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('families')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(AppNetwork.dataTimeout);
      return data.map((e) => FamilyModel.fromMap(e)).toList();
    }
    return [];
  }

  Future<FamilyModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('families')
          .select()
          .eq('id', id)
          .single();
      return FamilyModel.fromMap(data);
    }
    throw StateError('Supabase is not available. Please try again later.');
  }

  Future<void> create(Map<String, dynamic> family) async {
    final famData = Map<String, dynamic>.from(family);
    final uid = famData['user_id'] ?? SupabaseConfig.currentUserId;
    if (uid != null) famData['user_id'] = uid;

    if (SupabaseConfig.isInitialized &&
        SupabaseConfig.db != null &&
        famData['user_id'] != null) {
      await SupabaseConfig.db!.from('families').insert(famData);
    } else {
      throw StateError('Sign in is required before adding a family.');
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('families').update(updates).eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final ownerMembers = await SupabaseConfig.db!
          .from('members')
          .select('id')
          .eq('family_id', id)
          .ilike('relation', 'self')
          .limit(1);
      if (ownerMembers.isNotEmpty) {
        throw StateError(
          'The family containing your permanent Self profile cannot be deleted.',
        );
      }
      await SupabaseConfig.db!.from('families').delete().eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  Future<int> getCount(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('families')
          .select('id')
          .eq('user_id', userId);
      return data.length;
    }
    return 0;
  }
}
