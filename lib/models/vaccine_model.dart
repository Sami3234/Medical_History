class VaccineModel {
  final String id;
  final String memberId;
  final String name;
  final String? dose; // 'Dose 1', 'Dose 2', 'Booster'
  final DateTime administeredDate;
  final DateTime? nextDueDate;
  final String? administeredBy;
  final String? notes;
  final String status; // 'Completed', 'Upcoming', 'Pending'

  VaccineModel({
    required this.id,
    required this.memberId,
    required this.name,
    this.dose,
    required this.administeredDate,
    this.nextDueDate,
    this.administeredBy,
    this.notes,
    this.status = 'Completed',
  });

  factory VaccineModel.fromMap(Map<String, dynamic> map) {
    return VaccineModel(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      name: map['name'] as String,
      dose: map['dose'] as String?,
      administeredDate: map['administered_date'] != null
          ? DateTime.parse(map['administered_date'] as String)
          : DateTime.now(),
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      administeredBy: map['administered_by'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'Completed',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'member_id': memberId,
        'name': name,
        'dose': dose,
        'administered_date': administeredDate.toIso8601String(),
        'next_due_date': nextDueDate?.toIso8601String(),
        'administered_by': administeredBy,
        'notes': notes,
        'status': status,
      };
}
