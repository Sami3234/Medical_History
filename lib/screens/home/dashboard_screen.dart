import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../models/doctor_model.dart';
import '../../models/member_model.dart';
import '../../services/member_doctor_service.dart';
import '../../services/owner_profile_service.dart';
import '../../services/offline_data_service.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/tree_view.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_logo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _memberDoctorService = MemberDoctorService();
  final _ownerProfileService = OwnerProfileService();
  Map<String, List<DoctorModel>> _memberDoctors = {};
  late bool _checkingOwner;

  @override
  void initState() {
    super.initState();
    final uid =
        context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
    final hasCachedMembers = context.read<MemberProvider>().members.isNotEmpty ||
        (uid != null && OfflineDataService.getMembers(uid).isNotEmpty);
    final hasCachedOwner =
        uid != null && OfflineDataService.getOwner(uid) != null;

    _checkingOwner =
        !OwnerProfileService.homePrefetchFinished &&
        !hasCachedMembers &&
        !hasCachedOwner &&
        OwnerProfileService.verifiedOwnerUserId != uid;

    if (uid != null) {
      final cachedMapping = OfflineDataService.getMemberDoctors(uid);
      if (cachedMapping.isNotEmpty) {
        _memberDoctors = cachedMapping;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _loadMemberDoctors(
    List<MemberModel> members, [
    String? userId,
  ]) async {
    final uid =
        userId ??
        context.read<AuthProvider>().uid ??
        SupabaseConfig.currentUserId;
    try {
      final mapping = await _memberDoctorService
          .getDoctorsForMembers(
            members.map((member) => member.id).toList(),
          )
          .timeout(AppNetwork.quickTimeout);
      if (mapping.isNotEmpty) {
        if (mounted) setState(() => _memberDoctors = mapping);
        if (uid != null) {
          await OfflineDataService.saveMemberDoctors(uid, mapping);
        }
      }
    } catch (_) {}
  }

  Future<void> _initializeDashboard() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid ?? SupabaseConfig.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _checkingOwner = false);
      return;
    }

    final memberProvider = context.read<MemberProvider>();
    final familyProvider = context.read<FamilyProvider>();
    final doctorProvider = context.read<DoctorProvider>();

    try {
      if (OwnerProfileService.verifiedOwnerUserId != uid) {
        final cachedOwner = OfflineDataService.getOwner(uid);
        if (cachedOwner != null &&
            _ownerProfileService.isComplete(cachedOwner)) {
          OwnerProfileService.verifiedOwnerUserId = uid;
        } else {
          final owner = await _ownerProfileService
              .getOwnerMember(uid)
              .timeout(AppNetwork.quickTimeout);
          if (!mounted) return;
          if (!_ownerProfileService.isComplete(owner)) {
            context.go(AppRoutes.ownerSetup);
            return;
          }
          OwnerProfileService.verifiedOwnerUserId = uid;
        }
      }

      // Revalidate in parallel with short timeout, never blocking UI
      Future.wait([
        familyProvider.loadFamilies(uid),
        doctorProvider.loadDoctors(uid),
        memberProvider.loadAll(uid),
      ]).timeout(AppNetwork.quickTimeout).then((_) {
        if (mounted && memberProvider.members.isNotEmpty) {
          _loadMemberDoctors(memberProvider.members, uid);
        }
      }).catchError((_) {});
    } catch (_) {
      // Fast fallback on slow connection
    } finally {
      if (mounted) setState(() => _checkingOwner = false);
    }

    if (memberProvider.members.isNotEmpty) {
      _loadMemberDoctors(memberProvider.members, uid);
    }
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
    return _buildDashboardContent(context);
  }

  Widget _buildDashboardContent(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final memberProv = context.watch<MemberProvider>();
    final healthProv = context.watch<HealthProvider>();
    final recordsProv = context.watch<RecordsProvider>();
    final notificationInbox = context.watch<NotificationInboxProvider>();

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
    final notifications = notificationInbox.buildItems(
      appointments: recordsProv.appointments,
      documents: recordsProv.files,
      members: members,
    );
    final unreadNotifications = notificationInbox.unreadCount(notifications);

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
            try {
              await Future.wait([
                familyProv.loadFamilies(uid),
                context.read<DoctorProvider>().loadDoctors(uid),
                memberProv.loadAll(uid),
              ]).timeout(AppNetwork.dataTimeout);
              await _loadMemberDoctors(
                memberProv.members,
              ).timeout(AppNetwork.dataTimeout);
            } catch (_) {}
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
                  unreadNotifications: unreadNotifications,
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
                        child: _familyTreeBody(
                          loading:
                              familyProv.loading || memberProv.loading,
                          members: memberProv.members,
                          error: memberProv.error ?? familyProv.error,
                          tree: InteractiveTreeView(
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
    required int unreadNotifications,
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
            colors: [
              Color(0xFF267310), // Deep rich emerald
              Color(0xFF388E18), // Primary dark medical green
              Color(0xFF4FA023), // Primary vibrant green
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F1B5E20),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Elegant translucent ambient accents (clean, crisp, zero milky blur)
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: -55,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB9EB80).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              left: -35,
              bottom: -45,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
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
              decoration: const BoxDecoration(
                borderRadius: bottomRadius,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0x33FFFFFF),
                    width: 1.0,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppLogo(
                        size: 20,
                        isTransparent: true,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Medical History',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      _glassHeaderAction(
                        icon: Icons.notifications_none_rounded,
                        badgeCount: unreadNotifications,
                        tooltip: 'Notifications',
                        onTap: () => context.push(AppRoutes.notificationCenter),
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
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
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
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFDFEAE0),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('dashboard-search-bar'),
                        onTap: () => context.push(AppRoutes.search),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: AppColors.textLight,
                                size: 22,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Search family, doctors or reports...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.tune_rounded,
                                color: AppColors.textLight,
                                size: 20,
                              ),
                            ],
                          ),
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 21),
                if (badgeCount > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.1,
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

  Widget _familyTreeBody({
    required bool loading,
    required List<MemberModel> members,
    required String? error,
    required Widget tree,
  }) {
    if (loading && members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (members.isEmpty && error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.appTextSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load your family. Check your connection, then pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }
    if (members.isEmpty) return _buildEmptyTree();
    return tree;
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
              accent: const Color(0xFF2C6B14),
              surface: const Color(0xFFEBF7E4),
              onTap: () => context.push(AppRoutes.visits),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.local_hospital_outlined,
              label: 'Doctors',
              accent: const Color(0xFF388E18),
              surface: const Color(0xFFF2FBF0),
              onTap: () => context.push(AppRoutes.doctors),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.description_outlined,
              label: 'Documents',
              accent: const Color(0xFF4FA023),
              surface: const Color(0xFFEAF8EE),
              onTap: () => context.push(AppRoutes.documents),
            ),
            _quickLink(
              width: itemWidth,
              horizontal: useTwoColumns,
              icon: Icons.event_available_outlined,
              label: 'Appointments',
              accent: const Color(0xFF1B5E20),
              surface: const Color(0xFFEDF7EB),
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
          ),
        if (membersNeedingEmergency > 0) const SizedBox(height: 10),
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
