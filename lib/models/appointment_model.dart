class AppointmentModel {
  final String id;
  final String memberId;
  final String memberName;
  final String? doctorId;
  final String doctorName;
  final String specialization;
  final String? hospital;
  final DateTime dateTime;
  final String title;
  final String status;
  final bool reminderSet;
  final DateTime? createdAt;

  const AppointmentModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.doctorId,
    required this.doctorName,
    required this.specialization,
    this.hospital,
    required this.dateTime,
    required this.title,
    this.status = 'upcoming',
    this.reminderSet = true,
    this.createdAt,
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
      hospital: map['hospital'] as String?,
      dateTime: DateTime.parse(map['appointment_time'] as String),
      title: map['notes'] as String? ?? 'Medical appointment',
      status: map['status'] as String? ?? 'upcoming',
      reminderSet: map['reminder_set'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'member_id': memberId,
    'doctor_id': doctorId,
    'doctor_name': doctorName,
    'specialty': specialization,
    'hospital': hospital,
    'appointment_time': dateTime.toUtc().toIso8601String(),
    'status': status.toLowerCase(),
    'reminder_set': reminderSet,
    'notes': title,
  };

  AppointmentModel copyWith({
    String? memberId,
    String? memberName,
    String? doctorId,
    String? doctorName,
    String? specialization,
    String? hospital,
    DateTime? dateTime,
    String? title,
    String? status,
    bool? reminderSet,
  }) => AppointmentModel(
    id: id,
    memberId: memberId ?? this.memberId,
    memberName: memberName ?? this.memberName,
    doctorId: doctorId ?? this.doctorId,
    doctorName: doctorName ?? this.doctorName,
    specialization: specialization ?? this.specialization,
    hospital: hospital ?? this.hospital,
    dateTime: dateTime ?? this.dateTime,
    title: title ?? this.title,
    status: status ?? this.status,
    reminderSet: reminderSet ?? this.reminderSet,
    createdAt: createdAt,
  );
}
