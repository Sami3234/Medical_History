import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/doctor_model.dart';
import '../../models/med_file_model.dart';
import '../../models/member_model.dart';
import '../../models/visit_model.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/app_avatar.dart';

class MemberDoctorRecordsScreen extends StatefulWidget {
  const MemberDoctorRecordsScreen({
    super.key,
    required this.memberId,
    required this.doctorId,
    this.initialDoctor,
  });

  final String memberId;
  final String doctorId;
  final DoctorModel? initialDoctor;

  @override
  State<MemberDoctorRecordsScreen> createState() =>
      _MemberDoctorRecordsScreenState();
}

class _MemberDoctorRecordsScreenState extends State<MemberDoctorRecordsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        context.read<VisitProvider>().loadByMember(widget.memberId),
        context.read<RecordsProvider>().loadAll(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final member = _findMember(context.watch<MemberProvider>().members);
    final doctor = _findDoctor(context.watch<DoctorProvider>().doctors);
    final visitProvider = context.watch<VisitProvider>();
    final recordsProvider = context.watch<RecordsProvider>();
    final visits =
        visitProvider.visits
            .where(
              (visit) =>
                  visit.memberId == widget.memberId &&
                  (visit.doctorId == widget.doctorId ||
                      (visit.doctorId == null &&
                          doctor != null &&
                          visit.doctorName?.trim().toLowerCase() ==
                              doctor.name.trim().toLowerCase())),
            )
            .toList()
          ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    final visitIds = visits.map((visit) => visit.id).toSet();
    final documents =
        recordsProvider.files
            .where(
              (file) => file.visitId != null && visitIds.contains(file.visitId),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (member == null || doctor == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(title: const Text('Doctor records')),
        body: Center(
          child: visitProvider.loading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : const Text('Doctor or member profile is unavailable.'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          title: Text(member.name),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(
            '/visits/add?memberId=${member.id}&doctorId=${doctor.id}',
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add visit'),
        ),
        body: Column(
          children: [
            _buildDoctorHeader(doctor, member, visits, documents),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: context.appTextSecondary,
                tabs: [
                  Tab(text: 'Visits (${visits.length})'),
                  Tab(text: 'Documents (${documents.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVisits(visits, recordsProvider),
                  _buildDocuments(documents, recordsProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MemberModel? _findMember(List<MemberModel> members) {
    for (final member in members) {
      if (member.id == widget.memberId) return member;
    }
    return null;
  }

  DoctorModel? _findDoctor(List<DoctorModel> doctors) {
    if (widget.initialDoctor != null) return widget.initialDoctor;
    for (final doctor in doctors) {
      if (doctor.id == widget.doctorId) return doctor;
    }
    return null;
  }

  Widget _buildDoctorHeader(
    DoctorModel doctor,
    MemberModel member,
    List<VisitModel> visits,
    List<MedFileModel> documents,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(42),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            memberId: doctor.id,
            name: doctor.name,
            avatarUrl: doctor.avatarUrl,
            size: 62,
            border: Border.all(color: Colors.white, width: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  doctor.specialization ?? 'General physician',
                  style: TextStyle(color: Colors.white.withAlpha(220)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _headerChip('${visits.length} visits'),
                    _headerChip('${documents.length} documents'),
                    _headerChip(member.name),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open doctor profile',
            onPressed: () => context.push('/doctors/${doctor.id}'),
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(35),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withAlpha(70)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildVisits(
    List<VisitModel> visits,
    RecordsProvider recordsProvider,
  ) {
    if (visits.isEmpty) {
      return _emptyState(
        Icons.medical_information_outlined,
        'No visits recorded',
        'Use Add visit to save the first consultation with this doctor.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: visits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = visits[index];
        final attachments = recordsProvider.files
            .where((file) => file.visitId == visit.id)
            .toList();
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: context.appSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: context.appBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4ED),
                borderRadius: BorderRadius.circular(13),
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
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy').format(visit.visitDate)} • ${attachments.length} document${attachments.length == 1 ? '' : 's'}',
            ),
            children: [
              if (visit.symptoms?.trim().isNotEmpty == true)
                _detailRow('Symptoms', visit.symptoms!),
              if (visit.treatment?.trim().isNotEmpty == true)
                _detailRow('Treatment', visit.treatment!),
              if (visit.notes?.trim().isNotEmpty == true)
                _detailRow('Notes', visit.notes!),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/visits/${visit.id}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open visit'),
                  ),
                  const Spacer(),
                  Text(
                    '${attachments.length} attachments',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              ...attachments.map(
                (file) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _fileIcon(file.fileType),
                    color: AppColors.primary,
                  ),
                  title: Text(file.description ?? file.fileName ?? 'Document'),
                  subtitle: Text(_fileLabel(file.fileType)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => recordsProvider.openDocument(file),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocuments(
    List<MedFileModel> documents,
    RecordsProvider recordsProvider,
  ) {
    if (documents.isEmpty) {
      return _emptyState(
        Icons.folder_open_outlined,
        'No linked documents',
        'Attach prescriptions, reports or scans inside a doctor visit.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final document = documents[index];
        return ListTile(
          tileColor: context.appSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.appBorder),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_fileIcon(document.fileType), color: AppColors.primary),
          ),
          title: Text(document.description ?? document.fileName ?? 'Document'),
          subtitle: Text(
            '${_fileLabel(document.fileType)} • ${DateFormat('dd MMM yyyy').format(document.createdAt)}',
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 19),
          onTap: () => recordsProvider.openDocument(document),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) => Padding(
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

  Widget _emptyState(IconData icon, String title, String subtitle) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: AppColors.primary.withAlpha(150)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appTextSecondary),
          ),
        ],
      ),
    ),
  );

  String _fileLabel(String type) {
    switch (type.toLowerCase()) {
      case 'prescription':
        return 'Prescription';
      case 'labreport':
      case 'lab_report':
        return 'Lab report';
      case 'xray':
        return 'X-ray';
      case 'scan':
        return 'Scan';
      default:
        return 'Medical document';
    }
  }

  IconData _fileIcon(String type) {
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
}
