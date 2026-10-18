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
      final data = await SupabaseConfig.db!
          .from('members')
          .select()
          .eq('id', id)
          .single();
      return MemberModel.fromMap(data);
    }
    return _mock.members.firstWhere(
      (m) => m.id == id,
      orElse: () => _mock.members.first,
    );
  }

  Future<MemberModel> create(Map<String, dynamic> member) async {
    final memberData = Map<String, dynamic>.from(member);
    String generatedId = 'mem-${DateTime.now().millisecondsSinceEpoch}';

    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final rawFamId = memberData['family_id'];
      if (rawFamId == null ||
          rawFamId == 'fam-1' ||
          rawFamId.toString().length < 30) {
        final fams = await SupabaseConfig.db!
            .from('families')
            .select('id')
            .limit(1);
        if (fams.isNotEmpty) {
          memberData['family_id'] = fams.first['id'];
        }
      }
      try {
        final res = await SupabaseConfig.db!
            .from('members')
            .insert(memberData)
            .select()
            .maybeSingle();
        if (res != null && res['id'] != null) {
          generatedId = res['id'].toString();
        }
      } catch (e) {
        // Log silently
      }
    }

    final newMember = MemberModel(
      id: generatedId,
      familyId:
          memberData['family_id'] ??
          (_mock.families.isNotEmpty ? _mock.families.first.id : 'fam-1'),
      name: memberData['name'] ?? 'New Member',
      relation: memberData['relation'] ?? 'Member',
      dob: memberData['dob'] != null
          ? DateTime.tryParse(memberData['dob'])
          : null,
      gender: memberData['gender'],
      bloodGroup: memberData['blood_group'],
      allergies: memberData['allergies'],
      notes: memberData['notes'],
      avatarUrl: memberData['avatar_url'],
      createdAt: DateTime.now(),
    );

    _mock.members.removeWhere((m) => m.id == newMember.id);
    _mock.members.add(newMember);

    return newMember;
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      try {
        await SupabaseConfig.db!.from('members').update(updates).eq('id', id);
      } catch (_) {}
    }

    final idx = _mock.members.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final old = _mock.members[idx];
      _mock.members[idx] = MemberModel(
        id: old.id,
        familyId: updates['family_id'] ?? old.familyId,
        name: updates['name'] ?? old.name,
        relation: updates['relation'] ?? old.relation,
        dob: updates['dob'] != null
            ? DateTime.tryParse(updates['dob'])
            : old.dob,
        gender: updates['gender'] ?? old.gender,
        bloodGroup: updates['blood_group'] ?? old.bloodGroup,
        allergies: updates['allergies'] ?? old.allergies,
        notes: updates['notes'] ?? old.notes,
        avatarUrl: updates['avatar_url'] ?? old.avatarUrl,
        createdAt: old.createdAt,
      );
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
