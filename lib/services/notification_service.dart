import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> initialize() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  static Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String memberName,
    required String doctorName,
    required DateTime appointmentTime,
  }) async {
    await initialize();
    await cancel(appointmentId);
    final reminders = <({Duration before, String label})>[
      (before: const Duration(hours: 24), label: 'tomorrow'),
      (before: const Duration(hours: 2), label: 'in 2 hours'),
    ];
    for (final reminder in reminders) {
      final reminderTime = appointmentTime.subtract(reminder.before);
      if (!reminderTime.isAfter(DateTime.now())) continue;
      final scheduled = tz.TZDateTime.from(reminderTime, tz.local);
      await plugin.zonedSchedule(
        '$appointmentId:${reminder.before.inHours}h'.hashCode,
        'Upcoming medical appointment',
        '$memberName with $doctorName is scheduled ${reminder.label}.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointments',
            'Appointments',
            channelDescription: 'Appointment reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancel(String appointmentId) async {
    await initialize();
    await plugin.cancel(appointmentId.hashCode);
    await plugin.cancel('$appointmentId:24h'.hashCode);
    await plugin.cancel('$appointmentId:2h'.hashCode);
  }
}
