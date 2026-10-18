import '../config/supabase_config.dart';
import '../models/doctor_model.dart';
import 'mock_data_service.dart';

class DoctorService {
  final _mock = MockDataService();

  Future<List<DoctorModel>> getAll(String userId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('doctors')
          .select()
          .eq('user_id', userId)
          .order('name');
      return data.map((e) => DoctorModel.fromMap(e)).toList();
    }
    return List.from(_mock.doctors);
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
    return _mock.doctors.firstWhere(
      (d) => d.id == id,
      orElse: () => _mock.doctors.first,
    );
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
      final newDoctor = DoctorModel(
        id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
        userId: docData['user_id'] ?? 'usr-100',
        name: docData['name'] ?? 'Dr. Specialist',
        specialization: docData['specialization'],
        hospital: docData['hospital'],
        phone: docData['phone'],
        address: docData['address'],
        createdAt: DateTime.now(),
      );
      _mock.doctors.add(newDoctor);
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('doctors').update(updates).eq('id', id);
    } else {
      final idx = _mock.doctors.indexWhere((d) => d.id == id);
      if (idx != -1) {
        final old = _mock.doctors[idx];
        _mock.doctors[idx] = DoctorModel(
          id: old.id,
          userId: old.userId,
          name: updates['name'] ?? old.name,
          specialization: updates['specialization'] ?? old.specialization,
          hospital: updates['hospital'] ?? old.hospital,
          phone: updates['phone'] ?? old.phone,
          address: updates['address'] ?? old.address,
          createdAt: old.createdAt,
        );
      }
    }
  }

  Future<void> delete(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('doctors').delete().eq('id', id);
    } else {
      _mock.doctors.removeWhere((d) => d.id == id);
    }
  }
}
