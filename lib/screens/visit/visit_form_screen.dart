import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../providers/member_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../services/member_doctor_service.dart';
import '../../providers/visit_provider.dart';
import '../../utils/extensions.dart';

class VisitFormScreen extends StatefulWidget {
  final String? memberId;
  final String? doctorId;

  const VisitFormScreen({super.key, this.memberId, this.doctorId});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _form = GlobalKey<FormState>();
  final _doctorName = TextEditingController();
  final _hospital = TextEditingController();
  late final TextEditingController _dateCtrl;
  DateTime _visitDate = DateTime.now();
  final _symptoms = TextEditingController();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final List<Map<String, String>> _addedMedicines = [];
  String? _selectedMemberId;
  String? _selectedDoctorId;
  DateTime? _followUpDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.memberId;
    _dateCtrl = TextEditingController(
      text:
          '${_visitDate.day.toString().padLeft(2, '0')} / ${_visitDate.month.toString().padLeft(2, '0')} / ${_visitDate.year}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDoctorsAndPrefill();
    });
  }

  Future<void> _loadDoctorsAndPrefill() async {
    final uid = SupabaseConfig.currentUserId;
    final provider = context.read<DoctorProvider>();
    if (uid != null) await provider.loadDoctors(uid);
    final requestedDoctorId = widget.doctorId;
    if (!mounted || requestedDoctorId == null) return;
    for (final doctor in provider.doctors) {
      if (doctor.id != requestedDoctorId) continue;
      setState(() {
        _selectedDoctorId = doctor.id;
        _doctorName.text = doctor.name;
        _hospital.text = doctor.hospital ?? '';
      });
      break;
    }
  }

  @override
  void dispose() {
    _doctorName.dispose();
    _hospital.dispose();
    _dateCtrl.dispose();
    _symptoms.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? _visitDate.add(const Duration(days: 7)),
      firstDate: _visitDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
        _dateCtrl.text =
            '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      });
    }
  }

  void _showAddMedicineModal() {
    final medName = TextEditingController();
    final dosage = TextEditingController();
    final duration = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: ctx.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.appBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add Prescribed Medicine',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ctx.appTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: medName,
              decoration: const InputDecoration(
                hintText: 'Medicine name (e.g. Paracetamol syrup)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dosage,
              decoration: const InputDecoration(
                hintText: 'Dosage (e.g. 5ml, twice daily)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: duration,
              decoration: const InputDecoration(
                hintText: 'Duration (e.g. 3 days)',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (medName.text.isNotEmpty) {
                    setState(() {
                      _addedMedicines.add({
                        'name': medName.text.trim(),
                        'dosage': dosage.text.trim(),
                        'duration': duration.text.trim(),
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add Medicine'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final memberProv = context.read<MemberProvider>();
      if (memberProv.members.isEmpty) {
        context.showSnack('Please add a family member first.', isError: true);
        return;
      }
      final mId = _selectedMemberId ?? memberProv.members.first.id;

      await context.read<VisitProvider>().addVisit({
        'member_id': mId,
        'doctor_id': _selectedDoctorId,
        'doctor_name': _doctorName.text.trim(),
        'hospital': _hospital.text.trim(),
        'visit_date': _visitDate.toIso8601String(),
        'symptoms': _symptoms.text.trim(),
        'diagnosis': _diagnosis.text.trim(),
        'notes': _notes.text.trim(),
        'follow_up_date': _followUpDate?.toIso8601String(),
        'treatment': _addedMedicines
            .map(
              (medicine) =>
                  '${medicine['name']} | ${medicine['dosage']} | ${medicine['duration']}',
            )
            .join('\n'),
      });
      if (_selectedDoctorId != null) {
        try {
          await MemberDoctorService().addDoctor(
            memberId: mId,
            doctorId: _selectedDoctorId!,
          );
        } catch (_) {
          // The visit is already saved; assignment can be retried from profile.
        }
      }

      if (!mounted) return;
      context.showSnack('Doctor visit saved successfully');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Failed to save visit: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final members = memberProv.members;

    if (members.isEmpty) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          title: const Text('New doctor visit'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.group_add_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No family members found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please add at least one family member before recording a doctor visit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.memberAdd),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Family Member',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedMember =
        members.where((m) => m.id == _selectedMemberId).firstOrNull ??
        members.first;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('New doctor visit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Badge Card (Soft Green)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appSurfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.appBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          selectedMember.name
                              .substring(
                                0,
                                selectedMember.name.length >= 2 ? 2 : 1,
                              )
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedMember.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${selectedMember.relation} • ${selectedMember.age}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Linked doctor
                Text(
                  'Doctor / clinic specialist',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Consumer<DoctorProvider>(
                  builder: (context, doctorProvider, _) {
                    final doctors = doctorProvider.doctors;
                    if (doctors.isEmpty) {
                      return TextFormField(
                        controller: _doctorName,
                        decoration: const InputDecoration(
                          hintText: 'Enter doctor name or add a doctor first',
                          prefixIcon: Icon(Icons.medical_services_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter doctor name'
                            : null,
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedDoctorId,
                      decoration: const InputDecoration(
                        hintText: 'Select saved doctor',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                      ),
                      items: doctors
                          .map(
                            (doctor) => DropdownMenuItem<String>(
                              value: doctor.id,
                              child: Text(
                                doctor.specialization?.trim().isNotEmpty == true
                                    ? '${doctor.name} • ${doctor.specialization}'
                                    : doctor.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Please select a doctor' : null,
                      onChanged: (value) {
                        final doctor = doctors
                            .where((item) => item.id == value)
                            .firstOrNull;
                        setState(() {
                          _selectedDoctorId = value;
                          _doctorName.text = doctor?.name ?? '';
                          if (_hospital.text.trim().isEmpty) {
                            _hospital.text = doctor?.hospital ?? '';
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push(AppRoutes.doctors),
                    icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                    label: const Text('Manage doctors'),
                  ),
                ),
                const SizedBox(height: 18),

                // Hospital / Clinic
                Text(
                  'Hospital / Clinic',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _hospital,
                  decoration: const InputDecoration(
                    hintText: 'Enter hospital name',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Visit date
                Text(
                  'Visit date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    hintText: 'DD / MM / YYYY',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Symptoms / reason
                Text(
                  'Symptoms / reason',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _symptoms,
                  decoration: const InputDecoration(
                    hintText: 'Describe health complaint',
                    prefixIcon: Icon(
                      Icons.favorite_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please describe symptoms'
                      : null,
                ),
                const SizedBox(height: 18),

                // Diagnosis / treatment
                Text(
                  'Diagnosis / treatment',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _diagnosis,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter medical notes',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Visit notes',
                    hintText: 'Doctor advice, observations or next steps',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickFollowUpDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Follow-up date (optional)',
                      prefixIcon: Icon(Icons.event_repeat_outlined),
                    ),
                    child: Text(
                      _followUpDate == null
                          ? 'Not scheduled'
                          : '${_followUpDate!.day.toString().padLeft(2, '0')} / ${_followUpDate!.month.toString().padLeft(2, '0')} / ${_followUpDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Added medicines display
                if (_addedMedicines.isNotEmpty) ...[
                  ..._addedMedicines.map(
                    (m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.medication_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${m['name']} (${m['dosage'] ?? ''})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // + Add medicines / prescriptions button (soft green)
                InkWell(
                  onTap: _showAddMedicineModal,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: context.appSurfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appBorder, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '+ Add medicines / prescriptions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Save doctor visit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Save doctor visit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
