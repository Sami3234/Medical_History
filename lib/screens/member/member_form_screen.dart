import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/supabase_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_avatar.dart';

class MemberFormScreen extends StatefulWidget {
  final String? memberId;

  const MemberFormScreen({super.key, this.memberId});

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
  bool _loadingMember = false;
  bool _editingOwner = false;

  bool get _isEdit => widget.memberId != null;

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

  String? _relationLimitError({
    required String relation,
    required String familyId,
    required List<dynamic> members,
  }) {
    final normalized = relation.toLowerCase().trim();
    late final int limit;
    late final String label;
    late final bool Function(String relation) matches;

    if (normalized == 'father') {
      limit = 1;
      label = 'father';
      matches = (value) => value == 'father';
    } else if (normalized == 'mother') {
      limit = 3;
      label = 'mothers';
      matches = (value) => value == 'mother';
    } else if (normalized == 'grandfather') {
      limit = 1;
      label = 'grandfather';
      matches = (value) => value == 'grandfather';
    } else if (normalized == 'grandmother') {
      limit = 1;
      label = 'grandmother';
      matches = (value) => value == 'grandmother';
    } else if (normalized == 'brother' || normalized == 'sister') {
      limit = 10;
      label = 'brothers and sisters';
      matches = (value) => value == 'brother' || value == 'sister';
    } else if (normalized == 'son' || normalized == 'daughter') {
      limit = 10;
      label = 'sons and daughters';
      matches = (value) => value == 'son' || value == 'daughter';
    } else {
      return null;
    }

    final currentCount = members.where((member) {
      if (member.familyId != familyId || member.id == widget.memberId) {
        return false;
      }
      return matches(member.relation.toLowerCase().trim());
    }).length;

    if (currentCount >= limit) {
      return 'Maximum $limit $label can be added to one family.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.memberId;
    if (id == null) return;

    setState(() => _loadingMember = true);
    try {
      final memberProv = context.read<MemberProvider>();
      var member = memberProv.members.where((m) => m.id == id).firstOrNull;

      if (member == null) {
        final uid =
            context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
        if (uid != null) await memberProv.loadAll(uid);
        member = memberProv.members.where((m) => m.id == id).firstOrNull;
      }

      if (member == null || !mounted) {
        if (mounted) {
          context.showSnack('Member not found.', isError: true);
          context.pop();
        }
        return;
      }

      _name.text = member.name;
      if (!_relations.contains(member.relation) && member.relation.isNotEmpty) {
        _relations.add(member.relation);
      }
      _selectedRelation = member.relation;
      _editingOwner = member.relation.toLowerCase().trim() == 'self';
      _selectedBloodGroup = member.bloodGroup;
      _notes.text = member.allergies ?? member.notes ?? '';
      _emergencyContact.text = member.emergencyContact ?? '';
      _avatarUrl = member.avatarUrl;
      _selectedFamilyId = member.familyId;
      _selectedParentId = member.parentId;
      _selectedDob = member.dob;
      if (member.dob != null) {
        final dob = member.dob!;
        _dob.text =
            '${dob.day.toString().padLeft(2, '0')} / ${dob.month.toString().padLeft(2, '0')} / ${dob.year}';
        final now = DateTime.now();
        var age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
        _age.text = age.clamp(0, 125).toString();
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loadingMember = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final croppedBytes = await ImageCropperService.cropAvatar(
        file: picked,
        context: context,
      );
      if (croppedBytes == null || !mounted) return;

      _pickedPhotoBytes = croppedBytes;
      final dataUri = 'data:image/png;base64,${base64Encode(croppedBytes)}';

      AvatarMemoryCache.set(dataUri, croppedBytes);
      if (_name.text.trim().isNotEmpty) {
        AvatarMemoryCache.set(_name.text.trim(), croppedBytes);
        AvatarMemoryCache.set(_name.text.trim().toLowerCase(), croppedBytes);
      }
      setState(() => _avatarUrl = dataUri);

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
      } else if (mounted) {
        context.showSnack('Member photo saved successfully!');
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

    if (_selectedDob == null && _age.text.trim().isNotEmpty) {
      final ageNum = int.tryParse(_age.text.trim());
      if (ageNum != null) {
        _selectedDob = DateTime(DateTime.now().year - ageNum, 1, 1);
      }
    }

    setState(() => _saving = true);
    try {
      final famProv = context.read<FamilyProvider>();
      final memberProv = context.read<MemberProvider>();
      final memberName = _name.text.trim();
      final authName = context
          .read<AuthProvider>()
          .user
          ?.fullName
          .trim()
          .toLowerCase();
      String? ownerMemberId;
      for (final member in memberProv.members) {
        final isOwner =
            member.relation.toLowerCase().trim() == 'self' ||
            (authName != null &&
                authName.isNotEmpty &&
                member.name.trim().toLowerCase() == authName);
        if (isOwner) {
          ownerMemberId = member.id;
          break;
        }
      }
      final isChild =
          _selectedRelation == 'Son' || _selectedRelation == 'Daughter';

      String famId;
      if (_selectedFamilyId != null && _selectedFamilyId!.isNotEmpty) {
        famId = _selectedFamilyId!;
      } else if (famProv.families.isNotEmpty) {
        famId = famProv.families.first.id;
      } else {
        await famProv.addFamily({'family_id': 'FAM-1001', 'name': 'My Family'});
        famId = famProv.families.first.id;
      }

      final relationLimitError = _relationLimitError(
        relation: _selectedRelation ?? 'Other',
        familyId: famId,
        members: memberProv.members,
      );
      if (relationLimitError != null) {
        if (mounted) context.showSnack(relationLimitError, isError: true);
        return;
      }

      if (_pickedPhotoBytes != null) {
        AvatarMemoryCache.set(memberName, _pickedPhotoBytes!);
        AvatarMemoryCache.set(memberName.toLowerCase(), _pickedPhotoBytes!);
        if (_avatarUrl != null) {
          AvatarMemoryCache.set(_avatarUrl!, _pickedPhotoBytes!);
        }
        if (_isEdit) {
          AvatarMemoryCache.set(widget.memberId!, _pickedPhotoBytes!);
        }
      }

      final payload = <String, dynamic>{
        'name': memberName,
        'relation': _editingOwner ? 'Self' : (_selectedRelation ?? 'Other'),
        'dob': _selectedDob?.toIso8601String(),
        'blood_group': _selectedBloodGroup,
        'allergies': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        'avatar_url': _avatarUrl,
        'emergency_contact': _emergencyContact.text.trim().isNotEmpty
            ? _emergencyContact.text.trim()
            : null,
        'parent_id': isChild ? ownerMemberId : _selectedParentId,
      };

      if (_isEdit) {
        final ok = await memberProv.updateMember(widget.memberId!, payload);
        if (!mounted) return;
        if (!ok) {
          context.showSnack(
            memberProv.error ?? 'Failed to update member',
            isError: true,
          );
          return;
        }
        if (_editingOwner) {
          final authProvider = context.read<AuthProvider>();
          await authProvider.updateProfile({
            'full_name': memberName,
            if (_avatarUrl != null) 'avatar_url': _avatarUrl,
          });
          if (!mounted) return;
        }
        context.showSnack('Family member updated');
        context.pop();
        return;
      }

      payload['family_id'] = famId;
      final ok = await memberProv.addMember(payload);
      if (!mounted) return;
      if (!ok) {
        context.showSnack(
          memberProv.error ?? 'Failed to save member',
          isError: true,
        );
        return;
      }
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
    final authName = context
        .watch<AuthProvider>()
        .user
        ?.fullName
        .trim()
        .toLowerCase();
    final possibleParents = memberProv.members
        .where(
          (member) =>
              member.familyId == familyId &&
              member.id != widget.memberId &&
              (member.relation.toLowerCase().trim() == 'self' ||
                  (authName != null &&
                      authName.isNotEmpty &&
                      member.name.trim().toLowerCase() == authName)),
        )
        .toList();

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit family member' : 'Add family member'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loadingMember
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.2,
                          ),
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
                              onTap: _uploadingAvatar
                                  ? null
                                  : _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  if (_avatarUrl != null)
                                    AppAvatar(
                                      name: _name.text.isNotEmpty
                                          ? _name.text
                                          : 'M',
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
                                                child:
                                                    CircularProgressIndicator(
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
                                onTap: _uploadingAvatar
                                    ? null
                                    : _pickAndUploadAvatar,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Member Photo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: context.appTextPrimary,
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

                      Text(
                        'Full name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
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

                      Text(
                        'Relationship',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('relation-$_selectedRelation'),
                        initialValue: _selectedRelation,
                        decoration: const InputDecoration(
                          hintText: 'Select relationship',
                          prefixIcon: Icon(
                            Icons.groups_outlined,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                        ),
                        items: _relations
                            .where((rel) => _isEdit || rel != 'Self')
                            .map((rel) {
                              return DropdownMenuItem<String>(
                                value: rel,
                                child: Text(rel),
                              );
                            })
                            .toList(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please select relationship'
                            : null,
                        onChanged: _editingOwner
                            ? null
                            : (val) => setState(() => _selectedRelation = val),
                      ),
                      if (_editingOwner) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Self is your permanent owner profile and its relationship cannot be changed.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                      if (_selectedRelation == 'Son' ||
                          _selectedRelation == 'Daughter') ...[
                        const SizedBox(height: 18),
                        Text(
                          'Parent / linked adult',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey('parent-$_selectedParentId'),
                          initialValue:
                              possibleParents.any(
                                (parent) => parent.id == _selectedParentId,
                              )
                              ? _selectedParentId
                              : possibleParents.firstOrNull?.id,
                          decoration: const InputDecoration(
                            hintText: 'Owner profile is the parent',
                            prefixIcon: Icon(
                              Icons.account_tree_outlined,
                              color: AppColors.textLight,
                              size: 20,
                            ),
                          ),
                          items: possibleParents.map((parent) {
                            return DropdownMenuItem<String>(
                              value: parent.id,
                              child: Text(
                                '${parent.name} • ${parent.relation}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedParentId = value),
                        ),
                      ],
                      const SizedBox(height: 18),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Age (years)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: context.appTextPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    const Text(
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
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date of birth',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.appTextPrimary,
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

                      Text(
                        'Blood group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('blood-$_selectedBloodGroup'),
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
                          return DropdownMenuItem<String>(
                            value: bg,
                            child: Text(bg),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedBloodGroup = val),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Allergies / conditions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
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
                      Text(
                        'Emergency contact',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isEdit
                                          ? 'Save changes'
                                          : 'Save family member',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!_isEdit)
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
