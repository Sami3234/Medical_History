class AppointmentModel {
  final String id;
  final String memberId;
  final String memberName;
  final String? doctorId;
  final String doctorName;
  final String specialization;
  final DateTime dateTime;
  final String title;
  final String status;

  const AppointmentModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.dateTime,
    required this.title,
    this.status = 'upcoming',
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    final member = map['members'];
    return AppointmentModel(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      memberName: member is Map<String, dynamic>
          ? (member['name'] as String? ?? 'Family Member')
          : (map['member_name'] as String? ?? 'Family Member'),
      doctorId: map['doctor_id'] as String?,
      doctorName: map['doctor_name'] as String? ?? 'Doctor',
      specialization: map['specialty'] as String? ?? '',
      dateTime: DateTime.parse(map['appointment_time'] as String),
      title: map['notes'] as String? ?? 'Medical appointment',
      status: map['status'] as String? ?? 'upcoming',
    );
  }

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'member_id': memberId,
    'doctor_id': doctorId,
    'doctor_name': doctorName,
    'specialty': specialization,
    'appointment_time': dateTime.toUtc().toIso8601String(),
    'status': status.toLowerCase(),
    'notes': title,
  };
}
