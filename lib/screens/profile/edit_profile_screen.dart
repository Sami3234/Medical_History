import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/image_cropper_service.dart';
import '../../utils/extensions.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  String? _avatarUrl;
  String _countryCode = '+92';
  bool _uploadingImage = false;
  bool _saving = false;

  static const _countryCodes = [
    {'code': '+92', 'name': 'Pakistan'},
    {'code': '+91', 'name': 'India'},
    {'code': '+971', 'name': 'UAE'},
    {'code': '+966', 'name': 'Saudi Arabia'},
    {'code': '+44', 'name': 'United Kingdom'},
    {'code': '+1', 'name': 'United States / Canada'},
    {'code': '+61', 'name': 'Australia'},
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final savedPhone = user?.phone ?? '';
    final savedCountry = _countryCodes.cast<Map<String, String>?>().firstWhere(
      (country) => savedPhone.startsWith(country?['code'] ?? ''),
      orElse: () => null,
    );
    if (savedCountry != null) {
      _countryCode = savedCountry['code']!;
      _phoneCtrl = TextEditingController(
        text: savedPhone.substring(_countryCode.length).trim(),
      );
    } else {
      _phoneCtrl = TextEditingController(text: savedPhone);
    }
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
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

      // Immediately cache in memory and local storage
      final dataUri = 'data:image/png;base64,${base64Encode(croppedBytes)}';
      AvatarMemoryCache.set('current_user', croppedBytes);
      AvatarMemoryCache.set(_nameCtrl.text.trim(), croppedBytes);
      AvatarMemoryCache.set(_nameCtrl.text.trim().toLowerCase(), croppedBytes);
      AvatarMemoryCache.set(dataUri, croppedBytes);

      setState(() {
        _avatarUrl = dataUri;
        _uploadingImage = true;
      });
      if (mounted) {
        context.showSnack(
          'Profile photo updated successfully!',
          isError: false,
        );
      }

      final result = await CloudinaryService.uploadImage(
        bytes: croppedBytes,
        filename: picked.name,
        folder: 'medical_history/avatars',
      );

      if (result.success && result.secureUrl != null && mounted) {
        AvatarMemoryCache.set(result.secureUrl!, croppedBytes);
        setState(() {
          _avatarUrl = result.secureUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(
          'Unable to pick photo. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final auth = context.read<AuthProvider>();
      await auth.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isNotEmpty
            ? '$_countryCode ${_phoneCtrl.text.trim().replaceFirst(RegExp(r'^\+\d+\s*'), '')}'
            : null,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      });
      final userId = auth.uid;
      if (userId != null && mounted) {
        await Future.wait([
          context.read<MemberProvider>().loadAll(userId),
          context.read<FamilyProvider>().loadFamilies(userId),
        ]);
      }

      if (!mounted) return;
      context.showSnack('Profile updated successfully!', isError: false);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestEmailChange() async {
    final emailController = TextEditingController(text: _emailCtrl.text);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email address'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New email address',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, emailController.text),
            child: const Text('Send verification'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (!mounted || newEmail == null) return;
    final normalized = newEmail.trim();
    if (!normalized.contains('@')) {
      context.showSnack('Enter a valid email address.', isError: true);
      return;
    }
    final ok = await context.read<AuthProvider>().updateEmail(normalized);
    if (!mounted) return;
    context.showSnack(
      ok
          ? 'Verification link sent to your new email address.'
          : (context.read<AuthProvider>().error ?? 'Email update failed.'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initials = (user?.fullName ?? 'User')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // Avatar Container with Camera Badge
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDEF2D7),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _uploadingImage
                              ? const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                        child: Text(
                                          initials.isEmpty ? 'U' : initials,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF235E1E),
                                          ),
                                        ),
                                      ),
                                )
                              : Center(
                                  child: Text(
                                    initials.isEmpty ? 'U' : initials,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF235E1E),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingImage ? null : _pickAndUploadPhoto,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x20000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _uploadingImage ? null : _pickAndUploadPhoto,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    _uploadingImage
                        ? 'Uploading photo...'
                        : 'Change Profile Picture',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Full Name Input
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 18),

                // Email Input (Read-only with badge)
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Email Address (Linked Account)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    fillColor: Colors.grey.shade100,
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _requestEmailChange,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Change email'),
                  ),
                ),
                const SizedBox(height: 18),

                // Phone Input
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '+92 300 1234567',
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 118,
                      maxWidth: 132,
                    ),
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _countryCode,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                            ),
                            items: _countryCodes.map((country) {
                              return DropdownMenuItem<String>(
                                value: country['code'],
                                child: Text(
                                  country['code']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _countryCode = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
