import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/records_provider.dart';
import '../../models/doctor_model.dart';
import '../../models/member_model.dart';
import '../../services/member_doctor_service.dart';
import '../../services/owner_profile_service.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/tree_view.dart';
import '../../widgets/app_avatar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static String? _verifiedOwnerUserId;

  final _memberDoctorService = MemberDoctorService();
  final _ownerProfileService = OwnerProfileService();
  Map<String, List<DoctorModel>> _memberDoctors = {};
  late bool _checkingOwner;

  Future<void> _loadMemberDoctors(List<MemberModel> members) async {
    final mapping = await _memberDoctorService.getDoctorsForMembers(
      members.map((member) => member.id).toList(),
    );
    if (mounted) setState(() => _memberDoctors = mapping);
  }

  @override
  void initState() {
    super.initState();
    final uid =
        context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
    final hasCachedMembers = context.read<MemberProvider>().members.isNotEmpty;
    _checkingOwner = !hasCachedMembers && _verifiedOwnerUserId != uid;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid ?? SupabaseConfig.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _checkingOwner = false);
      return;
    }

    final memberProvider = context.read<MemberProvider>();
    final hasCachedMembers = memberProvider.members.isNotEmpty;
    if (hasCachedMembers && _checkingOwner && mounted) {
      setState(() => _checkingOwner = false);
    }

    if (_verifiedOwnerUserId != uid) {
      final owner = await _ownerProfileService.getOwnerMember(uid);
      if (!mounted) return;
      if (!_ownerProfileService.isComplete(owner)) {
        context.go(AppRoutes.ownerSetup);
        return;
      }
      _verifiedOwnerUserId = uid;
    }

    if (hasCachedMembers) {
      await _loadMemberDoctors(memberProvider.members);
      return;
    }

    await Future.wait([
      context.read<FamilyProvider>().loadFamilies(uid),
      context.read<DoctorProvider>().loadDoctors(uid),
      memberProvider.loadAll(uid),
    ]);
    await _loadMemberDoctors(memberProvider.members);
    if (mounted) {
      setState(() => _checkingOwner = false);
    }
  }

  Widget buildSampleDashboard(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final memberProv = context.watch<MemberProvider>();
    final doctorProv = context.watch<DoctorProvider>();
    final members = memberProv.members;
    final generations = members
        .map((member) => FamilyGeneration.fromRelation(member.relation))
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            final uid = auth.uid ?? SupabaseConfig.currentUserId;
            if (uid == null) return;
            await Future.wait([
              familyProv.loadFamilies(uid),
              context.read<DoctorProvider>().loadDoctors(uid),
              memberProv.loadAll(uid),
            ]);
            await _loadMemberDoctors(memberProv.members);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _buildDashboardHero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDashboardStatPill(
                              icon: Icons.account_tree_rounded,
                              value: '$generations',
                              label: 'Generations',
                              color: const Color(0xFF167A55),
                              background: const Color(0xFFE3F5EA),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDashboardStatPill(
                              icon: Icons.groups_rounded,
                              value: '${members.length}',
                              label: 'Members',
                              color: const Color(0xFF36566A),
                              background: const Color(0xFFF0F5F8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDashboardStatPill(
                              icon: Icons.medical_services_outlined,
                              value: '${doctorProv.doctors.length}',
                              label: 'Doctors',
                              color: const Color(0xFF36566A),
                              background: const Color(0xFFF0F5F8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2ECE6)),
                        ),
                        child: familyProv.loading
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              )
                            : members.isEmpty
                            ? _buildEmptyTree()
                            : InteractiveTreeView(
                                members: members,
                                memberDoctors: _memberDoctors,
                                currentUserName: auth.user?.fullName,
                                familyName: auth.user?.fullName ?? 'Family',
                                showToolbar: false,
                                showRootNode: false,
                                onMemberTap: (member) async {
                                  await context.push('/members/${member.id}');
                                  await _loadMemberDoctors(memberProv.members);
                                },
                              ),
                      ),
                      const SizedBox(height: 18),
                      _buildAssignedDoctorsDashboard(doctorProv),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _buildDashboardHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF075B3F), Color(0xFF1A936F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
              color: Colors.white.withAlpha(25),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Together for a Healthier Tomorrow',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _dashboardIconButton(
            icon: Icons.search_rounded,
            onTap: () => context.push(AppRoutes.search),
          ),
          const SizedBox(width: 8),
          _dashboardIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
    );
  }

  Widget _dashboardIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildDashboardStatPill({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withAlpha(35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$value $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDoctorsDashboard(DoctorProvider doctorProv) {
    final doctors = doctorProv.doctors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCDE5FA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_rounded,
                color: Color(0xFF1769AA),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assigned Doctors (${doctors.length})',
                  style: const TextStyle(
                    color: Color(0xFF145B91),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.doctors),
                child: const Text('View all'),
              ),
            ],
          ),
          if (doctors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No doctors added yet.'),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: doctors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return InkWell(
                    onTap: () => context.push('/doctors/${doctor.id}'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 145,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD7E8F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(name: doctor.name, size: 44),
                          const SizedBox(height: 8),
                          Text(
                            doctor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor.specialization ??
                                'Specialization not recorded',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOwner) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return buildLegacyDashboard(context);
  }

  Widget buildLegacyDashboard(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final memberProv = context.watch<MemberProvider>();
    final healthProv = context.watch<HealthProvider>();
    final recordsProv = context.watch<RecordsProvider>();

    final user = auth.user;
    final userName = user?.fullName ?? 'User';
    final userFirstName = userName.split(' ').first;
    final members = memberProv.members;
    final ownerName = members
        .where((member) => member.relation.toLowerCase().trim() == 'self')
        .map((member) => member.name)
        .firstOrNull;
    final activeMedicationCount = members.fold<int>(
      0,
      (sum, member) =>
          sum +
          healthProv
              .getMedicationsByMember(member.id)
              .where((item) => item.isActive)
              .length,
    );
    final vitalCount = members.fold<int>(
      0,
      (sum, member) => sum + healthProv.getVitalsByMember(member.id).length,
    );
    final upcomingAppointments = recordsProv.appointments
        .where(
          (item) =>
              item.dateTime.isAfter(DateTime.now()) &&
              item.status != 'cancelled',
        )
        .length;
    final membersNeedingEmergency = members
        .where(
          (m) =>
              m.bloodGroup == null &&
              (m.emergencyContact == null ||
                  m.emergencyContact!.trim().isEmpty),
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
          onRefresh: () async {
            final uid = auth.uid ?? SupabaseConfig.currentUserId;
            if (uid == null) return;
            await Future.wait([
              familyProv.loadFamilies(uid),
              context.read<DoctorProvider>().loadDoctors(uid),
              memberProv.loadAll(uid),
            ]);
            await _loadMemberDoctors(memberProv.members);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassDashboardHeader(
                  userName: userName,
                  avatarUrl: user?.avatarUrl,
                  greeting: greeting,
                  firstName: userFirstName,
                  date: dateStr,
                  upcomingAppointments: upcomingAppointments,
                ),
                if (SupabaseConfig.db == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildStatusBanner(
                      'Offline mode: showing locally saved records',
                      Icons.cloud_off_outlined,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical history hub',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your family, doctor visits, and documents in one place.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildQuickLinks(),
                      const SizedBox(height: 22),

                      _buildHealthSummary(
                        activeMedicationCount: activeMedicationCount,
                        vitalCount: vitalCount,
                        upcomingAppointments: upcomingAppointments,
                        membersNeedingEmergency: membersNeedingEmergency,
                      ),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Family members',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                      Text(
                        'Tap a person to see their visits, doctors, and documents',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
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
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.appBorder,
                            width: 1.2,
                          ),
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
                                memberDoctors: _memberDoctors,
                                currentUserName: userName,
                                familyName: ownerName ?? userName,
                                showToolbar: false,
                                onMemberTap: (member) async {
                                  await context.push('/members/${member.id}');
                                  await _loadMemberDoctors(memberProv.members);
                                },
                                onAddMember: () =>
                                    context.push(AppRoutes.memberAdd),
                              ),
                      ),
                      if (upcomingAppointments > 0) ...[
                        const SizedBox(height: 18),
                        InfoBanner(
                          icon: Icons.event_available_outlined,
                          title:
                              '$upcomingAppointments upcoming appointment(s)',
                          subtitle: 'Open calendar to review follow-ups.',
                          onTap: () => context.push('/appointments'),
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const BottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _buildGlassDashboardHeader({
    required String userName,
    required String? avatarUrl,
    required String greeting,
    required String firstName,
    required String date,
    required int upcomingAppointments,
  }) {
    const bottomRadius = BorderRadius.only(
      bottomLeft: Radius.circular(30),
      bottomRight: Radius.circular(30),
    );
    return ClipRRect(
      borderRadius: bottomRadius,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: bottomRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF168C45), Color(0xFF2AAF35), Color(0xFF65C93A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -44,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(28),
                ),
              ),
            ),
            Positioned(
              left: -38,
              bottom: -58,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB8F58C).withAlpha(38),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                18,
                18 + MediaQuery.paddingOf(context).top,
                18,
                18,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: bottomRadius,
                border: Border.all(color: Colors.white.withAlpha(190)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Medical History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      _glassHeaderAction(
                        icon: Icons.notifications_none_rounded,
                        badgeCount: upcomingAppointments,
                        tooltip: 'Notifications',
                        onTap: () => context.push(AppRoutes.notifications),
                      ),
                      const SizedBox(width: 8),
                      _glassHeaderAction(
                        icon: Icons.calendar_month_outlined,
                        badgeCount: upcomingAppointments,
                        tooltip: 'Appointments',
                        onTap: () => context.push(AppRoutes.appointments),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      AppAvatar(
                        name: userName,
                        avatarUrl: avatarUrl,
                        size: 52,
                        border: Border.all(color: Colors.white, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, $firstName!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push(AppRoutes.search),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(185),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0C6B45).withAlpha(15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Search members, visits or documents...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF62A48A),
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(165),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: const Color(0xFF174C3B), size: 22),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D67),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 7.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
            color: context.appTextSecondary.withAlpha(120),
          ),
          const SizedBox(height: 8),
          Text(
            'No family members yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
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

  Widget _buildQuickLinks() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth < 350;
        final columns = useTwoColumns ? 2 : 4;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.medical_services_outlined,
              label: 'Visits',
              accent: const Color(0xFF15803D),
              surface: const Color(0xFFEAF8EE),
              onTap: () => context.push(AppRoutes.visits),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.local_hospital_outlined,
              label: 'Doctors',
              accent: const Color(0xFF087EA4),
              surface: const Color(0xFFEAF8FD),
              onTap: () => context.push(AppRoutes.doctors),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.description_outlined,
              label: 'Documents',
              accent: const Color(0xFF7C3AED),
              surface: const Color(0xFFF4EFFF),
              onTap: () => context.push(AppRoutes.documents),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.event_available_outlined,
              label: 'Appointments',
              accent: const Color(0xFFEA7B16),
              surface: const Color(0xFFFFF4E8),
              onTap: () => context.push(AppRoutes.appointments),
            ),
          ],
        );
      },
    );
  }

  Widget _quickLink({
    required double width,
    required bool horizontal,
    required IconData icon,
    required String label,
    required Color accent,
    required Color surface,
    required VoidCallback onTap,
  }) {
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: horizontal ? 11 : 9.5,
        fontWeight: FontWeight.w700,
        color: context.appTextPrimary,
      ),
      textAlign: TextAlign.center,
    );

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 12 : 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.isDarkMode ? context.appSurfaceRaised : surface,
                context.appSurface,
              ],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: accent.withAlpha(35)),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(14),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Flex(
            direction: horizontal ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              SizedBox(width: horizontal ? 9 : 0, height: horizontal ? 0 : 6),
              if (horizontal) Flexible(child: labelWidget) else labelWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummary({
    required int activeMedicationCount,
    required int vitalCount,
    required int upcomingAppointments,
    required int membersNeedingEmergency,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Family health snapshot',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (membersNeedingEmergency > 0)
          _buildStatusBanner(
            '$membersNeedingEmergency member(s) still need blood group / emergency contact.',
            Icons.health_and_safety_outlined,
          )
        else
          _buildStatusBanner(
            'Emergency details look complete for your family.',
            Icons.verified_user_outlined,
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
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
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
              style: TextStyle(fontSize: 10, color: context.appTextSecondary),
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
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
