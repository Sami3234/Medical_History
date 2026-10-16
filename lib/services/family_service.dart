import '../config/supabase_config.dart';
import '../models/family_model.dart';
import 'mock_data_service.dart';

class FamilyService {
  final _mock = MockDataService();

  Future<List<FamilyModel>> getAll(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('families')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => FamilyModel.fromMap(e)).toList();
    }
    return List.from(_mock.families);
  }

  Future<FamilyModel> getById(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!.from('families').select().eq('id', id).single();
      return FamilyModel.fromMap(data);
    }
    return _mock.families.firstWhere(
      (f) => f.id == id || f.familyId == id,
      orElse: () => _mock.families.first,
    );
  }

  Future<void> create(Map<String, dynamic> family) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('families').insert(family);
    } else {
      final newFamily = FamilyModel(
        id: 'fam-${DateTime.now().millisecondsSinceEpoch}',
        familyId: family['family_id'] ?? 'FAM-${1000 + _mock.families.length + 1}',
        name: family['name'] ?? 'New Family',
        contact: family['contact'],
        address: family['address'],
        userId: family['user_id'] ?? 'usr-100',
        createdAt: DateTime.now(),
      );
      _mock.families.insert(0, newFamily);
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('families').update(updates).eq('id', id);
    } else {
      final idx = _mock.families.indexWhere((f) => f.id == id);
      if (idx != -1) {
        final old = _mock.families[idx];
        _mock.families[idx] = FamilyModel(
          id: old.id,
          familyId: updates['family_id'] ?? old.familyId,
          name: updates['name'] ?? old.name,
          contact: updates['contact'] ?? old.contact,
          address: updates['address'] ?? old.address,
          userId: old.userId,
          createdAt: old.createdAt,
        );
      }
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('families').delete().eq('id', id);
    } else {
      _mock.families.removeWhere((f) => f.id == id);
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
    return _mock.families.length;
  }
}

