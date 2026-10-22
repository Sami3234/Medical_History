import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/app_notification_item.dart';
import '../../providers/member_provider.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../providers/records_provider.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordsProvider>();
    final members = context.watch<MemberProvider>();
    final inbox = context.watch<NotificationInboxProvider>();
    final items = inbox.buildItems(
      appointments: records.appointments,
      documents: records.files,
      members: members.members,
    );
    final unreadCount = inbox.unreadCount(items);

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => inbox.markAllRead(items),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: records.loadAll,
        child: items.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 62,
                    color: context.appTextSecondary.withAlpha(130),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'You are all caught up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Appointment reminders and important family health updates will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _NotificationTile(
                  item: items[index],
                  isRead: inbox.isRead(items[index].id),
                  onTap: () async {
                    final item = items[index];
                    await inbox.markRead(item.id);
                    if (context.mounted) context.push(item.route);
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.type) {
      AppNotificationType.appointment => (
        Icons.calendar_month_rounded,
        const Color(0xFF1685A8),
      ),
      AppNotificationType.document => (
        Icons.description_rounded,
        const Color(0xFF7C3AED),
      ),
      AppNotificationType.emergency => (
        Icons.health_and_safety_rounded,
        const Color(0xFFE05252),
      ),
    };

    return Material(
      color: isRead ? context.appSurface : context.appSurfaceRaised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isRead ? context.appBorder : color.withAlpha(100),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDarkMode ? 35 : 22),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      DateFormat(
                        'dd MMM yyyy • hh:mm a',
                      ).format(item.timestamp),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
