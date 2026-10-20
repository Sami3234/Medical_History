import '../config/supabase_config.dart';
import '../models/member_model.dart';

class MemberService {
  Future<List<MemberModel>> getByFamily(String familyId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('members')
          .select()
          .eq('family_id', familyId)
          .order('created_at');
      return data.map((e) => MemberModel.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<MemberModel>> getAll(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('members')
          .select('*, families!inner(user_id)')
          .eq('families.user_id', userId)
          .order('name');
      return data.map((e) => MemberModel.fromMap(e)).toList();
    }
    return [];
  }

  Future<MemberModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('members')
          .select()
          .eq('id', id)
          .single();
      return MemberModel.fromMap(data);
    }
    throw StateError('Supabase is not available. Please try again later.');
  }

  Future<MemberModel> create(Map<String, dynamic> member) async {
    final memberData = Map<String, dynamic>.from(member);
    if (!SupabaseConfig.isInitialized || SupabaseConfig.db == null) {
      throw StateError('Sign in is required before adding a member.');
    }
    final response = await SupabaseConfig.db!
        .from('members')
        .insert(memberData)
        .select()
        .single();
    return MemberModel.fromMap(response);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (!SupabaseConfig.isInitialized || SupabaseConfig.db == null) {
      throw StateError('Supabase is not available. Please try again later.');
    }
    await SupabaseConfig.db!.from('members').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('members').delete().eq('id', id);
    } else {
      throw StateError('Supabase is not available. Please try again later.');
    }
  }

  Future<int> getCount(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('members')
          .select('id, families!inner(user_id)')
          .eq('families.user_id', userId);
      return data.length;
    }
    return 0;
  }
}
