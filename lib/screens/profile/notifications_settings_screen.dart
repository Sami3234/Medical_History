import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../utils/extensions.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _masterNotifications = true;
  bool _appointmentReminders = true;
  bool _medicationAlerts = true;
  bool _labReportAlerts = true;
  bool _emergencyAlerts = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _masterNotifications = prefs.getBool('notif_master') ?? true;
        _appointmentReminders = prefs.getBool('notif_appointments') ?? true;
        _medicationAlerts = prefs.getBool('notif_meds') ?? true;
        _labReportAlerts = prefs.getBool('notif_reports') ?? true;
        _emergencyAlerts = prefs.getBool('notif_emergency') ?? true;
        _soundEnabled = prefs.getBool('notif_sound') ?? true;
        _vibrationEnabled = prefs.getBool('notif_vibrate') ?? true;
      });
    }
  }

  Future<void> _savePref(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Switch Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _masterNotifications
                        ? AppColors.primary.withAlpha(80)
                        : AppColors.border,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _masterNotifications
                            ? AppColors.surface
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _masterNotifications
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: _masterNotifications
                            ? AppColors.primary
                            : Colors.grey,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allow Notifications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Receive reminders and medical updates',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _masterNotifications,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _masterNotifications = val);
                        _savePref('notif_master', val);
                        context.showSnack(
                          val
                              ? 'Notifications turned on.'
                              : 'Notifications paused.',
                          isError: false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reminder Preferences
              _buildSectionHeader('REMINDER PREFERENCES'),
              const SizedBox(height: 10),
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildToggleTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'Doctor Appointments',
                      subtitle:
                          'Alerts 24 hours & 2 hours before scheduled visits',
                      value: _masterNotifications && _appointmentReminders,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _appointmentReminders = val);
                        _savePref('notif_appointments', val);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleTile(
                      icon: Icons.medication_rounded,
                      title: 'Medication Reminders',
                      subtitle: 'Daily dose alerts and refill reminders',
                      value: _masterNotifications && _medicationAlerts,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _medicationAlerts = val);
                        _savePref('notif_meds', val);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleTile(
                      icon: Icons.description_rounded,
                      title: 'Lab Reports & Documents',
                      subtitle:
                          'Notifications when new lab reports are uploaded',
                      value: _masterNotifications && _labReportAlerts,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _labReportAlerts = val);
                        _savePref('notif_reports', val);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleTile(
                      icon: Icons.emergency_rounded,
                      title: 'Emergency Blood Group Notices',
                      subtitle: 'Urgent family medical alerts',
                      value: _masterNotifications && _emergencyAlerts,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _emergencyAlerts = val);
                        _savePref('notif_emergency', val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Alert Sound & Vibration
              _buildSectionHeader('SOUND & HAPTICS'),
              const SizedBox(height: 10),
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildToggleTile(
                      icon: Icons.volume_up_rounded,
                      title: 'Notification Sound',
                      subtitle: 'Play sound for reminders',
                      value: _masterNotifications && _soundEnabled,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _soundEnabled = val);
                        _savePref('notif_sound', val);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleTile(
                      icon: Icons.vibration_rounded,
                      title: 'Vibration',
                      subtitle: 'Vibrate device for critical health reminders',
                      value: _masterNotifications && _vibrationEnabled,
                      enabled: _masterNotifications,
                      onChanged: (val) {
                        setState(() => _vibrationEnabled = val);
                        _savePref('notif_vibrate', val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.primary,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.2),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled ? AppColors.surface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: enabled ? AppColors.primary : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: enabled ? AppColors.textDark : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
