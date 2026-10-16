import '../config/supabase_config.dart';
import '../models/member_model.dart';
import 'mock_data_service.dart';

class MemberService {
  final _mock = MockDataService();

  Future<List<MemberModel>> getByFamily(String familyId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('members')
          .select()
          .eq('family_id', familyId)
          .order('created_at');
      return data.map((e) => MemberModel.fromMap(e)).toList();
    }
    return _mock.members.where((m) => m.familyId == familyId).toList();
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
    return List.from(_mock.members);
  }

  Future<MemberModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!.from('members').select().eq('id', id).single();
      return MemberModel.fromMap(data);
    }
    return _mock.members.firstWhere(
      (m) => m.id == id,
      orElse: () => _mock.members.first,
    );
  }

  Future<void> create(Map<String, dynamic> member) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('members').insert(member);
    } else {
      final newMember = MemberModel(
        id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
        familyId: member['family_id'] ?? (_mock.families.isNotEmpty ? _mock.families.first.id : 'fam-1'),
        name: member['name'] ?? 'New Member',
        relation: member['relation'] ?? 'Member',
        dob: member['dob'] != null ? DateTime.tryParse(member['dob']) : null,
        gender: member['gender'],
        bloodGroup: member['blood_group'],
        allergies: member['allergies'],
        notes: member['notes'],
        avatarUrl: member['avatar_url'],
        createdAt: DateTime.now(),
      );
      _mock.members.add(newMember);
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('members').update(updates).eq('id', id);
    } else {
      final idx = _mock.members.indexWhere((m) => m.id == id);
      if (idx != -1) {
        final old = _mock.members[idx];
        _mock.members[idx] = MemberModel(
          id: old.id,
          familyId: updates['family_id'] ?? old.familyId,
          name: updates['name'] ?? old.name,
          relation: updates['relation'] ?? old.relation,
          dob: updates['dob'] != null ? DateTime.tryParse(updates['dob']) : old.dob,
          gender: updates['gender'] ?? old.gender,
          bloodGroup: updates['blood_group'] ?? old.bloodGroup,
          allergies: updates['allergies'] ?? old.allergies,
          notes: updates['notes'] ?? old.notes,
          avatarUrl: updates['avatar_url'] ?? old.avatarUrl,
          createdAt: old.createdAt,
        );
      }
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('members').delete().eq('id', id);
    } else {
      _mock.members.removeWhere((m) => m.id == id);
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
    return _mock.members.length;
  }
}

