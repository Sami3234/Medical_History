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
import '../../widgets/bottom_nav.dart';
import '../../widgets/hero_health_card.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/tree_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.uid ?? SupabaseConfig.currentUserId ?? 'usr-100';
      context.read<FamilyProvider>().loadFamilies(uid);
      context.read<VisitProvider>().loadRecent(uid);
      context.read<DoctorProvider>().loadDoctors(uid);
      context.read<MemberProvider>().loadAll(uid);
    });
  }

  /// Build tree nodes from live family / member data
  List<TreeNode> _buildFamilyTree(
    FamilyProvider familyProv,
    MemberProvider memberProv,
  ) {
    return familyProv.families.map((family) {
      final members = memberProv.members
          .where((m) => m.familyId == family.id)
          .toList();

      final memberNodes = members.map((m) {
        final initials = m.name.trim().split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
        return TreeNode(
          id: 'member-${m.id}',
          label: '${m.name} (${m.relation})',
          icon: Icons.person_rounded,
          badge: initials,
          onTap: () => context.push('/members/${m.id}'),
        );
      }).toList();

      return TreeNode(
        id: 'family-${family.id}',
        label: family.name,
        icon: Icons.family_restroom_rounded,
        badge: '${members.length}',
        children: memberNodes,
        onTap: () => context.push('/families/${family.id}'),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final visitProv = context.watch<VisitProvider>();
    final memberProv = context.watch<MemberProvider>();

    final user = auth.user;
    final userName = user?.fullName ?? 'Ahmed';
    final userFirstName = userName.split(' ').first;
    final initials = userName.trim().split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
    final primaryFamily = familyProv.families.isNotEmpty ? familyProv.families.first : null;
    final visits = visitProv.visits;

    // Dynamic greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    final treeNodes = _buildFamilyTree(familyProv, memberProv);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            final uid = auth.uid ?? SupabaseConfig.currentUserId ?? 'usr-100';
            await Future.wait([
              familyProv.loadFamilies(uid),
              visitProv.loadRecent(uid),
              memberProv.loadAll(uid),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDEF2D7),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials.isEmpty ? 'AK' : initials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF235E1E),
                        ),
                      ),
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
                        Icon(Icons.search_rounded,
                            color: AppColors.textLight, size: 22),
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
                  title: primaryFamily?.name ?? 'Ahmed Family',
                  subtitle:
                      '${primaryFamily?.familyId ?? "FAM-1001"} • ${memberProv.count} members',
                  avatarInitials: const ['AH', 'SA', 'AL', 'AY'],
                  actionText: 'View family',
                  onAction: () {
                    final famId = primaryFamily?.id ?? 'fam-1';
                    context.push('/families/$famId');
                  },
                ),
                const SizedBox(height: 28),

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
                      onPressed: () => context.push(AppRoutes.families),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add_rounded,
                          size: 15, color: AppColors.primary),
                      label: const Text(
                        'Add family',
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
                  'Tap a node to view details. Tap ▾ to expand.',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
                const SizedBox(height: 12),

                // Tree Card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      : treeNodes.isEmpty
                          ? _buildEmptyTree()
                          : InteractiveTreeView(nodes: treeNodes),
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
                    final uid = auth.uid ?? SupabaseConfig.currentUserId ?? 'usr-100';
                    visitProv.loadRecent(uid);
                  }),

                // Visits list
                if (visitProv.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
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
                    final ini = rawName
                        .trim()
                        .split(' ')
                        .where((p) => p.isNotEmpty)
                        .map((p) => p[0])
                        .take(2)
                        .join()
                        .toUpperCase();
                    final docDesc = v.doctorName != null
                        ? 'Dr. ${v.doctorName}'
                        : 'Routine Checkup';
                    final diagDesc =
                        v.diagnosis != null ? ' • ${v.diagnosis}' : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildVisitItem(
                        initials: ini.isNotEmpty ? ini : 'PT',
                        name: rawName,
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
          Icon(Icons.account_tree_rounded,
              size: 40, color: AppColors.textLight.withAlpha(120)),
          const SizedBox(height: 8),
          const Text(
            'No families yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => context.push(AppRoutes.familyAdd),
            child: const Text(
              'Tap here to add your first family',
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
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 18),
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
    required String initials,
    required String name,
    required String subtitle,
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
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFDEF2D7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF235E1E),
                ),
              ),
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
