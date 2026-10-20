import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../models/member_model.dart';
import '../../models/vital_model.dart';
import '../../models/medication_model.dart';
import '../../models/vaccine_model.dart';
import '../../models/visit_model.dart';
import '../../models/med_file_model.dart';
import '../../models/doctor_model.dart';
import '../../providers/member_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../services/member_share_service.dart';
import '../../services/member_doctor_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/health_dialogs.dart';
import '../../widgets/medical_summary_sheet.dart';

class MemberDetailScreen extends StatefulWidget {
  final String id;
  const MemberDetailScreen({super.key, required this.id});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _uploadingPhoto = false;
  final _memberDoctorService = MemberDoctorService();
  List<DoctorModel> _memberDoctors = [];
  int _selectedTab =
      0; // 0: Vitals, 1: Medications, 2: Vaccines, 3: Visits, 4: Files
  late TabController _tabController;

  final List<String> _tabs = [
    'Vitals',
    'Medications',
    'Vaccines',
    'Visits',
    'Lab & Files',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _tabController.index != _selectedTab) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VisitProvider>().loadByMember(widget.id);
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) context.read<DoctorProvider>().loadDoctors(uid);
      _loadMemberDoctors();
    });
  }

  Future<void> _loadMemberDoctors() async {
    try {
      final doctors = await _memberDoctorService.getDoctors(widget.id);
      if (mounted) setState(() => _memberDoctors = doctors);
    } catch (_) {}
  }

  Future<void> _manageMemberDoctors(MemberModel member) async {
    final allDoctors = context.read<DoctorProvider>().doctors;
    if (allDoctors.isEmpty) {
      if (mounted)
        context.showSnack('Add a doctor profile first.', isError: true);
      return;
    }
    final selected = _memberDoctors.map((doctor) => doctor.id).toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${member.name} doctors'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allDoctors.map((doctor) {
                final checked = selected.contains(doctor.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(doctor.name),
                  subtitle: Text(doctor.specialization ?? 'General physician'),
                  onChanged: (value) async {
                    try {
                      if (value == true) {
                        await _memberDoctorService.addDoctor(
                          memberId: member.id,
                          doctorId: doctor.id,
                        );
                        selected.add(doctor.id);
                      } else {
                        await _memberDoctorService.removeDoctor(
                          memberId: member.id,
                          doctorId: doctor.id,
                        );
                        selected.remove(doctor.id);
                      }
                      setDialogState(() {});
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not update doctor assignment.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    await _loadMemberDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeMemberPhoto(MemberModel member) async {
    if (_uploadingPhoto) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final croppedBytes = await ImageCropperService.cropAvatar(
        file: picked,
        context: context,
      );
      if (croppedBytes == null || !mounted) return;

      // 1. Immediately cache in memory and local storage
      final dataUri = 'data:image/png;base64,${base64Encode(croppedBytes)}';
      AvatarMemoryCache.set(member.id, croppedBytes);
      AvatarMemoryCache.set(member.name, croppedBytes);
      AvatarMemoryCache.set(member.name.toLowerCase(), croppedBytes);
      AvatarMemoryCache.set(dataUri, croppedBytes);

      // 2. Immediately update member state so all screens reflect the photo instantly
      await context.read<MemberProvider>().updateMember(member.id, {
        'avatar_url': dataUri,
      });
      if (mounted) context.showSnack('Photo updated successfully!');

      // 3. Background cloud backup
      setState(() => _uploadingPhoto = true);
      final res = await CloudinaryService.uploadImage(
        bytes: croppedBytes,
        filename: picked.name,
        folder: 'medical_history/avatars',
      );

      if (res.success && res.secureUrl != null && mounted) {
        AvatarMemoryCache.set(res.secureUrl!, croppedBytes);
        await context.read<MemberProvider>().updateMember(member.id, {
          'avatar_url': res.secureUrl,
        });
      }
    } catch (e) {
      if (mounted) context.showSnack('Unable to update photo', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _logVital(String memberId) async {
    final vital = await AddVitalDialog.show(context, memberId);
    if (vital != null && mounted) {
      await context.read<HealthProvider>().addVital(vital);
      context.showSnack('Vital sign logged successfully!');
    }
  }

  Future<void> _addMedication(String memberId) async {
    final med = await AddMedicationDialog.show(context, memberId);
    if (med != null && mounted) {
      await context.read<HealthProvider>().addMedication(med);
      context.showSnack('Medication prescription added!');
    }
  }

  Future<void> _addVaccine(String memberId) async {
    final vac = await AddVaccineDialog.show(context, memberId);
    if (vac != null && mounted) {
      await context.read<HealthProvider>().addVaccine(vac);
      context.showSnack('Immunization record saved!');
    }
  }

  Future<void> _uploadFile(String memberId) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
        withData: true,
      );
      if (res == null || res.files.isEmpty || !mounted) return;
      final file = res.files.first;
      if (file.bytes == null) return;

      await context.read<RecordsProvider>().addDocument(
        memberId: memberId,
        title: file.name.split('.').first,
        fileType: 'labReport',
        fileName: file.name,
        bytes: file.bytes!,
      );
      if (mounted) context.showSnack('Medical file uploaded successfully!');
    } catch (_) {
      if (mounted) context.showSnack('Failed to upload file', isError: true);
    }
  }

  Future<void> _shareMember(MemberModel member) async {
    try {
      final scope = await _selectShareScope();
      if (scope == null) return;
      final token = await MemberShareService.createShareToken(
        memberId: member.id,
        scope: scope,
      );
      final link = Uri(
        scheme: 'io.supabase.medicalhistory',
        host: 'shared-member',
        queryParameters: {'token': token},
      ).toString();
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        await _showShareLinkDialog(member, link);
      }
    } catch (e) {
      if (mounted)
        context.showSnack('Unable to create share link', isError: true);
    }
  }

  Future<Map<String, bool>?> _selectShareScope() async {
    var profile = true;
    var visits = true;
    var documents = true;
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose records to share'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: profile,
                title: const Text('Member profile'),
                onChanged: (value) =>
                    setDialogState(() => profile = value ?? false),
              ),
              CheckboxListTile(
                value: visits,
                title: const Text('Doctor visits'),
                onChanged: (value) =>
                    setDialogState(() => visits = value ?? false),
              ),
              CheckboxListTile(
                value: documents,
                title: const Text('Documents'),
                onChanged: (value) =>
                    setDialogState(() => documents = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: profile || visits || documents
                  ? () => Navigator.pop(dialogContext, {
                      'profile': profile,
                      'visits': visits,
                      'documents': documents,
                    })
                  : null,
              child: const Text('Create link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShareLinkDialog(MemberModel member, String link) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Secure profile link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This read-only link expires in 7 days. It has already been copied.',
            ),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) context.showSnack('Share link copied');
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy again'),
            ),
            TextButton.icon(
              onPressed: () async {
                await MemberShareService.revokeAllShares(member.id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted)
                  context.showSnack('All active share links revoked');
              },
              icon: const Icon(Icons.link_off_outlined, color: Colors.red),
              label: const Text(
                'Revoke all active links',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final visitProv = context.watch<VisitProvider>();
    final recordsProv = context.watch<RecordsProvider>();
    final healthProv = context.watch<HealthProvider>();

    final members = memberProv.members;
    final member =
        members.where((m) => m.id == widget.id).firstOrNull ??
        (members.isNotEmpty ? members.first : null);

    if (member == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Member profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: memberProv.loading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_off_rounded,
                      size: 54,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Member profile not found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    final totalVisits = visitProv.visits.isNotEmpty
        ? visitProv.visits.length
        : 0;
    final totalFiles = recordsProv.files
        .where((f) => f.memberId == member.id)
        .length;
    final memberVitals = healthProv.getVitalsByMember(member.id);
    final memberMeds = healthProv.getMedicationsByMember(member.id);
    final memberVaccines = healthProv.getVaccinesByMember(member.id);
    final memberVisits = visitProv.visits
        .where((v) => v.memberId == member.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(member.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Emergency ICE Quick Trigger in AppBar
          IconButton(
            tooltip: 'Emergency ICE Card',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
            ),
            onPressed: () => EmergencyIceModal.show(context, member),
          ),
          // Share / Print Summary
          IconButton(
            tooltip: 'Medical Summary',
            icon: const Icon(
              Icons.description_outlined,
              color: AppColors.textDark,
            ),
            onPressed: () => MedicalSummarySheet.show(context, member),
          ),
          IconButton(
            tooltip: 'Share secure profile',
            icon: const Icon(Icons.share_outlined, color: AppColors.textDark),
            onPressed: () => _shareMember(member),
          ),
          // Edit Profile
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_outlined, color: AppColors.textDark),
            onPressed: () => context.push('/members/${member.id}/edit'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    // Green Hero Banner Card
                    _buildHeroCard(member),
                    const SizedBox(height: 14),

                    // Quick Actions Row (ICE Card, Summary, Timeline)
                    _buildQuickActionButtons(member),
                    const SizedBox(height: 16),

                    // Quick Stats Bar (Visits, Meds, Vitals, Files)
                    _buildStatsRow(
                      visitsCount: totalVisits,
                      medsCount: memberMeds.where((m) => m.isActive).length,
                      vitalsCount: memberVitals.length,
                      filesCount: totalFiles,
                    ),
                    const SizedBox(height: 18),
                    _buildAssignedDoctors(member),
                    const SizedBox(height: 18),

                    // Modern Segmented Pill Tabs Header
                    _buildSegmentedTabBar(),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildVitalsTab(member, memberVitals, healthProv),
              _buildMedicationsTab(member, memberMeds, healthProv),
              _buildVaccinesTab(member, memberVaccines, healthProv),
              _buildVisitsTab(member, memberVisits),
              _buildFilesTab(
                member,
                recordsProv.files
                    .where((f) => f.memberId == member.id)
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  // ── Hero Banner ────────────────────────────────────────────────────────
  Widget _buildHeroCard(MemberModel member) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _changeMemberPhoto(member),
                child: Stack(
                  children: [
                    AppAvatar(
                      name: member.name,
                      avatarUrl: member.avatarUrl,
                      memberId: member.id,
                      size: 68,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: _uploadingPhoto
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.relation.toUpperCase()} • PAT-${member.id.length > 5 ? member.id.substring(0, 4).toUpperCase() : member.id.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Badges row: Age, Blood Group, Active
          Row(
            children: [
              _buildHeroBadge(
                Icons.cake_outlined,
                member.age == 'N/A' ? '12 years' : member.age,
              ),
              const SizedBox(width: 8),
              _buildHeroBadge(
                Icons.bloodtype_outlined,
                member.bloodGroup ?? 'O+',
              ),
              const SizedBox(width: 8),
              _buildHeroBadge(Icons.verified_rounded, 'Active'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Action Buttons ───────────────────────────────────────────────
  Widget _buildQuickActionButtons(MemberModel member) {
    return Row(
      children: [
        // ICE Emergency Card
        Expanded(
          child: InkWell(
            onTap: () => EmergencyIceModal.show(context, member),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emergency_rounded,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ICE Card',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Export Medical Summary
        Expanded(
          child: InkWell(
            onTap: () => MedicalSummarySheet.show(context, member),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Full Timeline
        Expanded(
          child: InkWell(
            onTap: () => context.push('/visits'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedDoctors(MemberModel member) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Assigned doctors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _manageMemberDoctors(member),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          if (_memberDoctors.isEmpty)
            const Text(
              'No doctors assigned yet. Add the doctors this member visits.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _memberDoctors
                  .map(
                    (doctor) => Chip(
                      avatar: const Icon(Icons.person_outline, size: 17),
                      label: Text(doctor.name),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ── Quick Stats Row ───────────────────────────────────────────────────
  Widget _buildStatsRow({
    required int visitsCount,
    required int medsCount,
    required int vitalsCount,
    required int filesCount,
  }) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            'Visits',
            visitsCount.toString(),
            Icons.medical_services_outlined,
          ),
          _statDivider(),
          _statItem(
            'Active Meds',
            medsCount.toString(),
            Icons.medication_outlined,
          ),
          _statDivider(),
          _statItem('Vitals', vitalsCount.toString(), Icons.speed_rounded),
          _statDivider(),
          _statItem('Files', filesCount.toString(), Icons.folder_outlined),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              value.padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 24, color: AppColors.border);
  }

  // ── Segmented Tab Bar ─────────────────────────────────────────────────
  Widget _buildSegmentedTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMid,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: _tabs.map((name) => Tab(text: name)).toList(),
      ),
    );
  }

  // ── Tab 1: Vitals View ────────────────────────────────────────────────
  Widget _buildVitalsTab(
    MemberModel member,
    List<VitalModel> vitals,
    HealthProvider healthProv,
  ) {
    final bp = healthProv.getLatestVital(member.id, 'Blood Pressure');
    final sugar = healthProv.getLatestVital(member.id, 'Blood Sugar');
    final hr = healthProv.getLatestVital(member.id, 'Heart Rate');
    final spo2 = healthProv.getLatestVital(member.id, 'Oxygen');
    final weight = healthProv.getLatestVital(member.id, 'Weight');
    final temp = healthProv.getLatestVital(member.id, 'Temperature');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with Log Vital button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Vital Signs',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _logVital(member.id),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Log Vital',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Vitals Grid (2x3)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _buildVitalGridCard(
                title: 'Blood Pressure',
                value: bp?.value ?? 'Not recorded',
                unit: bp?.unit ?? '',
                icon: Icons.speed_rounded,
                color: const Color(0xFFEF4444),
                status: bp?.status ?? 'Not recorded',
                recordedAt: bp?.recordedAt,
              ),
              _buildVitalGridCard(
                title: 'Blood Sugar',
                value: sugar?.value ?? 'Not recorded',
                unit: sugar?.unit ?? '',
                icon: Icons.bloodtype_rounded,
                color: const Color(0xFFF59E0B),
                status: sugar?.status ?? 'Not recorded',
                recordedAt: sugar?.recordedAt,
              ),
              _buildVitalGridCard(
                title: 'Heart Rate',
                value: hr?.value ?? 'Not recorded',
                unit: hr?.unit ?? '',
                icon: Icons.favorite_rounded,
                color: const Color(0xFFEC4899),
                status: hr?.status ?? 'Not recorded',
                recordedAt: hr?.recordedAt,
              ),
              _buildVitalGridCard(
                title: 'Oxygen (SpO2)',
                value: spo2?.value ?? 'Not recorded',
                unit: spo2?.unit ?? '',
                icon: Icons.air_rounded,
                color: const Color(0xFF06B6D4),
                status: spo2?.status ?? 'Not recorded',
                recordedAt: spo2?.recordedAt,
              ),
              _buildVitalGridCard(
                title: 'Weight',
                value: weight?.value ?? 'Not recorded',
                unit: weight?.unit ?? '',
                icon: Icons.monitor_weight_rounded,
                color: const Color(0xFF10B981),
                status: weight?.status ?? 'Not recorded',
                recordedAt: weight?.recordedAt,
              ),
              _buildVitalGridCard(
                title: 'Temperature',
                value: temp?.value ?? 'Not recorded',
                unit: temp?.unit ?? '',
                icon: Icons.thermostat_rounded,
                color: const Color(0xFF8B5CF6),
                status: temp?.status ?? 'Not recorded',
                recordedAt: temp?.recordedAt,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Vitals History Log
          const Text(
            'Recorded Logs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          if (vitals.isEmpty)
            _buildEmptyState(
              'No vitals logged yet. Tap "Log Vital" above to record one.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vitals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final v = vitals[index];
                return _buildVitalHistoryTile(v, healthProv);
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildVitalGridCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String status,
    DateTime? recordedAt,
  }) {
    final isNormal = status.toLowerCase() == 'normal';
    final isWarning = status.toLowerCase() == 'warning';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isNormal
                      ? const Color(0xFFD1FAE5)
                      : (isWarning
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isNormal
                        ? const Color(0xFF047857)
                        : (isWarning
                              ? const Color(0xFFB45309)
                              : const Color(0xFFB91C1C)),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
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

  Widget _buildVitalHistoryTile(VitalModel vital, HealthProvider healthProv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_outline_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vital.type}: ${vital.value} ${vital.unit}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(vital.recordedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.textLight,
            ),
            onPressed: () => healthProv.deleteVital(vital.id),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Medications View ───────────────────────────────────────────
  Widget _buildMedicationsTab(
    MemberModel member,
    List<MedicationModel> meds,
    HealthProvider healthProv,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Prescriptions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _addMedication(member.id),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Add Medicine',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (meds.isEmpty)
            _buildEmptyState(
              'No active medications. Tap "Add Medicine" to track daily pills and timings.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final med = meds[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: med.takenToday
                          ? const Color(0xFFBBF7D0)
                          : AppColors.border,
                      width: 1.2,
                    ),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: med.takenToday
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: med.takenToday
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF2563EB),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${med.dosage} • ${med.frequency}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Timing: ${med.timing} ${med.duration != null ? "• ${med.duration}" : ""}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Taken Today Toggle
                      InkWell(
                        onTap: () => healthProv.toggleMedicationTaken(med.id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: med.takenToday
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                med.takenToday
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: med.takenToday
                                    ? Colors.white
                                    : AppColors.textMid,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                med.takenToday ? 'Taken' : 'Take',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: med.takenToday
                                      ? Colors.white
                                      : AppColors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 3: Vaccines View ──────────────────────────────────────────────
  Widget _buildVaccinesTab(
    MemberModel member,
    List<VaccineModel> vaccines,
    HealthProvider healthProv,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Immunization Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _addVaccine(member.id),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Add Vaccine',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (vaccines.isEmpty)
            _buildEmptyState(
              'No vaccines logged. Tap "Add Vaccine" to record childhood or booster shots.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vaccines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final vac = vaccines[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.vaccines_rounded,
                          color: Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vac.name} (${vac.dose ?? "Dose"})',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Administered: ${DateFormat('dd MMM yyyy').format(vac.administeredDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            if (vac.administeredBy != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                vac.administeredBy!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 4: Visits View ────────────────────────────────────────────────
  Widget _buildVisitsTab(MemberModel member, List<VisitModel> visits) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Clinical History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/visits/add'),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'New Visit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (visits.isEmpty)
            _buildEmptyState(
              'No past clinical visits recorded for ${member.name}.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final visit = visits[index];
                return InkWell(
                  onTap: () => context.push('/visits/${visit.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              visit.diagnosis ?? 'General Consultation',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(visit.visitDate),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              visit.doctorName ?? 'Attending Doctor',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMid,
                              ),
                            ),
                            if (visit.hospital != null) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '•',
                                style: TextStyle(color: AppColors.textLight),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  visit.hospital!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (visit.treatment != null &&
                            visit.treatment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Treatment: ${visit.treatment!}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 5: Lab & Files View ───────────────────────────────────────────
  Widget _buildFilesTab(MemberModel member, List<MedFileModel> files) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reports & Documents',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _uploadFile(member.id),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Upload File',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (files.isEmpty)
            _buildEmptyState(
              'No medical files uploaded yet. Tap "Upload File" to save lab reports or scans.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final f = files[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.fileName ?? f.description ?? 'Medical Report',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.fileType.toUpperCase()} • ${DateFormat('dd MMM yyyy').format(f.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          context.showSnack(
                            'Document stored locally: ${f.fileName}',
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 40,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
