class MedicationModel {
  final String id;
  final String visitId;
  final String name;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? notes;

  MedicationModel({
    required this.id,
    required this.visitId,
    required this.name,
    this.dosage,
    this.frequency,
    this.duration,
    this.notes,
  });

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] as String,
      visitId: map['visit_id'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String?,
      frequency: map['frequency'] as String?,
      duration: map['duration'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'visit_id': visitId,
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'duration': duration,
    'notes': notes,
  };
}
