class VitalModel {
  final String id;
  final String memberId;
  final String type; // 'Blood Pressure', 'Blood Sugar', 'Heart Rate', 'Oxygen (SpO2)', 'Weight', 'Temperature'
  final String value;
  final String unit;
  final DateTime recordedAt;
  final String? notes;
  final String status; // 'Normal', 'Warning', 'Elevated', 'Low'

  VitalModel({
    required this.id,
    required this.memberId,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    this.notes,
    this.status = 'Normal',
  });

  factory VitalModel.fromMap(Map<String, dynamic> map) {
    return VitalModel(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      type: map['type'] as String,
      value: map['value'] as String,
      unit: map['unit'] as String? ?? '',
      recordedAt: map['recorded_at'] != null
          ? DateTime.parse(map['recorded_at'] as String)
          : DateTime.now(),
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'Normal',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'member_id': memberId,
        'type': type,
        'value': value,
        'unit': unit,
        'recorded_at': recordedAt.toIso8601String(),
        'notes': notes,
        'status': status,
      };

  static String calculateStatus(String type, String value) {
    final cleanType = type.toLowerCase();
    if (cleanType.contains('pressure')) {
      final parts = value.split('/');
      if (parts.length == 2) {
        final sys = int.tryParse(parts[0].trim()) ?? 120;
        final dia = int.tryParse(parts[1].trim()) ?? 80;
        if (sys >= 140 || dia >= 90) return 'Elevated';
        if (sys >= 130 || dia >= 85) return 'Warning';
        if (sys < 90 || dia < 60) return 'Low';
        return 'Normal';
      }
    } else if (cleanType.contains('sugar') || cleanType.contains('glucose')) {
      final val = double.tryParse(value.trim()) ?? 100;
      if (val >= 180) return 'Elevated';
      if (val >= 140) return 'Warning';
      if (val < 70) return 'Low';
      return 'Normal';
    } else if (cleanType.contains('heart') || cleanType.contains('pulse')) {
      final val = int.tryParse(value.trim()) ?? 75;
      if (val > 100) return 'Elevated';
      if (val < 60) return 'Low';
      return 'Normal';
    } else if (cleanType.contains('oxygen') || cleanType.contains('spo2')) {
      final val = double.tryParse(value.trim()) ?? 98;
      if (val < 92) return 'Elevated';
      if (val < 95) return 'Warning';
      return 'Normal';
    }
    return 'Normal';
  }
}
