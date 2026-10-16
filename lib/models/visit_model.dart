class VisitModel {
  final String id;
  final String memberId;
  final String? doctorId;
  final DateTime visitDate;
  final String? symptoms;
  final String? diagnosis;
  final String? treatment;
  final String? notes;
  final DateTime? followUpDate;
  final DateTime createdAt;

  // Joined fields (populated from queries)
  final String? memberName;
  final String? doctorName;

  VisitModel({
    required this.id,
    required this.memberId,
    this.doctorId,
    required this.visitDate,
    this.symptoms,
    this.diagnosis,
    this.treatment,
    this.notes,
    this.followUpDate,
    required this.createdAt,
    this.memberName,
    this.doctorName,
  });

  factory VisitModel.fromMap(Map<String, dynamic> map) {
    return VisitModel(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      doctorId: map['doctor_id'] as String?,
      visitDate: DateTime.parse(map['visit_date'] as String),
      symptoms: map['symptoms'] as String?,
      diagnosis: map['diagnosis'] as String?,
      treatment: map['treatment'] as String?,
      notes: map['notes'] as String?,
      followUpDate: map['follow_up_date'] != null
          ? DateTime.parse(map['follow_up_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      memberName: map['members']?['name'] as String?,
      doctorName: map['doctors']?['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'member_id': memberId,
    'doctor_id': doctorId,
    'visit_date': visitDate.toIso8601String(),
    'symptoms': symptoms,
    'diagnosis': diagnosis,
    'treatment': treatment,
    'notes': notes,
    'follow_up_date': followUpDate?.toIso8601String(),
  };

  bool get hasFollowUp =>
      followUpDate != null && followUpDate!.isAfter(DateTime.now());
}
