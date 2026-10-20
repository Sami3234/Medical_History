class MedicationModel {
  final String id;
  final String? visitId;
  final String? memberId;
  final String name;
  final String? dosage;
  final String? frequency; // 'Once daily', 'Twice daily', 'Thrice daily', 'As needed'
  final String? timing; // 'Before meal', 'After meal', 'Bedtime'
  final String? duration;
  final String? notes;
  final bool isActive;
  final bool takenToday;

  MedicationModel({
    required this.id,
    this.visitId,
    this.memberId,
    required this.name,
    this.dosage,
    this.frequency,
    this.timing,
    this.duration,
    this.notes,
    this.isActive = true,
    this.takenToday = false,
  });

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] as String,
      visitId: map['visit_id'] as String?,
      memberId: map['member_id'] as String?,
      name: map['name'] as String,
      dosage: map['dosage'] as String?,
      frequency: map['frequency'] as String?,
      timing: map['timing'] as String?,
      duration: map['duration'] as String?,
      notes: map['notes'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      takenToday: map['taken_today'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (visitId != null) 'visit_id': visitId,
        if (memberId != null) 'member_id': memberId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'timing': timing,
        'duration': duration,
        'notes': notes,
        'is_active': isActive,
        'taken_today': takenToday,
      };

  MedicationModel copyWith({
    String? id,
    String? visitId,
    String? memberId,
    String? name,
    String? dosage,
    String? frequency,
    String? timing,
    String? duration,
    String? notes,
    bool? isActive,
    bool? takenToday,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      duration: duration ?? this.duration,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      takenToday: takenToday ?? this.takenToday,
    );
  }
}
