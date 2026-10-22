import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/member_model.dart';
import '../models/vital_model.dart';
import '../models/medication_model.dart';
import '../models/vaccine_model.dart';

/// Interactive modal to log a new vital sign (BP, Sugar, Weight, Heart Rate, etc.)
class AddVitalDialog extends StatefulWidget {
  final String memberId;
  const AddVitalDialog({super.key, required this.memberId});

  static Future<VitalModel?> show(BuildContext context, String memberId) {
    return showModalBottomSheet<VitalModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddVitalDialog(memberId: memberId),
    );
  }

  @override
  State<AddVitalDialog> createState() => _AddVitalDialogState();
}

class _AddVitalDialogState extends State<AddVitalDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Blood Pressure';
  final _valueCtrl = TextEditingController(text: '120/80');
  final _notesCtrl = TextEditingController();

  final Map<String, String> _typeUnits = {
    'Blood Pressure': 'mmHg',
    'Blood Sugar': 'mg/dL',
    'Heart Rate': 'bpm',
    'Oxygen (SpO2)': '%',
    'Weight': 'kg',
    'Temperature': '°F',
  };

  final Map<String, String> _typeHints = {
    'Blood Pressure': 'e.g. 120/80',
    'Blood Sugar': 'e.g. 110',
    'Heart Rate': 'e.g. 72',
    'Oxygen (SpO2)': 'e.g. 98',
    'Weight': 'e.g. 68.5',
    'Temperature': 'e.g. 98.6',
  };

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      if (type == 'Blood Pressure') {
        _valueCtrl.text = '120/80';
      } else if (type == 'Blood Sugar') {
        _valueCtrl.text = '105';
      } else if (type == 'Heart Rate') {
        _valueCtrl.text = '75';
      } else if (type == 'Oxygen (SpO2)') {
        _valueCtrl.text = '98';
      } else if (type == 'Weight') {
        _valueCtrl.text = '70.0';
      } else if (type == 'Temperature') {
        _valueCtrl.text = '98.6';
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final unit = _typeUnits[_selectedType] ?? '';
    final val = _valueCtrl.text.trim();
    final status = VitalModel.calculateStatus(_selectedType, val);

    final vital = VitalModel(
      id: 'vit-${DateTime.now().millisecondsSinceEpoch}',
      memberId: widget.memberId,
      type: _selectedType,
      value: val,
      unit: unit,
      recordedAt: DateTime.now(),
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      status: status,
    );

    Navigator.of(context).pop(vital);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, media.viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Log Health Vital',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type selector chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeUnits.keys.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: context.appSurfaceSoft,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : context.appTextPrimary,
                  ),
                  onSelected: (val) {
                    if (val) _onTypeChanged(type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Value Input
            Text(
              'Measurement Value (${_typeUnits[_selectedType]})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _valueCtrl,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: _typeHints[_selectedType],
                suffixText: _typeUnits[_selectedType],
                prefixIcon: const Icon(
                  Icons.speed_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a value'
                  : null,
            ),
            const SizedBox(height: 14),

            // Notes Input
            Text(
              'Context / Note (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Fasting, after dinner, post-workout',
                prefixIcon: Icon(
                  Icons.notes_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Save Vital Log',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal to prescribe / track active medications
class AddMedicationDialog extends StatefulWidget {
  final String memberId;
  const AddMedicationDialog({super.key, required this.memberId});

  static Future<MedicationModel?> show(BuildContext context, String memberId) {
    return showModalBottomSheet<MedicationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddMedicationDialog(memberId: memberId),
    );
  }

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController(text: '500 mg');
  String _frequency = 'Twice daily';
  String _timing = 'After meals';
  final _durationCtrl = TextEditingController(text: '7 days');
  final _notesCtrl = TextEditingController();

  final List<String> _frequencies = [
    'Once daily',
    'Twice daily',
    'Thrice daily',
    'Every 4 hours',
    'As needed',
  ];

  final List<String> _timings = [
    'After meals',
    'Before meals',
    'With food',
    'Bedtime',
    'Morning',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final med = MedicationModel(
      id: 'med-${DateTime.now().millisecondsSinceEpoch}',
      memberId: widget.memberId,
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: _frequency,
      timing: _timing,
      duration: _durationCtrl.text.trim().isNotEmpty
          ? _durationCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      isActive: true,
      takenToday: false,
    );
    Navigator.of(context).pop(med);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, media.viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Active Medicine',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Medicine Name
              const Text(
                'Medicine Name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Panadol, Augmentin, Metformin',
                  prefixIcon: Icon(
                    Icons.local_pharmacy_outlined,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter medicine name'
                    : null,
              ),
              const SizedBox(height: 14),

              // Dosage & Duration Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dosage',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dosageCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 500 mg, 1 tablet',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _durationCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 7 days, Ongoing',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Frequency Dropdown
              const Text(
                'Frequency',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                items: _frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              const SizedBox(height: 14),

              // Timing Dropdown
              const Text(
                'Timing Instructions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _timing,
                items: _timings
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _timing = v!),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Add to Active Prescriptions',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal to record a vaccination
class AddVaccineDialog extends StatefulWidget {
  final String memberId;
  const AddVaccineDialog({super.key, required this.memberId});

  static Future<VaccineModel?> show(BuildContext context, String memberId) {
    return showModalBottomSheet<VaccineModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddVaccineDialog(memberId: memberId),
    );
  }

  @override
  State<AddVaccineDialog> createState() => _AddVaccineDialogState();
}

class _AddVaccineDialogState extends State<AddVaccineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Hepatitis B');
  final _doseCtrl = TextEditingController(text: 'Dose 1');
  final _centerCtrl = TextEditingController(text: 'City Health Clinic');
  DateTime _administeredDate = DateTime.now();

  final List<String> _commonVaccines = [
    'Hepatitis B',
    'Polio (OPV/IPV)',
    'BCG (Tuberculosis)',
    'COVID-19 Booster',
    'MMR (Measles, Mumps, Rubella)',
    'Tetanus Toxoid (TT)',
    'Influenza (Flu)',
    'Typhoid Conjugate',
    'Pneumococcal (PCV)',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _centerCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final vac = VaccineModel(
      id: 'vac-${DateTime.now().millisecondsSinceEpoch}',
      memberId: widget.memberId,
      name: _nameCtrl.text.trim(),
      dose: _doseCtrl.text.trim().isNotEmpty ? _doseCtrl.text.trim() : null,
      administeredDate: _administeredDate,
      administeredBy: _centerCtrl.text.trim().isNotEmpty
          ? _centerCtrl.text.trim()
          : null,
      status: 'Completed',
    );
    Navigator.of(context).pop(vac);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, media.viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.vaccines_rounded,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Record Vaccination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick vaccine selector chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _commonVaccines.map((vName) {
                    final isSelected = _nameCtrl.text == vName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(vName),
                        selected: isSelected,
                        selectedColor: const Color(0xFF7C3AED),
                        backgroundColor: context.appSurfaceSoft,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : context.appTextPrimary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _nameCtrl.text = vName);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Vaccine Name Input
              const Text(
                'Vaccine Name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter vaccine name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter vaccine name'
                    : null,
              ),
              const SizedBox(height: 14),

              // Dose & Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dose',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _doseCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Dose 1, Booster',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date Given',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _administeredDate,
                              firstDate: DateTime(1980),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _administeredDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_administeredDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Center / Hospital
              const Text(
                'Health Center / Hospital',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _centerCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. City Hospital, Dr. Clinic',
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text(
                    'Save Vaccination Record',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Emergency ICE (In Case of Emergency) Sheet
class EmergencyIceModal extends StatelessWidget {
  final MemberModel member;
  const EmergencyIceModal({super.key, required this.member});

  static void show(BuildContext context, MemberModel member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmergencyIceModal(member: member),
    );
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, media.viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E24), // High contrast slate emergency backdrop
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Red Emergency Badge Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EMERGENCY MEDICAL CARD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEF4444),
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Blood Group & Organ Donor Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BLOOD GROUP',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.bloodGroup ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.age == 'N/A' ? 'Age N/A' : member.age,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Allergies (High priority alert)
          _buildIceCard(
            title: 'CRITICAL ALLERGIES',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            content: member.allergies ?? 'No known drug or food allergies',
          ),
          const SizedBox(height: 12),

          // Chronic Conditions
          _buildIceCard(
            title: 'EXISTING CONDITIONS / MEDICAL NOTES',
            icon: Icons.medical_services_outlined,
            color: const Color(0xFF38BDF8),
            content: member.notes ?? 'No chronic conditions recorded',
          ),
          const SizedBox(height: 22),

          // Call Emergency Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _callPhone('1122'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
              label: const Text(
                'CALL RESCUE (1122) / EMERGENCY',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIceCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
