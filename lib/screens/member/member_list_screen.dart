import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../models/doctor_model.dart';
import '../../models/member_model.dart';
import '../../services/member_doctor_service.dart';
import '../../services/owner_profile_service.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/tree_view.dart';
import '../../widgets/family_grouped_list_view.dart';
import '../../widgets/view_toggle_pill.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  bool _isTreeView = true;
  Map<String, List<DoctorModel>> _memberDoctors = {};
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final uid =
        context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
    if (uid != null) {
      await context.read<MemberProvider>().loadAll(uid);
      final members = context.read<MemberProvider>().members;
      await _loadMemberDoctors(members);
      try {
        final profile = await OwnerProfileService().getProfile(uid);
        if (mounted && profile?.name != null) {
          setState(() => _ownerName = profile!.name);
        }
      } catch (_) {}
    }
  }

  Future<void> _loadMemberDoctors(List<MemberModel> members) async {
    if (members.isEmpty) return;
    try {
      final map = await MemberDoctorService().getDoctorsForMembers(
        members.map((m) => m.id).toList(),
      );
      if (mounted) setState(() => _memberDoctors = map);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final authProv = context.watch<AuthProvider>();
    final members = memberProv.members;
    final userName = authProv.profile?.fullName ?? 'Family';

    return Scaffold(
      backgroundColor: context.appBackground,
      body: Column(
        children: [
          // ── Gradient Header with Title, Back Button & Pill Toggle ───
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Circular back button
                        GestureDetector(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.dashboard),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: Color(0xFF172B21),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Family members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Top Right: [ Tree | List ] Pill Toggle
                        ViewTogglePill(
                          isTreeView: _isTreeView,
                          onChanged: (val) => setState(() => _isTreeView = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Tap a person to see their visits, doctors, and documents',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body: Tree or Grouped List ──────────────────────────────
          Expanded(
            child: memberProv.loading && members.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: _isTreeView
                        // Mode 1: Untouched Interactive Tree View
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
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
                            child: InteractiveTreeView(
                              members: members,
                              memberDoctors: _memberDoctors,
                              currentUserName: userName,
                              familyName: _ownerName ?? userName,
                              showToolbar: false,
                              onMemberTap: (member) async {
                                await context.push('/members/${member.id}');
                                await _loadMemberDoctors(members);
                              },
                              onAddMember: () =>
                                  context.push(AppRoutes.memberAdd),
                            ),
                          )
                        // Mode 2: Beautiful Grouped List View
                        : FamilyGroupedListView(
                            members: members,
                            onMemberTap: (member) async {
                              await context.push('/members/${member.id}');
                              await _loadMemberDoctors(members);
                            },
                            onAddMember: () =>
                                context.push(AppRoutes.memberAdd),
                          ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
