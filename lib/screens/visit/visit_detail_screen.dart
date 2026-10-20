import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/theme.dart';
import '../../models/visit_model.dart';
import '../../providers/records_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/bottom_nav.dart';

class VisitDetailScreen extends StatelessWidget {
  final String id;
  const VisitDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final visitProvider = context.watch<VisitProvider>();
    final recordsProvider = context.watch<RecordsProvider>();
    final visit = visitProvider.visits
        .where((item) => item.id == id)
        .firstOrNull;

    if (visit == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Visit details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: visitProvider.loading
              ? const CircularProgressIndicator()
              : const Text('Visit record not found'),
        ),
      );
    }

    final attachments = recordsProvider.files
        .where((document) => document.visitId == visit.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Visit details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Export visit',
            onPressed: () => _exportVisit(visit),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Attach document',
            onPressed: () => _attachDocument(context, visit, recordsProvider),
            icon: const Icon(Icons.attach_file_rounded),
          ),
          IconButton(
            tooltip: 'Delete visit',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy').format(visit.visitDate),
                    style: TextStyle(color: Colors.white.withAlpha(230)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    visit.doctorName?.trim().isNotEmpty == true
                        ? visit.doctorName!
                        : 'Doctor visit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (visit.memberName?.isNotEmpty == true)
                        visit.memberName!,
                      if (visit.hospital?.isNotEmpty == true) visit.hospital!,
                    ].join(' • '),
                    style: TextStyle(color: Colors.white.withAlpha(220)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _section(
              title: 'Consultation summary',
              children: [
                _field('Symptoms', visit.symptoms),
                const SizedBox(height: 16),
                _field('Diagnosis', visit.diagnosis),
                if (visit.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  _field('Notes', visit.notes),
                ],
              ],
            ),
            if (visit.treatment?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 18),
              _section(
                title: 'Prescribed medicines',
                children: [
                  Text(
                    visit.treatment!.replaceAll(' | ', ' • '),
                    style: const TextStyle(height: 1.7),
                  ),
                ],
              ),
            ],
            if (visit.followUpDate != null) ...[
              const SizedBox(height: 18),
              _section(
                title: 'Follow-up',
                children: [
                  Text(DateFormat('dd MMMM yyyy').format(visit.followUpDate!)),
                ],
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 18),
              _section(
                title: 'Attached documents',
                children: attachments
                    .map(
                      (document) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          document.description ??
                              document.fileName ??
                              'Document',
                        ),
                        subtitle: Text(document.fileName ?? document.fileType),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () async {
                          final opened = await recordsProvider.openDocument(
                            document,
                          );
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No compatible app could open this file.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _field(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value?.trim().isNotEmpty == true ? value! : 'Not recorded',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _section({required String title, required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete visit?'),
        content: const Text('This visit record will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final deleted = await context.read<VisitProvider>().deleteVisit(id);
      if (deleted && context.mounted) context.pop();
    }
  }

  Future<void> _attachDocument(
    BuildContext context,
    VisitModel visit,
    RecordsProvider records,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !context.mounted) return;
    await records.addDocument(
      memberId: visit.memberId,
      visitId: visit.id,
      title: file.name,
      fileType: file.extension?.toLowerCase() == 'pdf'
          ? 'prescription'
          : 'scan',
      fileName: file.name,
      bytes: file.bytes!,
      mimeType: file.extension?.toLowerCase() == 'pdf'
          ? 'application/pdf'
          : 'image/${file.extension ?? 'jpeg'}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document attached to this visit.')),
      );
    }
  }

  Future<void> _exportVisit(VisitModel visit) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Doctor Visit Summary',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Date: ${DateFormat('dd MMMM yyyy').format(visit.visitDate)}',
            ),
            pw.Text('Doctor: ${visit.doctorName ?? 'Not recorded'}'),
            pw.Text('Member: ${visit.memberName ?? 'Not recorded'}'),
            if (visit.hospital?.isNotEmpty == true)
              pw.Text('Hospital: ${visit.hospital}'),
            pw.SizedBox(height: 14),
            pw.Text(
              'Symptoms: ${visit.symptoms?.isNotEmpty == true ? visit.symptoms : 'Not recorded'}',
            ),
            pw.Text(
              'Diagnosis: ${visit.diagnosis?.isNotEmpty == true ? visit.diagnosis : 'Not recorded'}',
            ),
            pw.Text(
              'Treatment: ${visit.treatment?.isNotEmpty == true ? visit.treatment : 'Not recorded'}',
            ),
            pw.Text(
              'Notes: ${visit.notes?.isNotEmpty == true ? visit.notes : 'Not recorded'}',
            ),
            if (visit.followUpDate != null)
              pw.Text(
                'Follow-up: ${DateFormat('dd MMMM yyyy').format(visit.followUpDate!)}',
              ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'doctor_visit_${visit.id}.pdf',
    );
  }
}
