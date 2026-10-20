import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/records_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/hero_health_card.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/tree_view.dart';
import '../../widgets/app_avatar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _lastSync;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final uid = auth.uid ?? SupabaseConfig.currentUserId;
      if (uid == null) return;
      await Future.wait([
        context.read<FamilyProvider>().loadFamilies(uid),
        context.read<VisitProvider>().loadRecent(uid),
        context.read<DoctorProvider>().loadDoctors(uid),
        context.read<MemberProvider>().loadAll(uid),
      ]);
      if (mounted) setState(() => _lastSync = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final visitProv = context.watch<VisitProvider>();
    final memberProv = context.watch<MemberProvider>();
    final healthProv = context.watch<HealthProvider>();
    final recordsProv = context.watch<RecordsProvider>();

    final user = auth.user;
    final userName = user?.fullName ?? 'User';
    final userFirstName = userName.split(' ').first;
    final primaryFamily = familyProv.families.isNotEmpty
        ? familyProv.families.first
        : null;
    final visits = visitProv.visits;
    final primaryMember = memberProv.members.isEmpty
        ? null
        : memberProv.members.first;
    final activeMedicationCount = primaryMember == null
        ? 0
        : healthProv
              .getMedicationsByMember(primaryMember.id)
              .where((item) => item.isActive)
              .length;
    final vitalCount = primaryMember == null
        ? 0
        : healthProv.getVitalsByMember(primaryMember.id).length;
    final upcomingAppointments = recordsProv.appointments
        .where(
          (item) =>
              item.dateTime.isAfter(DateTime.now()) &&
              item.status != 'cancelled',
        )
        .length;

    // Dynamic greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            final uid = auth.uid ?? SupabaseConfig.currentUserId;
            if (uid == null) return;
            await Future.wait([
              familyProv.loadFamilies(uid),
              visitProv.loadRecent(uid),
              memberProv.loadAll(uid),
            ]);
            if (mounted) setState(() => _lastSync = DateTime.now());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (SupabaseConfig.db == null)
                  _buildStatusBanner(
                    'Offline mode: showing locally saved records',
                    Icons.cloud_off_outlined,
                  ),
                if (_lastSync != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Last synced ${DateFormat('h:mm a').format(_lastSync!.toLocal())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                // ── Top Header ──────────────────────────────────────────
                Row(
                  children: [
                    AppAvatar(
                      name: userName,
                      avatarUrl: user?.avatarUrl,
                      size: 48,
                      border: Border.all(
                        color: const Color(0xFF4ADE80),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      onTap: () => context.push(AppRoutes.profile),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $userFirstName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification bell
                    GestureDetector(
                      onTap: () => context.push('/appointments'),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textDark,
                              size: 24,
                            ),
                            Positioned(
                              top: 10,
                              right: 12,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5CB82C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── Search Bar ──────────────────────────────────────────
                InkWell(
                  onTap: () => context.push(AppRoutes.search),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.textLight,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Search family, doctors or reports...',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // ── Section: Family Health Space ─────────────────────────
                const Text(
                  'Your family, your care.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),

                HeroHealthCard(
                  tag: 'FAMILY HEALTH SPACE',
                  title: primaryFamily?.name ?? '$userFirstName Family',
                  subtitle: '${memberProv.count} family members registered',
                  actionText: 'View members',
                  onAction: () => context.push(AppRoutes.members),
                ),
                const SizedBox(height: 28),

                _buildHealthSummary(
                  member: primaryMember,
                  activeMedicationCount: activeMedicationCount,
                  vitalCount: vitalCount,
                  upcomingAppointments: upcomingAppointments,
                ),
                const SizedBox(height: 20),

                // ── Section: Family Tree ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Family tree',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.memberAdd),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        Icons.person_add_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'Add member',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hierarchical family tree with relationship ordering & age',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
                const SizedBox(height: 12),

                // Tree Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: familyProv.loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : memberProv.members.isEmpty
                      ? _buildEmptyTree()
                      : InteractiveTreeView(
                          members: memberProv.members,
                          familyName:
                              primaryFamily?.name ?? '$userFirstName Family',
                          onMemberTap: (m) => context.push('/members/${m.id}'),
                          onAddMember: () => context.push(AppRoutes.memberAdd),
                        ),
                ),
                const SizedBox(height: 28),

                // ── Section: Recent doctor visits ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent doctor visits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.visits),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Error banner for visit loading
                if (visitProv.error != null)
                  _buildErrorBanner(visitProv.error!, () {
                    final uid = auth.uid ?? SupabaseConfig.currentUserId;
                    if (uid != null) visitProv.loadRecent(uid);
                  }),

                // Visits list
                if (visitProv.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (visits.isEmpty)
                  _buildVisitItem(
                    initials: 'AL',
                    name: 'No recent visits',
                    subtitle: 'Tap + to add a visit record',
                    onTap: () => context.push(AppRoutes.visitAdd),
                  )
                else
                  ...visits.take(3).map((v) {
                    final rawName = v.memberName ?? 'Family Member';
                    final docDesc = v.doctorName != null
                        ? 'Dr. ${v.doctorName}'
                        : 'Routine Checkup';
                    final diagDesc = v.diagnosis != null
                        ? ' • ${v.diagnosis}'
                        : '';
                    final member = memberProv.members
                        .where(
                          (m) =>
                              m.id == v.memberId ||
                              m.name.toLowerCase() == rawName.toLowerCase(),
                        )
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildVisitItem(
                        name: rawName,
                        avatarUrl: member?.avatarUrl,
                        subtitle: '$docDesc$diagDesc',
                        onTap: () => context.push('/visits/${v.id}'),
                      ),
                    );
                  }),
                const SizedBox(height: 10),

                // Info Banner
                InfoBanner(
                  icon: Icons.verified_user_outlined,
                  title: 'Next follow-up',
                  subtitle: 'Check upcoming appointments for reminders.',
                  onTap: () => context.push('/appointments'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _buildEmptyTree() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(
            Icons.family_restroom_rounded,
            size: 40,
            color: AppColors.textLight.withAlpha(120),
          ),
          const SizedBox(height: 8),
          const Text(
            'No family members yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => context.push(AppRoutes.memberAdd),
            child: const Text(
              'Tap here to add your first member (Self, Parent, Child)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSummary({
    required dynamic member,
    required int activeMedicationCount,
    required int vitalCount,
    required int upcomingAppointments,
  }) {
    final hasEmergency =
        member?.bloodGroup != null ||
        (member?.emergencyContact as String?)?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health at a glance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        if (hasEmergency)
          _buildStatusBanner(
            'Emergency: ${member.bloodGroup ?? 'Blood group not set'}${member.emergencyContact == null ? '' : ' • ${member.emergencyContact}'}',
            Icons.emergency_outlined,
          ),
        if (!hasEmergency)
          _buildStatusBanner(
            'Add blood group and emergency contact to protect your family.',
            Icons.health_and_safety_outlined,
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            _summaryTile(
              'Medicines',
              '$activeMedicationCount',
              Icons.medication_outlined,
            ),
            const SizedBox(width: 8),
            _summaryTile('Vitals', '$vitalCount', Icons.monitor_heart_outlined),
            const SizedBox(width: 8),
            _summaryTile(
              'Upcoming',
              '$upcomingAppointments',
              Icons.event_available_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.textMid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE53935),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB71C1C)),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitItem({
    required String name,
    required String subtitle,
    String? avatarUrl,
    String? initials,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AppAvatar(
              name: name,
              avatarUrl: avatarUrl,
              size: 48,
              border: Border.all(color: AppColors.border),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
