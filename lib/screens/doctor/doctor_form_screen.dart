import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/supabase_config.dart';
import '../../config/theme.dart';
import '../../models/doctor_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_avatar.dart';

class DoctorFormScreen extends StatefulWidget {
  final String? doctorId;

  const DoctorFormScreen({super.key, this.doctorId});

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _specialization = TextEditingController();
  final _qualification = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _experienceYears = TextEditingController();
  final _hospital = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _availability = TextEditingController();
  final _notes = TextEditingController();

  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _loading = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  bool get _isEdit => widget.doctorId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctor());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _specialization.dispose();
    _qualification.dispose();
    _licenseNumber.dispose();
    _experienceYears.dispose();
    _hospital.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _availability.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadDoctor() async {
    final doctorId = widget.doctorId;
    if (doctorId == null) return;
    setState(() => _loading = true);
    try {
      final provider = context.read<DoctorProvider>();
      DoctorModel? doctor = provider.doctors
          .where((item) => item.id == doctorId)
          .firstOrNull;
      if (doctor == null) {
        final uid =
            context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
        if (uid != null) await provider.loadDoctors(uid);
        doctor = provider.doctors
            .where((item) => item.id == doctorId)
            .firstOrNull;
      }
      if (doctor == null || !mounted) {
        if (mounted) {
          context.showSnack('Doctor profile not found.', isError: true);
          context.pop();
        }
        return;
      }
      _name.text = doctor.name.replaceFirst(
        RegExp(r'^Dr\.\s*', caseSensitive: false),
        '',
      );
      _specialization.text = doctor.specialization ?? '';
      _qualification.text = doctor.qualification ?? '';
      _licenseNumber.text = doctor.licenseNumber ?? '';
      _experienceYears.text = doctor.experienceYears?.toString() ?? '';
      _hospital.text = doctor.hospital ?? '';
      _phone.text = doctor.phone ?? '';
      _email.text = doctor.email ?? '';
      _address.text = doctor.address ?? '';
      _availability.text = doctor.availability ?? '';
      _notes.text = doctor.notes ?? '';
      _avatarUrl = doctor.avatarUrl;
      setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAvatarSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Doctor profile photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              if (_avatarUrl?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _avatarUrl = null;
                      _avatarBytes = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final croppedBytes = await ImageCropperService.cropAvatar(
        file: picked,
        context: context,
      );
      if (croppedBytes == null || !mounted) return;

      final dataUrl = 'data:image/png;base64,${base64Encode(croppedBytes)}';
      _avatarBytes = croppedBytes;
      AvatarMemoryCache.set(dataUrl, croppedBytes);
      setState(() {
        _avatarUrl = dataUrl;
        _uploadingAvatar = true;
      });

      final upload = await CloudinaryService.uploadImage(
        bytes: croppedBytes,
        filename: picked.name,
        folder: 'medical_history/doctor_avatars',
      );
      if (!mounted) return;
      if (upload.success && upload.secureUrl != null) {
        AvatarMemoryCache.set(upload.secureUrl!, croppedBytes);
        setState(() => _avatarUrl = upload.secureUrl);
      } else {
        context.showSnack(
          'Photo saved locally; cloud upload can be retried later.',
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnack('Unable to select doctor photo.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final cleanName = _name.text.trim();
    final data = <String, dynamic>{
      'name': cleanName.toLowerCase().startsWith('dr.')
          ? cleanName
          : 'Dr. $cleanName',
      'specialization': _specialization.text.trim(),
      'qualification': _nullIfEmpty(_qualification.text),
      'license_number': _nullIfEmpty(_licenseNumber.text),
      'experience_years': int.tryParse(_experienceYears.text.trim()),
      'hospital': _hospital.text.trim(),
      'phone': _phone.text.trim(),
      'email': _nullIfEmpty(_email.text),
      'address': _nullIfEmpty(_address.text),
      'availability': _nullIfEmpty(_availability.text),
      'notes': _nullIfEmpty(_notes.text),
      'avatar_url': _avatarUrl,
    };

    try {
      final provider = context.read<DoctorProvider>();
      final saved = _isEdit
          ? await provider.updateDoctor(widget.doctorId!, data)
          : await provider.addDoctor(data);
      if (!mounted) return;
      if (!saved) {
        context.showSnack(
          provider.error ?? 'Could not save doctor profile.',
          isError: true,
        );
        return;
      }
      if (_avatarBytes != null && _avatarUrl != null) {
        AvatarMemoryCache.set(widget.doctorId ?? _avatarUrl!, _avatarBytes!);
      }
      context.showSnack(
        _isEdit ? 'Doctor profile updated.' : 'Doctor profile added.',
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAddressOnMap() async {
    final address = _address.text.trim();
    if (address.isEmpty) {
      context.showSnack('Enter the clinic address first.', isError: true);
      return;
    }
    final mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    final opened = await launchUrl(
      mapUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      context.showSnack('Could not open Google Maps.', isError: true);
    }
  }

  String? _nullIfEmpty(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit doctor' : 'Add doctor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _buildAvatarHeader(),
                    const SizedBox(height: 24),
                    _sectionTitle(
                      'Professional information',
                      'Required fields are marked with *',
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _name,
                      label: 'Doctor name *',
                      hint: 'e.g. Ayesha Khan',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => _required(value, 'doctor name'),
                    ),
                    _field(
                      controller: _specialization,
                      label: 'Specialization *',
                      hint: 'e.g. Cardiologist',
                      icon: Icons.medical_services_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => _required(value, 'specialization'),
                    ),
                    _field(
                      controller: _qualification,
                      label: 'Qualification',
                      hint: 'e.g. MBBS, FCPS',
                      icon: Icons.school_outlined,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            controller: _licenseNumber,
                            label: 'License / PMDC No.',
                            hint: 'Registration no.',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            controller: _experienceYears,
                            label: 'Experience',
                            hint: 'Years',
                            icon: Icons.workspace_premium_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final years = int.tryParse(value);
                              return years == null || years > 80
                                  ? 'Enter 0–80'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _sectionTitle('Clinic & contact', null),
                    const SizedBox(height: 14),
                    _field(
                      controller: _hospital,
                      label: 'Hospital / clinic *',
                      hint: 'Clinic or hospital name',
                      icon: Icons.local_hospital_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          _required(value, 'hospital or clinic'),
                    ),
                    _field(
                      controller: _phone,
                      label: 'Phone number *',
                      hint: '+92 300 1234567',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final requiredError = _required(value, 'phone number');
                        if (requiredError != null) return requiredError;
                        final digits = value!.replaceAll(RegExp(r'\D'), '');
                        return digits.length < 7
                            ? 'Enter a valid phone number'
                            : null;
                      },
                    ),
                    _field(
                      controller: _email,
                      label: 'Email',
                      hint: 'doctor@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        return RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value.trim())
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    _field(
                      controller: _address,
                      label: 'Clinic address *',
                      hint: 'Complete clinic address',
                      icon: Icons.location_on_outlined,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => _required(value, 'clinic address'),
                      suffixIcon: IconButton(
                        tooltip: 'Preview address on map',
                        onPressed: _openAddressOnMap,
                        icon: const Icon(
                          Icons.map_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    _field(
                      controller: _availability,
                      label: 'Clinic timings',
                      hint: 'e.g. Mon–Fri, 4 PM–8 PM',
                      icon: Icons.schedule_outlined,
                    ),
                    _field(
                      controller: _notes,
                      label: 'Notes',
                      hint: 'Assistant number, fee, instructions, etc.',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving || _uploadingAvatar ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isEdit
                                    ? Icons.save_outlined
                                    : Icons.person_add_alt_1_rounded,
                              ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : _isEdit
                              ? 'Save changes'
                              : 'Add doctor',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.isDarkMode
            ? const LinearGradient(
                colors: [Color(0xFF173B29), Color(0xFF102D21)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.heroSubtleGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                name: _name.text.trim().isEmpty ? 'Doctor' : _name.text.trim(),
                avatarUrl: _avatarUrl,
                size: 82,
                border: Border.all(color: context.appSurface, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                onTap: _chooseAvatarSource,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _uploadingAvatar ? null : _chooseAvatarSource,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: _uploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'Use a clear professional photo. Camera and gallery are supported.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, color: context.appTextSecondary),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            maxLines: maxLines,
            onChanged: controller == _name ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: context.appTextSecondary, size: 20),
              suffixIcon: suffixIcon,
              alignLabelWithHint: maxLines > 1,
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String field) {
    return value == null || value.trim().isEmpty ? 'Please enter $field' : null;
  }
}
