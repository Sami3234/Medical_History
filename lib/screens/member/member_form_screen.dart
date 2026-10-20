import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_avatar.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  final _age = TextEditingController();
  DateTime? _selectedDob;
  String? _selectedBloodGroup;
  String? _selectedRelation;
  final _notes = TextEditingController();
  final _emergencyContact = TextEditingController();
  String? _selectedFamilyId;
  String? _selectedParentId;
  String? _avatarUrl;
  Uint8List? _pickedPhotoBytes;
  bool _uploadingAvatar = false;
  bool _saving = false;

  final List<String> _relations = [
    'Self',
    'Spouse',
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Grandfather',
    'Grandmother',
  ];

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      // Crop image with modern circular aperture cropper
      final croppedBytes = await ImageCropperService.cropAvatar(
        file: picked,
        context: context,
      );
      if (croppedBytes == null || !mounted) {
        // User cancelled crop
        return;
      }

      _pickedPhotoBytes = croppedBytes;
      // Convert to self-contained Base64 data URI to guarantee instant, 100% reliable display
      final dataUri = 'data:image/png;base64,${base64Encode(croppedBytes)}';

      AvatarMemoryCache.set(dataUri, croppedBytes);
      if (_name.text.trim().isNotEmpty) {
        AvatarMemoryCache.set(_name.text.trim(), croppedBytes);
        AvatarMemoryCache.set(_name.text.trim().toLowerCase(), croppedBytes);
      }
      setState(() => _avatarUrl = dataUri);

      // Attempt background cloud upload for persistent CDN backup
      setState(() => _uploadingAvatar = true);
      final res = await CloudinaryService.uploadImage(
        bytes: croppedBytes,
        filename: picked.name,
        folder: 'medical_history/avatars',
      );

      if (res.success && res.secureUrl != null) {
        AvatarMemoryCache.set(res.secureUrl!, croppedBytes);
        if (mounted) {
          setState(() => _avatarUrl = res.secureUrl);
          context.showSnack('Member photo saved successfully!');
        }
      } else {
        // Fallback: Photo is already safely saved locally as Base64 Data URI
        if (mounted) context.showSnack('Member photo saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(
          'Unable to pick photo. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _age.dispose();
    _notes.dispose();
    _emergencyContact.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDob ?? DateTime(now.year - 18);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? initialDate : now,
      firstDate: DateTime(1910),
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
      final now = DateTime.now();
      int calculatedAge = now.year - picked.year;
      if (now.month < picked.month ||
          (now.month == picked.month && now.day < picked.day)) {
        calculatedAge--;
      }
      if (calculatedAge < 0) calculatedAge = 0;

      setState(() {
        _selectedDob = picked;
        _dob.text =
            '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
        _age.text = calculatedAge.toString();
      });
    }
  }

  void _onAgeChanged(String val) {
    final ageNum = int.tryParse(val.trim());
    if (ageNum != null && ageNum >= 0 && ageNum <= 125) {
      final now = DateTime.now();
      final estimatedYear = now.year - ageNum;
      final estimatedDob = DateTime(
        estimatedYear,
        _selectedDob?.month ?? 1,
        _selectedDob?.day ?? 1,
      );
      setState(() {
        _selectedDob = estimatedDob;
        _dob.text =
            '${estimatedDob.day.toString().padLeft(2, '0')} / ${estimatedDob.month.toString().padLeft(2, '0')} / $estimatedYear (Est.)';
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    // Ensure _selectedDob is set from age if user only entered age
    if (_selectedDob == null && _age.text.trim().isNotEmpty) {
      final ageNum = int.tryParse(_age.text.trim());
      if (ageNum != null) {
        _selectedDob = DateTime(DateTime.now().year - ageNum, 1, 1);
      }
    }

    setState(() => _saving = true);
    try {
      final famProv = context.read<FamilyProvider>();

      // Determine or create a valid family
      String famId;
      if (_selectedFamilyId != null && _selectedFamilyId!.isNotEmpty) {
        famId = _selectedFamilyId!;
      } else if (famProv.families.isNotEmpty) {
        famId = famProv.families.first.id;
      } else {
        // Automatically create a default family for this user if none exists
        await famProv.addFamily({'family_id': 'FAM-1001', 'name': 'My Family'});
        famId = famProv.families.first.id;
      }

      if (!mounted) return;
      final memberName = _name.text.trim();
      if (_pickedPhotoBytes != null) {
        AvatarMemoryCache.set(memberName, _pickedPhotoBytes!);
        AvatarMemoryCache.set(memberName.toLowerCase(), _pickedPhotoBytes!);
        if (_avatarUrl != null) {
          AvatarMemoryCache.set(_avatarUrl!, _pickedPhotoBytes!);
        }
      }

      await context.read<MemberProvider>().addMember({
        'family_id': famId,
        'name': memberName,
        'relation': _selectedRelation ?? 'Other',
        'dob': _selectedDob?.toIso8601String(),
        'blood_group': _selectedBloodGroup,
        'allergies': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'avatar_url': _avatarUrl,
        'emergency_contact': _emergencyContact.text.trim().isNotEmpty
            ? _emergencyContact.text.trim()
            : null,
        'parent_id': _selectedParentId,
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
    final memberProv = context.watch<MemberProvider>();
    final familyProv = context.watch<FamilyProvider>();
    final familyId =
        _selectedFamilyId ??
        (familyProv.families.isNotEmpty ? familyProv.families.first.id : null);
    final possibleParents = memberProv.members
        .where((member) => member.familyId == familyId)
        .toList();

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
                // Top Card: Create patient profile with Cloudinary Avatar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          children: [
                            if (_avatarUrl != null)
                              AppAvatar(
                                name: _name.text.isNotEmpty ? _name.text : 'M',
                                avatarUrl: _avatarUrl,
                                size: 68,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              )
                            else
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDEF2D7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: _uploadingAvatar
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Color(0xFF235E1E),
                                        size: 28,
                                      ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Member Photo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _uploadingAvatar
                                    ? 'Uploading photo...'
                                    : _avatarUrl != null
                                    ? 'Photo set for this member ✓'
                                    : 'Tap circle to add photo for this member',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _avatarUrl != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _avatarUrl != null
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Full name
                const Text(
                  'Full name',
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
                    hintText: 'Enter member name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter member name'
                      : null,
                ),
                const SizedBox(height: 18),

                // Relationship
                const Text(
                  'Relationship',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRelation,
                  decoration: const InputDecoration(
                    hintText: 'Select relationship',
                    prefixIcon: Icon(
                      Icons.groups_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  items: _relations.map((rel) {
                    return DropdownMenuItem<String>(
                      value: rel,
                      child: Text(rel),
                    );
                  }).toList(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please select relationship'
                      : null,
                  onChanged: (val) => setState(() => _selectedRelation = val),
                ),
                if (_selectedRelation == 'Son' ||
                    _selectedRelation == 'Daughter') ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Parent / linked adult',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedParentId,
                    decoration: const InputDecoration(
                      hintText: 'Select parent or guardian',
                      prefixIcon: Icon(
                        Icons.account_tree_outlined,
                        color: AppColors.textLight,
                        size: 20,
                      ),
                    ),
                    items: possibleParents.map((parent) {
                      return DropdownMenuItem<String>(
                        value: parent.id,
                        child: Text('${parent.name} • ${parent.relation}'),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedParentId = value),
                  ),
                ],
                const SizedBox(height: 18),

                // Age (Mandatory) & Date of Birth
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Age in years (REQUIRED)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Text(
                                'Age (years)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '*',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 35',
                              prefixIcon: Icon(
                                Icons.cake_outlined,
                                color: AppColors.textLight,
                                size: 20,
                              ),
                            ),
                            onChanged: _onAgeChanged,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Age is required';
                              }
                              final num = int.tryParse(v.trim());
                              if (num == null || num < 0 || num > 125) {
                                return 'Enter 0 - 125';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Date of birth (Optional exact picker)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date of birth',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dob,
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Blood group
                const Text(
                  'Blood group',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  decoration: const InputDecoration(
                    hintText: 'Select blood group',
                    prefixIcon: Icon(
                      Icons.favorite_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  items: _bloodGroups.map((bg) {
                    return DropdownMenuItem<String>(value: bg, child: Text(bg));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBloodGroup = val),
                ),
                const SizedBox(height: 18),

                // Allergies / conditions
                const Text(
                  'Allergies / conditions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Optional medical notes',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Emergency contact',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emergencyContact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Name and phone number',
                    prefixIcon: Icon(
                      Icons.emergency_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
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
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
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
