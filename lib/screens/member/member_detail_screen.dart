import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../models/member_model.dart';
import '../../models/vital_model.dart';
import '../../models/medication_model.dart';
import '../../models/vaccine_model.dart';
import '../../models/visit_model.dart';
import '../../models/med_file_model.dart';
import '../../models/doctor_model.dart';
import '../../providers/member_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../services/member_doctor_service.dart';
import '../../utils/extensions.dart';
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
      _loadMemberDoctors();
    });
  }

  Future<void> _loadMemberDoctors() async {
    try {
      final doctors = await _memberDoctorService.getDoctors(widget.id);
      if (mounted) setState(() => _memberDoctors = doctors);
    } catch (_) {}
  }

  Future<void> _manageAssignedDoctors(MemberModel member) async {
    final doctorProvider = context.read<DoctorProvider>();
    if (doctorProvider.doctors.isEmpty) {
      final userId = SupabaseConfig.currentUserId;
      if (userId != null) await doctorProvider.loadDoctors(userId);
    }
    if (!mounted) return;

    final doctors = doctorProvider.doctors;
    if (doctors.isEmpty) {
      final openDoctors = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No doctors available'),
          content: const Text(
            'Add a doctor first, then assign that doctor to this member.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add doctor'),
            ),
          ],
        ),
      );
      if (openDoctors == true && mounted) context.push(AppRoutes.doctorAdd);
      return;
    }

    final selectedIds = _memberDoctors.map((doctor) => doctor.id).toSet();
    final updatedIds = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final draftIds = Set<String>.from(selectedIds);
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assign doctors',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Choose doctors who care for ${member.name}',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: doctors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doctor = doctors[index];
                        final selected = draftIds.contains(doctor.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) => setSheetState(() {
                            if (value == true) {
                              draftIds.add(doctor.id);
                            } else {
                              draftIds.remove(doctor.id);
                            }
                          }),
                          tileColor: context.appSurface,
                          selectedTileColor: AppColors.primary.withAlpha(24),
                          selected: selected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          title: Text(
                            doctor.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            doctor.specialization ?? 'General physician',
                          ),
                          secondary: AppAvatar(
                            memberId: doctor.id,
                            name: doctor.name,
                            avatarUrl: doctor.avatarUrl,
                            size: 42,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, draftIds),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save assignments'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (updatedIds == null || !mounted) return;

    try {
      final additions = updatedIds.difference(selectedIds);
      final removals = selectedIds.difference(updatedIds);
      await Future.wait([
        ...additions.map(
          (doctorId) => _memberDoctorService.addDoctor(
            memberId: member.id,
            doctorId: doctorId,
          ),
        ),
        ...removals.map(
          (doctorId) => _memberDoctorService.removeDoctor(
            memberId: member.id,
            doctorId: doctorId,
          ),
        ),
      ]);
      await _loadMemberDoctors();
      if (mounted) context.showSnack('Doctor assignments updated');
    } catch (error) {
      if (mounted) {
        context.showSnack('Could not update doctors: $error', isError: true);
      }
    }
  }

  // ignore: unused_element
  void _showDoctorRecords(MemberModel member, DoctorModel doctor) {
    final visits =
        context
            .read<VisitProvider>()
            .visits
            .where(
              (visit) =>
                  visit.memberId == member.id &&
                  (visit.doctorId == doctor.id ||
                      (visit.doctorId == null &&
                          visit.doctorName?.trim().toLowerCase() ==
                              doctor.name.trim().toLowerCase())),
            )
            .toList()
          ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    final recordsProvider = context.read<RecordsProvider>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.appBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFD7EFE3),
                    child: Text(
                      _doctorInitials(doctor.name),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${doctor.specialization ?? "General physician"} â€¢ ${visits.length} visit${visits.length == 1 ? "" : "s"}',
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '${member.name} visit records',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (visits.isEmpty)
                _buildEmptyState(
                  'No visit with ${doctor.name} has been recorded yet.',
                )
              else
                ...visits.map((visit) {
                  final documents = recordsProvider.files
                      .where((document) => document.visitId == visit.id)
                      .toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: context.appSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4ED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.medical_information_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        visit.diagnosis?.trim().isNotEmpty == true
                            ? visit.diagnosis!
                            : 'General consultation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(visit.visitDate)} â€¢ ${documents.length} document${documents.length == 1 ? "" : "s"}',
                      ),
                      children: [
                        if (visit.symptoms?.trim().isNotEmpty == true)
                          _doctorRecordField('Symptoms', visit.symptoms!),
                        if (visit.treatment?.trim().isNotEmpty == true)
                          _doctorRecordField('Treatment', visit.treatment!),
                        if (visit.notes?.trim().isNotEmpty == true)
                          _doctorRecordField('Notes', visit.notes!),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              context.push('/visits/${visit.id}');
                            },
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 17,
                            ),
                            label: const Text('Open complete visit'),
                          ),
                        ),
                        if (documents.isNotEmpty) ...[
                          const Divider(),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Prescription, tests & documents',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...documents.map(
                            (document) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _documentIcon(document.fileType),
                                color: AppColors.primary,
                              ),
                              title: Text(
                                document.description ??
                                    document.fileName ??
                                    _documentLabel(document.fileType),
                              ),
                              subtitle: Text(_documentLabel(document.fileType)),
                              trailing: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              onTap: () async {
                                final opened = await recordsProvider
                                    .openDocument(document);
                                if (!opened && sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No compatible app could open this file.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doctorRecordField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _doctorInitials(String name) => name
      .replaceFirst(RegExp(r'^Dr\.\s*', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  String _documentLabel(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return 'Doctor prescription';
      case 'labreport':
      case 'lab_report':
        return 'Lab test report';
      case 'xray':
        return 'X-Ray';
      case 'scan':
        return 'Medical scan';
      default:
        return 'Medical document';
    }
  }

  IconData _documentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return Icons.receipt_long_outlined;
      case 'labreport':
      case 'lab_report':
        return Icons.science_outlined;
      case 'xray':
      case 'scan':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
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
    if (vital == null || !mounted) return;
    await context.read<HealthProvider>().addVital(vital);
    if (!mounted) return;
    context.showSnack('Vital sign logged successfully!');
  }

  Future<void> _addMedication(String memberId) async {
    final med = await AddMedicationDialog.show(context, memberId);
    if (med == null || !mounted) return;
    await context.read<HealthProvider>().addMedication(med);
    if (!mounted) return;
    context.showSnack('Medication prescription added!');
  }

  Future<void> _addVaccine(String memberId) async {
    final vac = await AddVaccineDialog.show(context, memberId);
    if (vac == null || !mounted) return;
    await context.read<HealthProvider>().addVaccine(vac);
    if (!mounted) return;
    context.showSnack('Immunization record saved!');
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
    await context.push('/members/${member.id}/share');
  }

  Future<void> _showMemberSettings(MemberModel member) async {
    final isOwner = member.relation.toLowerCase().trim() == 'self';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit member'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            if (!isOwner)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Delete member',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                subtitle: const Text('Remove this member and linked records'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              )
            else
              const ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Permanent owner profile'),
                subtitle: Text('Self can be edited but cannot be deleted'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      await context.push('/members/${member.id}/edit');
      if (mounted) setState(() {});
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete member?'),
        content: Text(
          'This will remove ${member.name} and linked records. Export or back up first because this cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<MemberProvider>();
    final deleted = await provider.deleteMember(member.id);
    if (!mounted) return;
    if (deleted) {
      context.go(AppRoutes.members);
      context.showSnack('Member deleted successfully.');
    } else {
      context.showSnack(
        provider.error ?? 'Could not delete member.',
        isError: true,
      );
    }
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
        backgroundColor: context.appBackground,
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
                    Icon(
                      Icons.person_off_rounded,
                      size: 54,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Member profile not found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
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
      backgroundColor: context.appBackground,
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
            icon: const Icon(Icons.description_outlined),
            onPressed: () => MedicalSummarySheet.show(context, member),
          ),
          IconButton(
            tooltip: 'Share secure profile',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareMember(member),
          ),
          // Edit Profile
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/members/${member.id}/edit').then((_) {
                  if (mounted) setState(() {});
                }),
          ),
          IconButton(
            tooltip: 'Member settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showMemberSettings(member),
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
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
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
    );
  }

  // â”€â”€ Hero Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                          color: AppColors.primaryDark,
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
                      '${member.relation.toUpperCase()} â€¢ PAT-${member.id.length > 5 ? member.id.substring(0, 4).toUpperCase() : member.id.toUpperCase()}',
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
                member.age == 'N/A' ? 'Not recorded' : member.age,
              ),
              const SizedBox(width: 8),
              _buildHeroBadge(
                Icons.bloodtype_outlined,
                member.bloodGroup ?? 'Not recorded',
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

  // â”€â”€ Quick Action Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        // This member's visits tab
        Expanded(
          child: InkWell(
            onTap: () {
              _tabController.animateTo(3);
              setState(() => _selectedTab = 3);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC4E7D5), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
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
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
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
                onPressed: () => _manageAssignedDoctors(member),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: const Text(
                  'Manage',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_memberDoctors.isEmpty)
            const Text(
              'No doctors assigned yet. Add the doctors this member visits.',
            )
          else
            ..._memberDoctors.map((doctor) {
              final visits = context
                  .watch<VisitProvider>()
                  .visits
                  .where(
                    (visit) =>
                        visit.memberId == member.id &&
                        (visit.doctorId == doctor.id ||
                            (visit.doctorId == null &&
                                visit.doctorName?.trim().toLowerCase() ==
                                    doctor.name.trim().toLowerCase())),
                  )
                  .length;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => context.push(
                    '/members/${member.id}/doctors/${doctor.id}/records',
                    extra: doctor,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.appSurfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Row(
                      children: [
                        AppAvatar(
                          memberId: doctor.id,
                          name: doctor.name,
                          avatarUrl: doctor.avatarUrl,
                          size: 38,
                          fontSize: 12,
                          backgroundColor: const Color(0xFFD7EFE3),
                          textColor: AppColors.primaryDark,
                          border: Border.all(
                            color: AppColors.primary.withAlpha(90),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${doctor.specialization ?? "General physician"} â€¢ $visits visit${visits == 1 ? "" : "s"}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.appTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // â”€â”€ Quick Stats Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStatsRow({
    required int visitsCount,
    required int medsCount,
    required int vitalsCount,
    required int filesCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1.2),
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 24, color: context.appBorder);
  }

  // â”€â”€ Segmented Tab Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // â”€â”€ Tab 1: Vitals View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with Log Vital button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Vital Signs',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
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
          Text(
            'Recorded Logs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
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
              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder, width: 1.2),
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
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: context.appTextSecondary,
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
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
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
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(vital.recordedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: context.appTextSecondary,
            ),
            onPressed: () => healthProv.deleteVital(vital.id),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Tab 2: Medications View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMedicationsTab(
    MemberModel member,
    List<MedicationModel> meds,
    HealthProvider healthProv,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Prescriptions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final med = meds[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: med.takenToday
                          ? const Color(0xFFBBF7D0)
                          : context.appBorder,
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
                              ? const Color(0xFFE6F4ED)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: med.takenToday
                              ? AppColors.primaryDark
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${med.dosage} â€¢ ${med.frequency}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Timing: ${med.timing} ${med.duration != null ? "â€¢ ${med.duration}" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.appTextSecondary,
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
                                ? AppColors.primaryDark
                                : context.appSurfaceRaised,
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
                                    : context.appTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                med.takenToday ? 'Taken' : 'Take',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: med.takenToday
                                      ? Colors.white
                                      : context.appTextSecondary,
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

  // â”€â”€ Tab 3: Vaccines View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildVaccinesTab(
    MemberModel member,
    List<VaccineModel> vaccines,
    HealthProvider healthProv,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Immunization Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final vac = vaccines[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.appBorder, width: 1.2),
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
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
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
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.appTextSecondary,
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

  // â”€â”€ Tab 4: Visits View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildVisitsTab(MemberModel member, List<VisitModel> visits) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Clinical History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.push('/visits/add?memberId=${member.id}'),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final visit = visits[index];
                return InkWell(
                  onTap: () => context.push('/visits/${visit.id}'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.appBorder, width: 1.2),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(visit.visitDate),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.appTextSecondary,
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
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.appTextSecondary,
                              ),
                            ),
                            if (visit.hospital != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'â€¢',
                                style: TextStyle(
                                  color: context.appTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  visit.hospital!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTextSecondary,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTextSecondary,
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

  // â”€â”€ Tab 5: Lab & Files View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilesTab(MemberModel member, List<MedFileModel> files) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reports & Documents',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final f = files[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appBorder, width: 1.2),
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
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.fileType.toUpperCase()} â€¢ ${DateFormat('dd MMM yyyy').format(f.createdAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondary,
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
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 40,
            color: context.appTextSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
