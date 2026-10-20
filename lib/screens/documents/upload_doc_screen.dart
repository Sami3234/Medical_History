import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/visit_provider.dart';
import '../../services/image_cropper_service.dart';
import '../../services/native_document_service.dart';
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
  String? _selectedVisitId;
  String? _pickedFileName;
  String? _pickedFilePath;
  Uint8List? _pickedFileBytes;
  String? _ocrText;
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
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        if (res.files.first.size > 10 * 1024 * 1024) {
          if (mounted) {
            context.showSnack('File must be 10 MB or smaller', isError: true);
          }
          return;
        }
        setState(() {
          _pickedFileName = res.files.first.name;
          _pickedFilePath = res.files.first.path;
          _pickedFileBytes = res.files.first.bytes;
          if (_titleCtrl.text.isEmpty) {
            _titleCtrl.text = res.files.first.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(
          'File selection cancelled or not supported',
          isError: true,
        );
      }
    }
  }

  Future<void> _captureDocument() async {
    try {
      if (Platform.isAndroid) {
        final scanned = await NativeDocumentService.scanDocuments();
        if (scanned.isNotEmpty) {
          final selected = scanned.firstWhere(
            (file) => file.mimeType == 'application/pdf',
            orElse: () => scanned.first,
          );
          final bytes = await File(selected.path).readAsBytes();
          final ocrSource = scanned.firstWhere(
            (file) => file.mimeType.startsWith('image/'),
            orElse: () => selected,
          );
          var title = 'Scanned medical document';
          var extractedText = '';
          if (ocrSource.mimeType.startsWith('image/')) {
            final text = await NativeDocumentService.recognizeText(
              ocrSource.path,
            );
            extractedText = text;
            final firstLine = text
                .split('\n')
                .map((line) => line.trim())
                .firstWhere((line) => line.length > 3, orElse: () => title);
            if (firstLine != title) {
              title = firstLine.length > 80
                  ? firstLine.substring(0, 80)
                  : firstLine;
            }
          }
          if (!mounted) return;
          setState(() {
            _pickedFileName = selected.name;
            _pickedFilePath = null;
            _pickedFileBytes = bytes;
            _ocrText = extractedText.isEmpty ? title : extractedText;
            if (_titleCtrl.text.isEmpty) _titleCtrl.text = title;
          });
          return;
        }
      }
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 3200,
      );
      if (picked == null) return;
      final bytes = await ImageCropperService.cropAvatar(
        file: picked,
        context: context,
        title: 'Adjust scanned document',
      );
      if (bytes == null) return;
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          context.showSnack(
            'Captured image must be 10 MB or smaller',
            isError: true,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _pickedFileName = picked.name;
        _pickedFilePath = null;
        _pickedFileBytes = bytes;
        if (_titleCtrl.text.isEmpty)
          _titleCtrl.text = 'Scanned medical document';
      });
    } catch (_) {
      if (mounted) {
        context.showSnack(
          'Camera could not be opened. Check camera permission.',
          isError: true,
        );
      }
    }
  }

  Future<void> _showFileSourceSheet() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Scan with camera'),
              subtitle: const Text('Capture a clear medical document image'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery/files'),
              subtitle: const Text('Select an existing image or PDF'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (source == 'camera') await _captureDocument();
    if (source == 'file') await _pickFile();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      context.showSnack('Please enter a document title', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final memberProv = context.read<MemberProvider>();
      final mId =
          _selectedMemberId ??
          (memberProv.members.isNotEmpty ? memberProv.members.first.id : null);
      if (mId == null) {
        context.showSnack('Please add a family member first', isError: true);
        return;
      }

      final fileTypeVal = _selectedType == 'Prescription'
          ? 'prescription'
          : _selectedType == 'Lab report'
          ? 'labReport'
          : 'other';

      if (_pickedFileName == null) {
        context.showSnack('Please choose a document to upload', isError: true);
        return;
      }

      Uint8List? bytes = _pickedFileBytes;
      if (bytes == null && _pickedFilePath != null) {
        try {
          bytes = await File(_pickedFilePath!).readAsBytes();
        } catch (_) {}
      }

      if (bytes == null) {
        throw StateError('The selected file could not be read.');
      }

      if (!mounted) return;
      final records = context.read<RecordsProvider>();
      final document = await records.addDocument(
        memberId: mId,
        title: _titleCtrl.text.trim(),
        fileType: fileTypeVal,
        fileName: _pickedFileName!,
        bytes: bytes,
        mimeType: _mimeTypeFor(_pickedFileName!),
        visitId: _selectedVisitId,
        ocrText: _ocrText,
      );

      if (!mounted) return;
      final driveConnected = context.read<BackupProvider>().isConnected;
      var message = 'Saved locally on this device.';
      if (!driveConnected) {
        final backedUp = await records.backupDocumentToCloudinary(document);
        message = backedUp
            ? 'Saved locally and backed up to Cloudinary.'
            : 'Saved locally. Cloud backup is not configured or unavailable.';
      } else {
        message = 'Saved locally. It will be included in your Drive backup.';
      }
      if (!mounted) return;
      context.showSnack(message);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
        'Failed to upload document. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_pickedFileName == null) {
      context.showSnack('Choose a file before saving a draft', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      var bytes = _pickedFileBytes;
      if (bytes == null && _pickedFilePath != null) {
        bytes = await File(_pickedFilePath!).readAsBytes();
      }
      if (bytes == null) throw StateError('File could not be read');
      await context.read<RecordsProvider>().addDraft(
        fileName: _pickedFileName!,
        bytes: bytes,
        mimeType: _mimeTypeFor(_pickedFileName!),
      );
      if (!mounted) return;
      context.showSnack('Saved to Draft Inbox for later organization');
      context.pop();
    } catch (_) {
      if (mounted)
        context.showSnack('Could not save this draft', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final visits = context.watch<VisitProvider>().visits;
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
                onTap: _showFileSourceSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _captureDocument,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Use camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickFile,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('Browse files'),
                    ),
                  ),
                ],
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeChip('Prescription'),
                    const SizedBox(width: 10),
                    _buildTypeChip('Lab report'),
                    const SizedBox(width: 10),
                    _buildTypeChip('Other'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Document title
              const Text(
                'Document title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter document name',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Family member picker
              const Text(
                'Family member',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue:
                    _selectedMemberId ??
                    (members.isNotEmpty ? members.first.id : null),
                decoration: const InputDecoration(
                  hintText: 'Select patient',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(value: m.id, child: Text(m.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedMemberId = val),
              ),
              const SizedBox(height: 18),

              // Visit reference (optional)
              const Text(
                'Visit reference',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedVisitId,
                decoration: const InputDecoration(
                  hintText: 'Link to doctor visit (optional)',
                  prefixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                ),
                items: visits
                    .map(
                      (visit) => DropdownMenuItem(
                        value: visit.id,
                        child: Text(
                          '${visit.doctorName ?? 'Doctor visit'} - '
                          '${visit.visitDate.day}/${visit.visitDate.month}/${visit.visitDate.year}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedVisitId = value),
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Upload securely',
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _saveDraft,
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Save to Draft Inbox'),
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
