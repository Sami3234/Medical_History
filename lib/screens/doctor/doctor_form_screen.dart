import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/doctor_provider.dart';
import '../../utils/extensions.dart';

class DoctorFormScreen extends StatefulWidget {
  const DoctorFormScreen({super.key});

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _spec = TextEditingController();
  final _hospital = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _availability = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _hospital.dispose();
    _phone.dispose();
    _address.dispose();
    _availability.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<DoctorProvider>().addDoctor({
        'name': _name.text.startsWith('Dr.')
            ? _name.text.trim()
            : 'Dr. ${_name.text.trim()}',
        'specialization': _spec.text.trim(),
        'hospital': _hospital.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'availability': _availability.text.trim(),
      });
      if (!mounted) return;
      context.showSnack('Doctor profile added');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Failed to save doctor: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Add Doctor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'Enter doctor name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter doctor name'
                      : null,
                ),
                const SizedBox(height: 18),

                const Text(
                  'Specialization',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _spec,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Pediatrician, General Physician',
                    prefixIcon: Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Hospital / Clinic',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _hospital,
                  decoration: const InputDecoration(
                    hintText: 'e.g. City Children\'s Clinic',
                    prefixIcon: Icon(
                      Icons.local_hospital_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Phone number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+92 300 1234567',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Address / City',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    hintText: 'Enter clinic address',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Clinic timings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _availability,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Mon-Fri, 4pm-8pm',
                    prefixIcon: Icon(
                      Icons.schedule_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

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
                                'Save doctor',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
