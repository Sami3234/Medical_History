import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/owner_profile_service.dart';
import '../../utils/extensions.dart';

class OwnerSetupScreen extends StatefulWidget {
  const OwnerSetupScreen({super.key});

  @override
  State<OwnerSetupScreen> createState() => _OwnerSetupScreenState();
}

class _OwnerSetupScreenState extends State<OwnerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _allergies = TextEditingController();
  final _service = OwnerProfileService();

  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  bool _loading = true;
  bool _saving = false;

  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.uid;
    if (userId == null) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    if (auth.user == null) await auth.loadProfile();
    final owner = await _service.getOwnerMember(userId);
    if (!mounted) return;
    if (_service.isComplete(owner)) {
      context.go(AppRoutes.dashboard);
      return;
    }

    _name.text = owner?.name ?? auth.user?.fullName ?? '';
    _dob = owner?.dob;
    _gender = owner?.gender;
    _bloodGroup = owner?.bloodGroup;
    _emergencyContact.text = owner?.emergencyContact ?? '';
    _allergies.text = owner?.allergies ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _emergencyContact.dispose();
    _allergies.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1910),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      context.showSnack('Date of birth is required.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final familyProvider = context.read<FamilyProvider>();
    final memberProvider = context.read<MemberProvider>();
    final userId = auth.uid;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await _service.saveOwner(
        userId: userId,
        name: _name.text,
        dob: _dob!,
        gender: _gender!,
        bloodGroup: _bloodGroup!,
        emergencyContact: _emergencyContact.text,
        allergies: _allergies.text,
      );
      await auth.loadProfile();
      await Future.wait([
        familyProvider.loadFamilies(userId),
        memberProvider.loadAll(userId),
      ]);
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } catch (error) {
      if (mounted) {
        context.showSnack('Could not save your profile: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateLabel() {
    final value = _dob;
    if (value == null) return 'Select date of birth';
    return '${value.day.toString().padLeft(2, '0')} / ${value.month.toString().padLeft(2, '0')} / ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(22),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Complete your health profile',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This becomes your permanent Self profile in the family tree. You can edit it later, but it cannot be deleted.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Full name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickDob,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date of birth *',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            child: Text(_dateLabel()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender *',
                            prefixIcon: Icon(Icons.wc_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) => setState(() => _gender = value),
                          validator: (value) =>
                              value == null ? 'Gender is required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _bloodGroup,
                          decoration: const InputDecoration(
                            labelText: 'Blood group *',
                            prefixIcon: Icon(Icons.bloodtype_outlined),
                          ),
                          items: _bloodGroups
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _bloodGroup = value),
                          validator: (value) =>
                              value == null ? 'Blood group is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emergencyContact,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Emergency contact *',
                            prefixIcon: Icon(Icons.phone_in_talk_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Emergency contact is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _allergies,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Allergies / conditions (optional)',
                            prefixIcon: Icon(
                              Icons.medical_information_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _saving
                                  ? 'Saving profile...'
                                  : 'Continue to dashboard',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
