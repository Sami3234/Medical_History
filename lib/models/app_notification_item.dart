enum AppNotificationType { appointment, document, emergency }

class AppNotificationItem {
  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String route;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.route,
  });
}
