import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? memberId;

  const UploadDocScreen({super.key, this.memberId});

  @override
  State<UploadDocScreen> createState() => _UploadDocScreenState();
}

class _UploadDocScreenState extends State<UploadDocScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String _selectedType = 'Prescription';
  String? _selectedMemberId;
  String? _selectedVisitId;
  String? _pickedFileName;
  String? _pickedFilePath;
  Uint8List? _pickedFileBytes;
  String? _ocrText;
  bool _uploading = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.memberId;
  }

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
    if (_capturing || _uploading) return;
    setState(() => _capturing = true);
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final permission =
            await NativeDocumentService.requestCameraPermission();
        if (permission != 'granted') {
          if (!mounted) return;
          await _showCameraPermissionDialog(
            permanentlyDenied: permission == 'permanentlyDenied',
          );
          return;
        }

        try {
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
        } on PlatformException catch (error) {
          if (error.code == 'SCAN_CANCELLED') return;
          if (mounted) {
            context.showSnack(
              'Smart scanner unavailable. Opening the camera instead.',
            );
          }
        }
      }
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 3200,
      );
      if (picked == null) return;
      if (!mounted) return;
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
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = 'Scanned medical document';
        }
      });
    } on PlatformException catch (error) {
      if (mounted) {
        context.showSnack(
          error.code == 'camera_access_denied'
              ? 'Camera permission is required to scan a document.'
              : 'Camera could not be opened. Please try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnack(
          'Camera could not be opened. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _showCameraPermissionDialog({
    required bool permanentlyDenied,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
        title: const Text('Camera permission needed'),
        content: Text(
          permanentlyDenied
              ? 'Camera access is blocked. Open app settings and allow Camera to scan medical documents.'
              : 'Allow camera access when prompted, then tap Scan document again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          if (permanentlyDenied)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await NativeDocumentService.openAppSettings();
              },
              child: const Text('Open settings'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Got it'),
            ),
        ],
      ),
    );
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
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

      final fileTypeVal = switch (_selectedType) {
        'Prescription' => 'prescription',
        'Lab report' => 'labReport',
        'X-Ray / Scan' => 'scan',
        'Discharge summary' => 'dischargeSummary',
        'Insurance' => 'insurance',
        _ => 'other',
      };

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
    final records = context.read<RecordsProvider>();
    setState(() => _uploading = true);
    try {
      var bytes = _pickedFileBytes;
      if (bytes == null && _pickedFilePath != null) {
        bytes = await File(_pickedFilePath!).readAsBytes();
      }
      if (bytes == null) throw StateError('File could not be read');
      await records.addDraft(
        fileName: _pickedFileName!,
        bytes: bytes,
        mimeType: _mimeTypeFor(_pickedFileName!),
      );
      if (!mounted) return;
      context.showSnack('Saved to Draft Inbox for later organization');
      context.pop();
    } catch (_) {
      if (mounted) {
        context.showSnack('Could not save this draft', isError: true);
      }
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
    final visits = context
        .watch<VisitProvider>()
        .visits
        .where(
          (visit) =>
              _selectedMemberId == null || visit.memberId == _selectedMemberId,
        )
        .toList();
    final members = memberProv.members;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Add medical document'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save a health record',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Scan with smart document detection or choose an existing PDF/image.',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Large File Dropzone
                GestureDetector(
                  onTap: _uploading || _capturing ? null : _showFileSourceSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: context.isDarkMode
                          ? const LinearGradient(
                              colors: [Color(0xFF173B29), Color(0xFF102D21)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.heroSubtleGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _pickedFileName == null
                            ? context.appBorder
                            : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(28),
                            shape: BoxShape.circle,
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  _pickedFileName == null
                                      ? Icons.document_scanner_outlined
                                      : Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 34,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pickedFileName ?? 'Choose a file to upload',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pickedFileName == null
                              ? 'PDF, JPG or PNG • Maximum 10 MB'
                              : 'Ready to save • Tap to replace',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_pickedFileName != null) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _uploading
                                ? null
                                : () => setState(() {
                                    _pickedFileName = null;
                                    _pickedFilePath = null;
                                    _pickedFileBytes = null;
                                    _ocrText = null;
                                  }),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Remove file'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading || _capturing
                            ? null
                            : _captureDocument,
                        icon: const Icon(
                          Icons.document_scanner_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _capturing ? 'Opening...' : 'Scan document',
                        ),
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
                Text(
                  'Document type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _buildTypeChip('Prescription'),
                    _buildTypeChip('Lab report'),
                    _buildTypeChip('X-Ray / Scan'),
                    _buildTypeChip('Discharge summary'),
                    _buildTypeChip('Insurance'),
                    _buildTypeChip('Other'),
                  ],
                ),
                const SizedBox(height: 24),

                // Document title
                Text(
                  'Document title',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Document title is required'
                      : null,
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
                Text(
                  'Family member',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                  onChanged: (val) => setState(() {
                    _selectedMemberId = val;
                    _selectedVisitId = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Please select a family member' : null,
                ),
                const SizedBox(height: 18),

                // Visit reference (optional)
                Text(
                  'Visit reference',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                  onChanged: (value) =>
                      setState(() => _selectedVisitId = value),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.appSurfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The original stays on this device. Cloud backup runs only when configured.',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

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
          color: isSelected ? AppColors.primary : context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appBorder,
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
            color: isSelected ? Colors.white : context.appTextPrimary,
          ),
        ),
      ),
    );
  }
}
