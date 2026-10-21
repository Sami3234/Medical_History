class DoctorModel {
  final String id;
  final String userId;
  final String name;
  final String? specialization;
  final String? hospital;
  final String? phone;
  final String? email;
  final String? address;
  final String? avatarUrl;
  final String? qualification;
  final String? licenseNumber;
  final int? experienceYears;
  final String? availability;
  final String? notes;
  final bool isFavorite;
  final DateTime createdAt;

  DoctorModel({
    required this.id,
    required this.userId,
    required this.name,
    this.specialization,
    this.hospital,
    this.phone,
    this.email,
    this.address,
    this.avatarUrl,
    this.qualification,
    this.licenseNumber,
    this.experienceYears,
    this.availability,
    this.notes,
    this.isFavorite = false,
    required this.createdAt,
  });

  factory DoctorModel.fromMap(Map<String, dynamic> map) {
    return DoctorModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      specialization: map['specialization'] as String?,
      hospital: map['hospital'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      qualification: map['qualification'] as String?,
      licenseNumber: map['license_number'] as String?,
      experienceYears: (map['experience_years'] as num?)?.toInt(),
      availability: map['availability'] as String?,
      notes: map['notes'] as String?,
      isFavorite: map['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'name': name,
    'specialization': specialization,
    'hospital': hospital,
    'phone': phone,
    'email': email,
    'address': address,
    'avatar_url': avatarUrl,
    'qualification': qualification,
    'license_number': licenseNumber,
    'experience_years': experienceYears,
    'availability': availability,
    'notes': notes,
    'is_favorite': isFavorite,
  };
}
