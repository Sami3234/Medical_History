class MemberModel {
  final String id;
  final String familyId;
  final String name;
  final String relation;
  final DateTime? dob;
  final String? gender;
  final String? bloodGroup;
  final String? allergies;
  final String? notes;
  final String? avatarUrl;
  final String? emergencyContact;
  final String? parentId;
  final DateTime createdAt;

  MemberModel({
    required this.id,
    required this.familyId,
    required this.name,
    required this.relation,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.notes,
    this.avatarUrl,
    this.emergencyContact,
    this.parentId,
    required this.createdAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      name: map['name'] as String,
      relation: map['relation'] as String,
      dob: map['dob'] != null ? DateTime.parse(map['dob'] as String) : null,
      gender: map['gender'] as String?,
      bloodGroup: map['blood_group'] as String?,
      allergies: map['allergies'] as String?,
      notes: map['notes'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'family_id': familyId,
    'name': name,
    'relation': relation,
    'dob': dob?.toIso8601String(),
    'gender': gender,
    'blood_group': bloodGroup,
    'allergies': allergies,
    'notes': notes,
    'avatar_url': avatarUrl,
    'emergency_contact': emergencyContact,
    'parent_id': parentId,
  };

  String get age {
    if (dob == null) return 'N/A';
    final now = DateTime.now();
    int years = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      years--;
    }
    return '$years yrs';
  }
}
