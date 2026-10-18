import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
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
}
