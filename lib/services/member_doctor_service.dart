import 'dart:async';

import '../config/constants.dart';
import '../config/supabase_config.dart';
import '../models/doctor_model.dart';

class MemberDoctorService {
  Future<Map<String, List<DoctorModel>>> getDoctorsForMembers(
    List<String> memberIds,
  ) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null || memberIds.isEmpty) {
      return {};
    }
    try {
      final rows = await db
          .from('member_doctors')
          .select('member_id, created_at, doctors(*)')
          .inFilter('member_id', memberIds)
          .order('created_at', ascending: false)
          .timeout(AppNetwork.quickTimeout);
      final result = <String, List<DoctorModel>>{};
      for (final row in rows) {
        final memberId = row['member_id'] as String;
        final doctorData = row['doctors'];
        if (doctorData is Map) {
          result
              .putIfAbsent(memberId, () => [])
              .add(DoctorModel.fromMap(Map<String, dynamic>.from(doctorData)));
        }
      }
      return result;
    } on TimeoutException {
      return {};
    } catch (_) {
      final entries = await Future.wait(
        memberIds.map((memberId) async {
          final doctors = await getDoctors(memberId);
          return MapEntry(memberId, doctors);
        }),
      );
      return Map<String, List<DoctorModel>>.fromEntries(entries);
    }
  }

  Future<List<DoctorModel>> getDoctors(String memberId) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) return [];
    final rows = await db
        .from('member_doctors')
        .select('created_at, doctors(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false)
        .timeout(AppNetwork.dataTimeout);
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
