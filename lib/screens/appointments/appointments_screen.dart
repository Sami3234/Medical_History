import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/member_model.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/extensions.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _selectedView = 'Upcoming';
  String _selectedMemberId = 'all';
  DateTime? _selectedDate;

  Future<void> _openAppointmentForm([AppointmentModel? appointment]) async {
    final members = context.read<MemberProvider>().members;
    final doctors = context.read<DoctorProvider>().doctors;
    final records = context.read<RecordsProvider>();
    if (members.isEmpty) {
      context.showSnack(
        'Add a family member before scheduling an appointment.',
        isError: true,
      );
      return;
    }

    final draft = await showModalBottomSheet<_AppointmentDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppointmentFormSheet(
        members: members,
        doctors: doctors,
        existingAppointments: records.appointments,
        appointment: appointment,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final member = members.firstWhere((item) => item.id == draft.memberId);
      final saved = AppointmentModel(
        id:
            appointment?.id ??
            'appointment-${DateTime.now().millisecondsSinceEpoch}',
        memberId: member.id,
        memberName: member.name,
        doctorId: draft.doctorId,
        doctorName: draft.doctorName,
        specialization: draft.specialization,
        hospital: draft.hospital,
        dateTime: draft.dateTime,
        title: draft.title,
        status: 'upcoming',
        reminderSet: draft.reminderSet,
        createdAt: appointment?.createdAt,
      );

      AppointmentModel persisted;
      if (appointment == null) {
        persisted = await records.addAppointment(saved);
      } else {
        await NotificationService.cancel(appointment.id);
        persisted = await records.updateAppointment(saved);
      }
      if (persisted.reminderSet) {
        await NotificationService.scheduleAppointmentReminder(
          appointmentId: persisted.id,
          memberName: persisted.memberName,
          doctorName: persisted.doctorName,
          appointmentTime: persisted.dateTime,
        );
      }
      if (mounted) {
        setState(() {
          _selectedView = 'Upcoming';
          _selectedDate = null;
        });
        context.showSnack(
          appointment == null
              ? 'Appointment scheduled successfully.'
              : 'Appointment rescheduled successfully.',
        );
      }
    } catch (error) {
      if (mounted) {
        context.showSnack('Could not save appointment: $error', isError: true);
      }
    }
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          '${appointment.doctorName} with ${appointment.memberName} will be moved to Cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final records = context.read<RecordsProvider>();
    try {
      await NotificationService.cancel(appointment.id);
      await records.cancelAppointment(appointment.id);
      if (mounted) context.showSnack('Appointment cancelled.');
    } catch (error) {
      if (mounted) {
        context.showSnack(
          'Could not cancel appointment: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteAppointment(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete appointment?'),
        content: const Text('This appointment will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final records = context.read<RecordsProvider>();
    try {
      await NotificationService.cancel(appointment.id);
      await records.deleteAppointment(appointment.id);
      if (mounted) context.showSnack('Appointment deleted.');
    } catch (error) {
      if (mounted) {
        context.showSnack(
          'Could not delete appointment: $error',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordsProvider>();
    final members = context.watch<MemberProvider>().members;
    final now = DateTime.now();
    final upcoming = records.appointments
        .where(
          (item) =>
              item.dateTime.isAfter(now) &&
              item.status.toLowerCase() != 'cancelled',
        )
        .length;
    final past = records.appointments
        .where(
          (item) =>
              !item.dateTime.isAfter(now) &&
              item.status.toLowerCase() != 'cancelled',
        )
        .length;
    final cancelled = records.appointments
        .where((item) => item.status.toLowerCase() == 'cancelled')
        .length;
    final appointments =
        records.appointments.where((item) {
          final status = item.status.toLowerCase();
          final matchesView = switch (_selectedView) {
            'Past' => !item.dateTime.isAfter(now) && status != 'cancelled',
            'Cancelled' => status == 'cancelled',
            _ => item.dateTime.isAfter(now) && status != 'cancelled',
          };
          final matchesMember =
              _selectedMemberId == 'all' || item.memberId == _selectedMemberId;
          final matchesDate =
              _selectedDate == null ||
              DateUtils.isSameDay(item.dateTime.toLocal(), _selectedDate);
          return matchesView && matchesMember && matchesDate;
        }).toList()..sort(
          (a, b) => _selectedView == 'Past'
              ? b.dateTime.compareTo(a.dateTime)
              : a.dateTime.compareTo(b.dateTime),
        );
    final calendarDays = List.generate(
      7,
      (index) => DateUtils.dateOnly(now.add(Duration(days: index))),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: records.loadAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _AppointmentsHeader(
                  upcomingCount: upcoming,
                  onBack: () => context.pop(),
                  onSchedule: () => _openAppointmentForm(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SummaryRow(
                      upcoming: upcoming,
                      past: past,
                      cancelled: cancelled,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Manage appointments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Schedule, reschedule and track care for every family member.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ViewSelector(
                      selected: _selectedView,
                      counts: {
                        'Upcoming': upcoming,
                        'Past': past,
                        'Cancelled': cancelled,
                      },
                      onChanged: (value) => setState(() {
                        _selectedView = value;
                        if (value != 'Upcoming') _selectedDate = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue:
                          members.any(
                            (member) => member.id == _selectedMemberId,
                          )
                          ? _selectedMemberId
                          : 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Family member',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All family members'),
                        ),
                        ...members.map(
                          (member) => DropdownMenuItem(
                            value: member.id,
                            child: Text(
                              member.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedMemberId = value ?? 'all'),
                    ),
                    if (_selectedView == 'Upcoming') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 82,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: calendarDays.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final date = calendarDays[index];
                            final selected =
                                _selectedDate != null &&
                                DateUtils.isSameDay(date, _selectedDate);
                            return _DateChip(
                              date: date,
                              selected: selected,
                              count: records.appointments
                                  .where(
                                    (item) =>
                                        item.dateTime.isAfter(now) &&
                                        item.status.toLowerCase() !=
                                            'cancelled' &&
                                        DateUtils.isSameDay(
                                          item.dateTime.toLocal(),
                                          date,
                                        ),
                                  )
                                  .length,
                              onTap: () => setState(
                                () => _selectedDate = selected ? null : date,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? '$_selectedView appointments'
                                : DateFormat(
                                    'EEEE, dd MMMM',
                                  ).format(_selectedDate!),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${appointments.length}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (records.loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (appointments.isEmpty)
                      _EmptyAppointments(
                        view: _selectedView,
                        onSchedule: () => _openAppointmentForm(),
                      )
                    else
                      ...appointments.map(
                        (appointment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AppointmentCard(
                            appointment: appointment,
                            onReschedule: () =>
                                _openAppointmentForm(appointment),
                            onCancel: () => _cancelAppointment(appointment),
                            onDelete: () => _deleteAppointment(appointment),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAppointmentForm(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Schedule',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _AppointmentsHeader extends StatelessWidget {
  final int upcomingCount;
  final VoidCallback onBack;
  final VoidCallback onSchedule;

  const _AppointmentsHeader({
    required this.upcomingCount,
    required this.onBack,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        16,
        12 + MediaQuery.paddingOf(context).top,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF176F43), Color(0xFF2FAE45), Color(0xFF67C93C)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(35),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Family care calendar',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onSchedule,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(70)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        upcomingCount == 0
                            ? 'No upcoming appointments'
                            : '$upcomingCount upcoming appointment${upcomingCount == 1 ? '' : 's'} • reminders appear in your notification bell',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int upcoming;
  final int past;
  final int cancelled;

  const _SummaryRow({
    required this.upcoming,
    required this.past,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(
          value: '$upcoming',
          label: 'Upcoming',
          icon: Icons.event_available_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 9),
        _SummaryCard(
          value: '$past',
          label: 'Past',
          icon: Icons.history_rounded,
          color: const Color(0xFF1685A8),
        ),
        const SizedBox(width: 9),
        _SummaryCard(
          value: '$cancelled',
          label: 'Cancelled',
          icon: Icons.event_busy_rounded,
          color: const Color(0xFFE05252),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _ViewSelector({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: counts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = counts.entries.elementAt(index);
          final active = selected == item.key;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onChanged(item.key),
            label: Text('${item.key}  ${item.value}'),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: active ? Colors.white : context.appTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.appSurface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.primary : context.appBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white70 : context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : context.appTextPrimary,
              ),
            ),
            if (count > 0)
              Text(
                '$count visit${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 8,
                  color: selected ? Colors.white70 : AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.onReschedule,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled = appointment.status.toLowerCase() == 'cancelled';
    final past = appointment.dateTime.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cancelled ? AppColors.error.withAlpha(70) : context.appBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 58,
                decoration: BoxDecoration(
                  color: cancelled
                      ? AppColors.error.withAlpha(18)
                      : AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat(
                        'MMM',
                      ).format(appointment.dateTime).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: cancelled ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    Text(
                      '${appointment.dateTime.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.specialization.isEmpty
                          ? appointment.title
                          : appointment.specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appointment.memberName} • ${DateFormat('hh:mm a').format(appointment.dateTime.toLocal())}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Appointment options',
                onSelected: (value) {
                  if (value == 'reschedule') onReschedule();
                  if (value == 'cancel') onCancel();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  if (!cancelled && !past)
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_calendar_outlined),
                        title: Text('Reschedule'),
                      ),
                    ),
                  if (!cancelled && !past)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.event_busy_outlined),
                        title: Text('Cancel'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (appointment.hospital?.trim().isNotEmpty == true ||
              appointment.reminderSet) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                if (appointment.hospital?.trim().isNotEmpty == true)
                  _InfoPill(
                    icon: Icons.location_on_outlined,
                    label: appointment.hospital!,
                  ),
                if (appointment.reminderSet && !cancelled && !past)
                  const _InfoPill(
                    icon: Icons.notifications_active_outlined,
                    label: 'Reminder on',
                  ),
                _InfoPill(
                  icon: cancelled
                      ? Icons.event_busy_rounded
                      : past
                      ? Icons.history_rounded
                      : Icons.event_available_rounded,
                  label: cancelled
                      ? 'Cancelled'
                      : past
                      ? 'Past'
                      : 'Upcoming',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.appSurfaceRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.appTextSecondary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  final String view;
  final VoidCallback onSchedule;

  const _EmptyAppointments({required this.view, required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 42,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'No ${view.toLowerCase()} appointments',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          if (view == 'Upcoming') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSchedule,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Schedule appointment'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentDraft {
  final String memberId;
  final String? doctorId;
  final String doctorName;
  final String specialization;
  final String? hospital;
  final String title;
  final DateTime dateTime;
  final bool reminderSet;

  const _AppointmentDraft({
    required this.memberId,
    this.doctorId,
    required this.doctorName,
    required this.specialization,
    this.hospital,
    required this.title,
    required this.dateTime,
    required this.reminderSet,
  });
}

class _AppointmentFormSheet extends StatefulWidget {
  final List<MemberModel> members;
  final List<DoctorModel> doctors;
  final List<AppointmentModel> existingAppointments;
  final AppointmentModel? appointment;

  const _AppointmentFormSheet({
    required this.members,
    required this.doctors,
    required this.existingAppointments,
    this.appointment,
  });

  @override
  State<_AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<_AppointmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _memberId;
  late String _doctorChoice;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _reminderSet;
  late final TextEditingController _doctorName;
  late final TextEditingController _specialization;
  late final TextEditingController _hospital;
  late final TextEditingController _title;
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    final appointment = widget.appointment;
    _memberId = appointment?.memberId ?? widget.members.first.id;
    _doctorChoice =
        appointment?.doctorId != null &&
            widget.doctors.any((doctor) => doctor.id == appointment!.doctorId)
        ? appointment!.doctorId!
        : 'manual';
    _date = DateUtils.dateOnly(
      appointment?.dateTime.toLocal() ??
          DateTime.now().add(const Duration(days: 1)),
    );
    _time = appointment == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay.fromDateTime(appointment.dateTime.toLocal());
    _reminderSet = appointment?.reminderSet ?? true;
    _doctorName = TextEditingController(text: appointment?.doctorName ?? '');
    _specialization = TextEditingController(
      text: appointment?.specialization ?? '',
    );
    _hospital = TextEditingController(text: appointment?.hospital ?? '');
    _title = TextEditingController(text: appointment?.title ?? '');
  }

  @override
  void dispose() {
    _doctorName.dispose();
    _specialization.dispose();
    _hospital.dispose();
    _title.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  void _selectDoctor(String value) {
    setState(() {
      _doctorChoice = value;
      if (value == 'manual') {
        _doctorName.clear();
        _specialization.clear();
        _hospital.clear();
        return;
      }
      final doctor = widget.doctors.firstWhere((item) => item.id == value);
      _doctorName.text = doctor.name;
      _specialization.text = doctor.specialization ?? '';
      _hospital.text = doctor.hospital ?? '';
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time == null || !mounted) return;
    setState(() {
      _date = date;
      _time = time;
      _conflictMessage = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final dateTime = _dateTime;
    if (!dateTime.isAfter(DateTime.now())) {
      setState(() => _conflictMessage = 'Choose a future date and time.');
      return;
    }
    final conflict = widget.existingAppointments.any((item) {
      if (item.id == widget.appointment?.id ||
          item.memberId != _memberId ||
          item.status.toLowerCase() == 'cancelled') {
        return false;
      }
      return item.dateTime.difference(dateTime).abs() <
          const Duration(minutes: 30);
    });
    if (conflict) {
      setState(
        () => _conflictMessage =
            'This family member already has an appointment near this time.',
      );
      return;
    }
    Navigator.pop(
      context,
      _AppointmentDraft(
        memberId: _memberId,
        doctorId: _doctorChoice == 'manual' ? null : _doctorChoice,
        doctorName: _doctorName.text.trim(),
        specialization: _specialization.text.trim(),
        hospital: _hospital.text.trim().isEmpty ? null : _hospital.text.trim(),
        title: _title.text.trim().isEmpty
            ? 'Medical appointment'
            : _title.text.trim(),
        dateTime: dateTime,
        reminderSet: _reminderSet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboardInset),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.appointment == null
                    ? 'Schedule appointment'
                    : 'Reschedule appointment',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Choose the family member, doctor and visit time.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Family member *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: widget.members
                    .map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(
                          '${member.name} • ${member.relation}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _memberId = value ?? _memberId;
                  _conflictMessage = null;
                }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _doctorChoice,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Doctor *',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                items: [
                  ...widget.doctors.map(
                    (doctor) => DropdownMenuItem(
                      value: doctor.id,
                      child: Text(
                        '${doctor.name} • ${doctor.specialization ?? 'General physician'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: 'manual',
                    child: Text('Other / enter manually'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _selectDoctor(value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _doctorName,
                readOnly: _doctorChoice != 'manual',
                decoration: const InputDecoration(
                  labelText: 'Doctor name *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Doctor name is required'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _specialization,
                      readOnly: _doctorChoice != 'manual',
                      decoration: const InputDecoration(
                        labelText: 'Specialty',
                        prefixIcon: Icon(Icons.medical_information_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _hospital,
                      readOnly: _doctorChoice != 'manual',
                      decoration: const InputDecoration(
                        labelText: 'Clinic',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason / notes',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: context.appSurfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _conflictMessage == null
                          ? context.appBorder
                          : AppColors.error,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(_date),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            Text(
                              _time.format(context),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_outlined),
                    ],
                  ),
                ),
              ),
              if (_conflictMessage != null) ...[
                const SizedBox(height: 7),
                Text(
                  _conflictMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _reminderSet,
                activeTrackColor: AppColors.primary,
                title: const Text(
                  'Appointment reminders',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Alerts 24 hours and 2 hours before'),
                secondary: const Icon(Icons.notifications_active_outlined),
                onChanged: (value) => setState(() => _reminderSet = value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                    widget.appointment == null
                        ? 'Schedule appointment'
                        : 'Save new schedule',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
