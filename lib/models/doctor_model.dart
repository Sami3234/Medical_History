class DoctorModel {
  final String id;
  final String userId;
  final String name;
  final String? specialization;
  final String? hospital;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  DoctorModel({
    required this.id,
    required this.userId,
    required this.name,
    this.specialization,
    this.hospital,
    this.phone,
    this.address,
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
      address: map['address'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'name': name,
    'specialization': specialization,
    'hospital': hospital,
    'phone': phone,
    'address': address,
  };
}
