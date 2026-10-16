import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/theme.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../utils/extensions.dart';

class UploadDocScreen extends StatefulWidget {
  const UploadDocScreen({super.key});

  @override
  State<UploadDocScreen> createState() => _UploadDocScreenState();
}

class _UploadDocScreenState extends State<UploadDocScreen> {
  final _titleCtrl = TextEditingController();
  String _selectedType = 'Prescription';
  String? _selectedMemberId;
  String? _pickedFileName;
  bool _uploading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedFileName = res.files.first.name;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = res.files.first.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnack('File picking cancelled or not supported', isError: true);
      }
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      context.showSnack('Please enter a document title', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final memberProv = context.read<MemberProvider>();
      final mId = _selectedMemberId ?? (memberProv.members.isNotEmpty ? memberProv.members.first.id : 'mem-3');

      final fileTypeVal = _selectedType == 'Prescription'
          ? 'prescription'
          : _selectedType == 'Lab report'
              ? 'labReport'
              : 'other';

      context.read<RecordsProvider>().addDocument(
        memberId: mId,
        title: _titleCtrl.text.trim(),
        fileType: fileTypeVal,
      );

      if (!mounted) return;
      context.showSnack('Document uploaded successfully');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Failed to upload: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final members = memberProv.members;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Upload medical file'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large File Dropzone
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8EC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFCBE8C6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDEF2D7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF38931F),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pickedFileName ?? 'Choose a file to upload',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Images or PDF • Up to 10 MB',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section: Document type
              const Text(
                'Document type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeChip('Prescription'),
                  const SizedBox(width: 10),
                  _buildTypeChip('Lab report'),
                  const SizedBox(width: 10),
                  _buildTypeChip('Other'),
                ],
              ),
              const SizedBox(height: 24),

              // Document title
              const Text(
                'Document title',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter document name',
                  prefixIcon: Icon(Icons.description_outlined, color: AppColors.textLight, size: 20),
                ),
              ),
              const SizedBox(height: 18),

              // Family member picker
              const Text(
                'Family member',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedMemberId ?? (members.isNotEmpty ? members.first.id : null),
                decoration: const InputDecoration(
                  hintText: 'Select patient',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textLight, size: 20),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedMemberId = val),
              ),
              const SizedBox(height: 18),

              // Visit reference (optional)
              const Text(
                'Visit reference',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Link to doctor visit (optional)',
                  prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textLight, size: 20),
                ),
              ),
              const SizedBox(height: 32),

              // Upload securely button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Upload securely',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    final isSelected = _selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF287D1F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF287D1F) : AppColors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }
}
