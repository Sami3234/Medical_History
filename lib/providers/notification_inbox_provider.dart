import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification_item.dart';
import '../models/appointment_model.dart';
import '../models/med_file_model.dart';
import '../models/member_model.dart';

class NotificationInboxProvider extends ChangeNotifier {
  static const _readIdsKey = 'notification_inbox_read_ids_v1';

  final Set<String> _readIds = <String>{};
  bool _loaded = false;

  bool get loaded => _loaded;

  NotificationInboxProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _readIds
      ..clear()
      ..addAll(prefs.getStringList(_readIdsKey) ?? const <String>[]);
    _loaded = true;
    notifyListeners();
  }

  List<AppNotificationItem> buildItems({
    required List<AppointmentModel> appointments,
    required List<MedFileModel> documents,
    required List<MemberModel> members,
  }) {
    final now = DateTime.now();
    final documentCutoff = now.subtract(const Duration(days: 7));
    final memberNames = {for (final member in members) member.id: member.name};
    final items = <AppNotificationItem>[];

    for (final appointment in appointments) {
      if (!appointment.dateTime.isAfter(now) ||
          appointment.status.toLowerCase() == 'cancelled') {
        continue;
      }
      final isSoon = appointment.dateTime.difference(now).inHours <= 24;
      items.add(
        AppNotificationItem(
          id: 'appointment:${appointment.id}',
          type: AppNotificationType.appointment,
          title: isSoon ? 'Appointment coming up' : 'Upcoming appointment',
          message: '${appointment.memberName} with ${appointment.doctorName}',
          timestamp: appointment.dateTime,
          route: '/appointments',
        ),
      );
    }

    for (final document in documents) {
      if (document.createdAt.isBefore(documentCutoff)) continue;
      final title = document.description?.trim();
      items.add(
        AppNotificationItem(
          id: 'document:${document.id}',
          type: AppNotificationType.document,
          title: 'Document added',
          message:
              '${title?.isNotEmpty == true ? title : document.fileName ?? 'Medical document'} • ${memberNames[document.memberId] ?? 'Family member'}',
          timestamp: document.createdAt,
          route: '/documents',
        ),
      );
    }

    for (final member in members) {
      final missingBloodGroup = member.bloodGroup?.trim().isNotEmpty != true;
      final missingContact = member.emergencyContact?.trim().isNotEmpty != true;
      if (!missingBloodGroup && !missingContact) continue;
      items.add(
        AppNotificationItem(
          id: 'emergency:${member.id}',
          type: AppNotificationType.emergency,
          title: 'Emergency profile incomplete',
          message:
              'Add ${missingBloodGroup && missingContact
                  ? 'blood group and emergency contact'
                  : missingBloodGroup
                  ? 'blood group'
                  : 'emergency contact'} for ${member.name}.',
          timestamp: member.createdAt,
          route: '/members/${member.id}',
        ),
      );
    }

    items.sort((a, b) {
      final unreadCompare = isRead(a.id) == isRead(b.id)
          ? 0
          : (isRead(a.id) ? 1 : -1);
      if (unreadCompare != 0) return unreadCompare;
      if (a.type == AppNotificationType.appointment &&
          b.type == AppNotificationType.appointment) {
        return a.timestamp.compareTo(b.timestamp);
      }
      return b.timestamp.compareTo(a.timestamp);
    });
    return items;
  }

  bool isRead(String id) => _readIds.contains(id);

  int unreadCount(Iterable<AppNotificationItem> items) =>
      items.where((item) => !isRead(item.id)).length;

  Future<void> markRead(String id) async {
    if (!_readIds.add(id)) return;
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead(Iterable<AppNotificationItem> items) async {
    _readIds.addAll(items.map((item) => item.id));
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, _readIds.toList(growable: false));
  }
}
