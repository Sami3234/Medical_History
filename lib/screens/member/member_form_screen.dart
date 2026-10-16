import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../utils/extensions.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _dob = TextEditingController();
  DateTime? _selectedDob;
  String? _selectedBloodGroup;
  final _notes = TextEditingController();
  String? _selectedFamilyId;
  bool _saving = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _dob.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dob.text = '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final famProv = context.read<FamilyProvider>();
      final famId = _selectedFamilyId ?? (famProv.families.isNotEmpty ? famProv.families.first.id : 'fam-1');

      await context.read<MemberProvider>().addMember({
        'family_id': famId,
        'name': _name.text.trim(),
        'relation': _relation.text.trim(),
        'dob': _selectedDob?.toIso8601String(),
        'blood_group': _selectedBloodGroup,
        'allergies': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
      });

      if (!mounted) return;
      context.showSnack('Family member profile created');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Failed to save member: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Add family member'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Card: Create patient profile
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDEF2D7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF235E1E),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create patient profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Photo optional • ID auto-generated',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // Full name
                const Text(
                  'Full name',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'Enter member name',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textLight, size: 20),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter member name' : null,
                ),
                const SizedBox(height: 18),

                // Relationship
                const Text(
                  'Relationship',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _relation,
                  decoration: const InputDecoration(
                    hintText: 'Son / Daughter / Wife...',
                    prefixIcon: Icon(Icons.groups_outlined, color: AppColors.textLight, size: 20),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please specify relationship' : null,
                ),
                const SizedBox(height: 18),

                // Date of birth
                const Text(
                  'Date of birth',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dob,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    hintText: 'DD / MM / YYYY',
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textLight, size: 20),
                  ),
                ),
                const SizedBox(height: 18),

                // Blood group
                const Text(
                  'Blood group',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  decoration: const InputDecoration(
                    hintText: 'Select blood group',
                    prefixIcon: Icon(Icons.favorite_outline_rounded, color: AppColors.textLight, size: 20),
                  ),
                  items: _bloodGroups.map((bg) {
                    return DropdownMenuItem(value: bg, child: Text(bg));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBloodGroup = val),
                ),
                const SizedBox(height: 18),

                // Allergies / conditions
                const Text(
                  'Allergies / conditions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Optional medical notes',
                    prefixIcon: Icon(Icons.description_outlined, color: AppColors.textLight, size: 20),
                  ),
                ),
                const SizedBox(height: 32),

                // Save family member button
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
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Save family member',
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
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Each person gets a unique Patient ID.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
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
