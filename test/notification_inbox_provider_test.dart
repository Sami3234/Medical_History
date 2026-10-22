import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_history/models/appointment_model.dart';
import 'package:medical_history/models/med_file_model.dart';
import 'package:medical_history/models/member_model.dart';
import 'package:medical_history/providers/notification_inbox_provider.dart';

void main() {
  test('builds real health notifications and persists read state', () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final provider = NotificationInboxProvider();
    await Future<void>.delayed(Duration.zero);

    final items = provider.buildItems(
      appointments: [
        AppointmentModel(
          id: 'appointment-1',
          memberId: 'member-1',
          memberName: 'Sami',
          doctorName: 'Dr. Khan',
          specialization: 'General physician',
          dateTime: now.add(const Duration(days: 90)),
          title: 'Follow-up',
        ),
        AppointmentModel(
          id: 'appointment-cancelled',
          memberId: 'member-1',
          memberName: 'Sami',
          doctorName: 'Dr. Khan',
          specialization: 'General physician',
          dateTime: now.add(const Duration(days: 2)),
          title: 'Cancelled follow-up',
          status: 'cancelled',
        ),
      ],
      documents: [
        MedFileModel(
          id: 'document-1',
          memberId: 'member-1',
          fileUrl: 'local/report.pdf',
          fileType: 'labReport',
          description: 'Blood report',
          createdAt: now,
        ),
      ],
      members: [
        MemberModel(
          id: 'member-1',
          familyId: 'family-1',
          name: 'Sami',
          relation: 'Self',
          createdAt: now,
        ),
      ],
    );

    expect(items, hasLength(3));
    expect(provider.unreadCount(items), 3);
    await provider.markRead(items.first.id);
    expect(provider.unreadCount(items), 2);
  });
}
