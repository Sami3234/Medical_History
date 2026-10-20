import '../config/supabase_config.dart';
import '../models/doctor_model.dart';

class MemberDoctorService {
  Future<List<DoctorModel>> getDoctors(String memberId) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) return [];
    final rows = await db
        .from('member_doctors')
        .select('doctors(*)')
        .eq('member_id', memberId);
    return rows
        .map(
          (row) => DoctorModel.fromMap(
            Map<String, dynamic>.from(row['doctors'] as Map),
          ),
        )
        .toList();
  }

  Future<void> addDoctor({
    required String memberId,
    required String doctorId,
  }) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) {
      throw StateError('Sign in is required before assigning a doctor.');
    }
    await db.from('member_doctors').upsert({
      'member_id': memberId,
      'doctor_id': doctorId,
    }, onConflict: 'member_id,doctor_id');
  }

  Future<void> removeDoctor({
    required String memberId,
    required String doctorId,
  }) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) return;
    await db
        .from('member_doctors')
        .delete()
        .eq('member_id', memberId)
        .eq('doctor_id', doctorId);
  }
}
