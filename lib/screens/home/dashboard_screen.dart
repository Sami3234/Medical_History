import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final visitProv = context.watch<VisitProvider>();

    final user = auth.user;
    final userName = user?.fullName ?? 'Ahmed';
    final userFirstName = userName.split(' ').first;
    final primaryFamily = familyProv.families.isNotEmpty ? familyProv.families.first : null;
    final visits = visitProv.visits;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
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
                      'AK',
                      style: TextStyle(
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
                          'Good morning, $userFirstName!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Friday, 16 October 2026',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Bell with Badge
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

              // Search Bar
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
                      Icon(Icons.search_rounded, color: AppColors.textLight, size: 22),
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

              // Section: Your family, your care.
              const Text(
                'Your family, your care.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),

              // Hero Family Health Space Card
              HeroHealthCard(
                tag: 'FAMILY HEALTH SPACE',
                title: primaryFamily?.name ?? 'Ahmed Family',
                subtitle: '${primaryFamily?.familyId ?? "FAM-1001"} • 4 members',
                avatarInitials: const ['AH', 'SA', 'AL', 'AY'],
                actionText: 'View family',
                onAction: () {
                  final famId = primaryFamily?.id ?? 'fam-1';
                  context.push('/families/$famId');
                },
              ),
              const SizedBox(height: 28),

              // Section: Recent doctor visits
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

              // Visits list
              if (visits.isEmpty)
                _buildVisitItem(
                  initials: 'AL',
                  name: 'Ali Ahmed',
                  subtitle: 'Dr. Sana Malik • Pediatrician',
                  onTap: () => context.push(AppRoutes.visits),
                )
              else
                ...visits.take(3).map((v) {
                  final rawName = v.memberName ?? 'Family Member';
                  final initials = rawName.trim().split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
                  final docDesc = v.doctorName != null ? 'Dr. ${v.doctorName}' : 'Routine Checkup';
                  final diagDesc = v.diagnosis != null ? ' • ${v.diagnosis}' : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVisitItem(
                      initials: initials.isNotEmpty ? initials : 'PT',
                      name: rawName,
                      subtitle: '$docDesc$diagDesc',
                      onTap: () => context.push('/visits/${v.id}'),
                    ),
                  );
                }),
              const SizedBox(height: 10),

              // Info Follow-up Banner
              InfoBanner(
                icon: Icons.verified_user_outlined,
                title: 'Next follow-up',
                subtitle: 'Ali\'s appointment is on 21 Oct at 11:30 AM.',
                onTap: () => context.push('/appointments'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
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
