import 'package:flutter_test/flutter_test.dart';
import 'package:medical_history/models/appointment_model.dart';

void main() {
  test('appointment maps clinic, reminder and member details', () {
    final appointmentTime = DateTime.parse('2026-11-12T10:30:00+05:00');
    final appointment = AppointmentModel.fromMap({
      'id': 'appointment-1',
      'member_id': 'member-1',
      'members': {'name': 'Sami Khan'},
      'doctor_id': 'doctor-1',
      'doctor_name': 'Dr. Ayesha',
      'specialty': 'Cardiology',
      'hospital': 'City Clinic',
      'appointment_time': appointmentTime.toIso8601String(),
      'notes': 'Routine follow-up',
      'status': 'upcoming',
      'reminder_set': false,
      'created_at': '2026-10-22T08:00:00Z',
    });

    expect(appointment.memberName, 'Sami Khan');
    expect(appointment.hospital, 'City Clinic');
    expect(appointment.reminderSet, isFalse);

    final map = appointment.toMap('user-1');
    expect(map['doctor_id'], 'doctor-1');
    expect(map['hospital'], 'City Clinic');
    expect(map['reminder_set'], isFalse);
    expect(map['appointment_time'], appointmentTime.toUtc().toIso8601String());
  });
}
