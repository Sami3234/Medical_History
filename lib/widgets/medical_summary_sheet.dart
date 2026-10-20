import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/member_model.dart';
import '../models/vital_model.dart';
import '../models/medication_model.dart';
import '../models/vaccine_model.dart';
import '../models/visit_model.dart';
import '../providers/health_provider.dart';
import '../providers/visit_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MedicalSummarySheet extends StatelessWidget {
  final MemberModel member;

  const MedicalSummarySheet({super.key, required this.member});

  static void show(BuildContext context, MemberModel member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicalSummarySheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthProv = context.watch<HealthProvider>();
    final visitProv = context.watch<VisitProvider>();

    final medications = healthProv.getMedicationsByMember(member.id);
    final vaccines = healthProv.getVaccinesByMember(member.id);
    final visits =
        visitProv.visits.where((v) => v.memberId == member.id).toList()
          ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

    final bp = healthProv.getLatestVital(member.id, 'Blood Pressure');
    final sugar = healthProv.getLatestVital(member.id, 'Blood Sugar');
    final hr = healthProv.getLatestVital(member.id, 'Heart Rate');
    final weight = healthProv.getLatestVital(member.id, 'Weight');

    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle & Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clinical Medical Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Official patient health overview',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMid,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Scrollable Clinical Document
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hospital / System Logo Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FAMILY HEALTH RECORDS',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            member.bloodGroup ?? 'O+',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Section: Patient Demographics
                    _sectionHeader('1. PATIENT DEMOGRAPHICS'),
                    const SizedBox(height: 10),
                    _demographicGrid(),
                    const SizedBox(height: 18),

                    // Section: Allergies & Chronic Conditions (Alert Box)
                    _sectionHeader('2. CRITICAL ALERTS & CHRONIC CONDITIONS'),
                    const SizedBox(height: 10),
                    _criticalAlertsBox(),
                    const SizedBox(height: 18),

                    // Section: Current Vitals
                    _sectionHeader('3. CURRENT VITAL SIGNS'),
                    const SizedBox(height: 10),
                    _vitalsRow(bp, sugar, hr, weight),
                    const SizedBox(height: 18),

                    // Section: Active Medications
                    _sectionHeader('4. ACTIVE PRESCRIPTIONS & MEDICATIONS'),
                    const SizedBox(height: 10),
                    medications.isEmpty
                        ? _emptyNote('No active medications on record.')
                        : Column(
                            children: medications
                                .where((m) => m.isActive)
                                .map((m) => _medicationRow(m))
                                .toList(),
                          ),
                    const SizedBox(height: 18),

                    // Section: Immunizations
                    _sectionHeader('5. IMMUNIZATION & VACCINE RECORD'),
                    const SizedBox(height: 10),
                    vaccines.isEmpty
                        ? _emptyNote('No immunization records logged.')
                        : Column(
                            children: vaccines
                                .map((v) => _vaccineRow(v))
                                .toList(),
                          ),
                    const SizedBox(height: 18),

                    // Section: Clinical Visits
                    _sectionHeader('6. RECENT CLINICAL VISITS'),
                    const SizedBox(height: 10),
                    visits.isEmpty
                        ? _emptyNote('No doctor visits logged yet.')
                        : Column(
                            children: visits
                                .take(3)
                                .map((v) => _visitRow(v))
                                .toList(),
                          ),
                    const SizedBox(height: 24),

                    // Medical Disclaimer Footer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This summary is generated for personal and emergency medical reference. For clinical treatment, please verify details with the attending physician.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textLight,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar: Print / Share button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _exportPdf(
                  context,
                  medications: medications,
                  vaccines: vaccines,
                  visits: visits,
                  vitals: [
                    bp,
                    sugar,
                    hr,
                    weight,
                  ].whereType<VitalModel>().toList(),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(
                  'Share / Print Medical Summary',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context, {
    required List<MedicationModel> medications,
    required List<VaccineModel> vaccines,
    required List<VisitModel> visits,
    required List<VitalModel> vitals,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Medical History Summary')),
          pw.Text('Member: ${member.name}'),
          pw.Text(
            'Generated: ${DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, child: pw.Text('Profile')),
          pw.Text('Relation: ${member.relation}'),
          pw.Text('Blood group: ${member.bloodGroup ?? 'Not recorded'}'),
          pw.Text('Allergies: ${member.allergies ?? 'None recorded'}'),
          pw.Header(level: 1, child: pw.Text('Vitals')),
          if (vitals.isEmpty)
            pw.Text('No vitals recorded.')
          else
            ...vitals.map((v) => pw.Text('${v.type}: ${v.value} ${v.unit}')),
          pw.Header(level: 1, child: pw.Text('Active medications')),
          if (medications.isEmpty)
            pw.Text('No medications recorded.')
          else
            ...medications
                .where((m) => m.isActive)
                .map(
                  (m) => pw.Text(
                    '${m.name} ${m.dosage ?? ''} ${m.frequency ?? ''}',
                  ),
                ),
          pw.Header(level: 1, child: pw.Text('Visits')),
          if (visits.isEmpty)
            pw.Text('No visits recorded.')
          else
            ...visits.map(
              (v) => pw.Text(
                '${DateFormat('dd MMM yyyy').format(v.visitDate)} — ${v.doctorName ?? 'Doctor'} — ${v.diagnosis ?? v.notes ?? 'Visit'}',
              ),
            ),
          pw.Header(level: 1, child: pw.Text('Vaccines')),
          if (vaccines.isEmpty)
            pw.Text('No vaccines recorded.')
          else
            ...vaccines.map((v) => pw.Text('${v.name} — ${v.status}')),
          pw.SizedBox(height: 20),
          pw.Text('Read-only summary generated by Medical History.'),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: '${member.name.replaceAll(' ', '_')}_medical_summary.pdf',
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _demographicGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _dataCell('Full Name', member.name),
              _dataCell(
                'Age',
                member.age == 'N/A' ? 'Not specified' : member.age,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _dataCell('Relationship', member.relation),
              _dataCell('Blood Group', member.bloodGroup ?? 'O+'),
            ],
          ),
          if (member.emergencyContact != null &&
              member.emergencyContact!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _dataCell('Emergency Contact', member.emergencyContact!),
                _dataCell('Status', 'Active Patient'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _criticalAlertsBox() {
    final hasAllergy = member.allergies != null && member.allergies!.isNotEmpty;
    final hasCondition = member.notes != null && member.notes!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasAllergy ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasAllergy ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasAllergy
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: hasAllergy
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Text(
                'Known Allergies: ${hasAllergy ? member.allergies! : "None Reported"}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: hasAllergy
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.medical_information_outlined,
                size: 16,
                color: AppColors.textMid,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chronic History: ${hasCondition ? member.notes! : "No chronic illnesses reported"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalsRow(
    VitalModel? bp,
    VitalModel? sugar,
    VitalModel? hr,
    VitalModel? weight,
  ) {
    return Row(
      children: [
        _vitalMiniCard(
          'BP',
          bp != null ? '${bp.value} ${bp.unit}' : '120/80 mmHg',
          Icons.speed_rounded,
        ),
        const SizedBox(width: 8),
        _vitalMiniCard(
          'Sugar',
          sugar != null ? '${sugar.value} ${sugar.unit}' : '105 mg/dL',
          Icons.bloodtype_rounded,
        ),
        const SizedBox(width: 8),
        _vitalMiniCard(
          'Pulse',
          hr != null ? '${hr.value} ${hr.unit}' : '72 bpm',
          Icons.favorite_rounded,
        ),
        const SizedBox(width: 8),
        _vitalMiniCard(
          'Weight',
          weight != null ? '${weight.value} ${weight.unit}' : '68 kg',
          Icons.monitor_weight_rounded,
        ),
      ],
    );
  }

  Widget _vitalMiniCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationRow(MedicationModel med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medication_rounded,
            size: 16,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${med.dosage} • ${med.frequency} (${med.timing})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vaccineRow(VaccineModel vac) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.vaccines_rounded,
            size: 16,
            color: Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vac.name} (${vac.dose ?? "Dose"})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${DateFormat('dd MMM yyyy').format(vac.administeredDate)} • ${vac.administeredBy ?? "Health Center"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'DONE',
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
  }

  Widget _visitRow(VisitModel visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medical_services_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.diagnosis ?? 'General Consultation',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${DateFormat('dd MMM yyyy').format(visit.visitDate)} • ${visit.doctorName ?? "Consulting Physician"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textLight,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
