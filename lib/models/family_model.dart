class FamilyModel {
  final String id;
  final String familyId; // FAM-XXXX
  final String name;
  final String? contact;
  final String? address;
  final String userId;
  final DateTime createdAt;

  FamilyModel({
    required this.id,
    required this.familyId,
    required this.name,
    this.contact,
    this.address,
    required this.userId,
    required this.createdAt,
  });

  factory FamilyModel.fromMap(Map<String, dynamic> map) {
    return FamilyModel(
      id: map['id'] as String,
      familyId: map['family_id'] as String,
      name: map['name'] as String,
      contact: map['contact'] as String?,
      address: map['address'] as String?,
      userId: map['user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'family_id': familyId,
    'name': name,
    'contact': contact,
    'address': address,
    'user_id': userId,
  };
}
