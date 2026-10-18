import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/appointment_model.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../widgets/bottom_nav.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Future<void> _showAddDialog() async {
    final members = context.read<MemberProvider>().members;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a family member before scheduling an appointment.',
          ),
        ),
      );
      return;
    }

    final doctorController = TextEditingController();
    final specialtyController = TextEditingController();
    final titleController = TextEditingController();
    String memberId = members.first.id;
    DateTime appointmentDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay appointmentTime = const TimeOfDay(hour: 10, minute: 0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: memberId,
                  decoration: const InputDecoration(labelText: 'Family member'),
                  items: members
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(member.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) memberId = value;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: doctorController,
                  decoration: const InputDecoration(labelText: 'Doctor name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specialtyController,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Reason / notes',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    DateFormat('dd MMM yyyy').format(appointmentDate),
                  ),
                  subtitle: Text(appointmentTime.format(context)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: appointmentDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: appointmentTime,
                    );
                    if (time == null) return;
                    setDialogState(() {
                      appointmentDate = date;
                      appointmentTime = time;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (doctorController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final member = members.firstWhere((item) => item.id == memberId);
      final dateTime = DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
        appointmentTime.hour,
        appointmentTime.minute,
      );
      await context.read<RecordsProvider>().addAppointment(
        AppointmentModel(
          id: 'appointment-${DateTime.now().millisecondsSinceEpoch}',
          memberId: member.id,
          memberName: member.name,
          doctorName: doctorController.text.trim(),
          specialization: specialtyController.text.trim(),
          dateTime: dateTime,
          title: titleController.text.trim().isEmpty
              ? 'Medical appointment'
              : titleController.text.trim(),
        ),
      );
    }

    doctorController.dispose();
    specialtyController.dispose();
    titleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordsProvider>();
    final upcoming =
        records.appointments
            .where(
              (appointment) =>
                  appointment.dateTime.isAfter(DateTime.now()) &&
                  appointment.status.toLowerCase() != 'cancelled',
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final selectedAppointments = upcoming
        .where(
          (appointment) =>
              DateUtils.isSameDay(appointment.dateTime, _selectedDate),
        )
        .toList();
    final firstDay = _selectedDate.subtract(const Duration(days: 2));
    final calendarDays = List.generate(
      5,
      (index) => firstDay.add(Duration(days: index)),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Appointments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: records.loadAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Text(
                'FAMILY CARE CALENDAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: calendarDays.map((date) {
                        final selected = DateUtils.isSameDay(
                          date,
                          _selectedDate,
                        );
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selectedDate = date),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('EEE').format(date).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                selectedAppointments.isEmpty
                    ? 'Upcoming appointments'
                    : 'Selected day',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              if (records.loading)
                const Center(child: CircularProgressIndicator())
              else if (upcoming.isEmpty)
                const _EmptyAppointments()
              else
                ...(selectedAppointments.isNotEmpty
                        ? selectedAppointments
                        : upcoming)
                    .map(
                      (appointment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AppointmentCard(appointment: appointment),
                      ),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Schedule'),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFDEF2D7),
            child: Text(appointment.memberName.substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.doctorName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${appointment.memberName} • ${appointment.specialization.isEmpty ? appointment.title : appointment.specialization}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat(
                    'dd MMM yyyy • hh:mm a',
                  ).format(appointment.dateTime.toLocal()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 42,
            color: AppColors.primary,
          ),
          SizedBox(height: 10),
          Text(
            'No upcoming appointments',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
