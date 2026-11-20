import '../config/constants.dart';
import '../config/supabase_config.dart';
import '../models/member_model.dart';
import 'offline_data_service.dart';

class OwnerProfileService {
  static String? verifiedOwnerUserId;
  static bool homePrefetchFinished = false;

  Future<MemberModel?> getProfile(String userId) => getOwnerMember(userId);

  Future<MemberModel?> getOwnerMember(String userId) async {
    // 1. Instant cached owner check
    final cached = OfflineDataService.getOwner(userId);
    if (cached != null) {
      verifiedOwnerUserId = userId;
    }

    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) return cached;

    try {
      final row = await db
          .from('members')
          .select('*, families!inner(user_id)')
          .eq('families.user_id', userId)
          .ilike('relation', 'self')
          .order('created_at')
          .limit(1)
          .maybeSingle()
          .timeout(AppNetwork.quickTimeout);

      if (row != null) {
        final member = MemberModel.fromMap(row);
        await OfflineDataService.saveOwner(userId, member);
        verifiedOwnerUserId = userId;
        return member;
      }
      return cached;
    } catch (_) {
      // In case of timeout or offline, return cached owner
      return cached;
    }
  }

  bool isComplete(MemberModel? member) {
    return member != null &&
        member.name.trim().isNotEmpty &&
        member.dob != null &&
        (member.gender?.trim().isNotEmpty ?? false) &&
        (member.bloodGroup?.trim().isNotEmpty ?? false) &&
        (member.emergencyContact?.trim().isNotEmpty ?? false);
  }

  Future<MemberModel> saveOwner({
    required String userId,
    required String name,
    required DateTime dob,
    required String gender,
    required String bloodGroup,
    required String emergencyContact,
    String? allergies,
  }) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) {
      throw StateError('Sign in is required before creating your profile.');
    }

    final families = await db
        .from('families')
        .select('id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    late final String familyId;
    if (families.isEmpty) {
      final family = await db
          .from('families')
          .insert({
            'user_id': userId,
            'family_id': 'FAM-${userId.substring(0, 8).toUpperCase()}',
            'name': '${name.trim()} Family',
          })
          .select('id')
          .single();
      familyId = family['id'] as String;
    } else {
      familyId = families.first['id'] as String;
    }

    final payload = <String, dynamic>{
      'family_id': familyId,
      'name': name.trim(),
      'relation': 'Self',
      'dob': dob.toIso8601String(),
      'gender': gender,
      'blood_group': bloodGroup,
      'emergency_contact': emergencyContact.trim(),
      'allergies': (allergies == null || allergies.trim().isEmpty)
          ? null
          : allergies.trim(),
    };

    final existing = await getOwnerMember(userId);
    late final Map<String, dynamic> row;
    if (existing == null) {
      row = await db.from('members').insert(payload).select().single();
    } else {
      row = await db
          .from('members')
          .update(payload)
          .eq('id', existing.id)
          .select()
          .single();
    }

    await db
        .from('profiles')
        .update({
          'full_name': name.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    final member = MemberModel.fromMap(row);
    verifiedOwnerUserId = userId;
    await OfflineDataService.saveOwner(userId, member);
    return member;
  }
}
