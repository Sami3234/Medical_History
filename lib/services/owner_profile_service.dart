import '../config/supabase_config.dart';
import '../models/member_model.dart';

class OwnerProfileService {
  Future<MemberModel?> getOwnerMember(String userId) async {
    final db = SupabaseConfig.db;
    if (!SupabaseConfig.isInitialized || db == null) return null;

    final row = await db
        .from('members')
        .select('*, families!inner(user_id)')
        .eq('families.user_id', userId)
        .ilike('relation', 'self')
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : MemberModel.fromMap(row);
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

    return MemberModel.fromMap(row);
  }
}
