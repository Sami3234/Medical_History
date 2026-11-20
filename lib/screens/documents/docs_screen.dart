import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/med_file_model.dart';
import '../../providers/backup_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/member_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/info_banner.dart';
import '../../services/native_document_service.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'All files';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NativeDocumentService.importSharedFilesToDrafts();
      if (mounted) await context.read<RecordsProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDocument(MedFileModel document) async {
    final records = context.read<RecordsProvider>();
    try {
      if ((document.mimeType ?? '').startsWith('image/')) {
        final bytes = await records.readDocumentBytes(document);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
        return;
      }
      final opened = await records.openDocument(document);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No compatible app could open this file.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This local file is no longer available.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(MedFileModel document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
          'This removes the local copy from this device. Existing cloud backups are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<RecordsProvider>().deleteDocument(document.id);
    }
  }

  Future<void> _organizeDraft(MedFileModel draft) async {
    final records = context.read<RecordsProvider>();
    final members = context.read<MemberProvider>().members;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a family member before organizing a draft.'),
        ),
      );
      return;
    }
    String memberId = members.first.id;
    String fileType = 'other';
    final titleController = TextEditingController(
      text: draft.fileName?.split('.').first,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Organize draft'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Document title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: memberId,
                decoration: const InputDecoration(labelText: 'Family member'),
                items: members
                    .map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => memberId = value ?? memberId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: fileType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: const [
                  DropdownMenuItem(
                    value: 'prescription',
                    child: Text('Prescription'),
                  ),
                  DropdownMenuItem(
                    value: 'labReport',
                    child: Text('Lab report'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) =>
                    setDialogState(() => fileType = value ?? fileType),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                titleController.text.trim().isNotEmpty,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (confirmed != true || !mounted) return;
    await records.organizeDraft(
      draft,
      memberId: memberId,
      fileType: fileType,
      title: title,
    );
  }

  Future<void> _deleteDraft(MedFileModel draft) async {
    await context.read<RecordsProvider>().deleteDraft(draft.id);
  }

  @override
  Widget build(BuildContext context) {
    final recordsProv = context.watch<RecordsProvider>();
    final memberProv = context.watch<MemberProvider>();
    final driveConnected = context.watch<BackupProvider>().isConnected;
    final drafts = recordsProv.drafts;
    final files = recordsProv.files.where((f) {
      final name = f.description ?? f.fileUrl.split('/').last;
      final matchesQuery =
          _query.isEmpty || name.toLowerCase().contains(_query.toLowerCase());
      if (!matchesQuery) return false;

      if (_selectedFilter == 'All files') return true;
      if (_selectedFilter == 'Prescriptions') {
        return f.fileType == 'prescription';
      }
      if (_selectedFilter == 'Lab tests') return f.fileType == 'labReport';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR DIGITAL HEALTH FILES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Medical documents',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/documents/upload'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search prescriptions or reports...',
                  hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textLight,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: context.appSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: context.appBorder, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: context.appBorder, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterTab('All files'),
                    const SizedBox(width: 10),
                    _buildFilterTab('Prescriptions'),
                    const SizedBox(width: 10),
                    _buildFilterTab('Lab tests'),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              if (drafts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Draft inbox',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    Text(
                      '${drafts.length} pending',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...drafts.map(
                  (draft) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.inbox_outlined,
                        color: AppColors.warning,
                      ),
                      title: Text(draft.fileName ?? 'Incoming document'),
                      subtitle: const Text(
                        'Not organized yet • Stored locally',
                      ),
                      onTap: () => _openDocument(draft),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'organize') _organizeDraft(draft);
                          if (value == 'delete') _deleteDraft(draft);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'organize',
                            child: Text('Organize'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete draft'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Section: Recent uploads
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent uploads',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  Text(
                    '${files.length} file${files.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Documents List
              if (files.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 38,
                        color: context.appTextSecondary,
                      ),
                      SizedBox(height: 10),
                      Text('No local documents found'),
                    ],
                  ),
                ),
              ...files.map((file) {
                final member =
                    memberProv.members
                        .where((m) => m.id == file.memberId)
                        .firstOrNull ??
                    (memberProv.members.isNotEmpty
                        ? memberProv.members.first
                        : null);

                final fileName =
                    file.description ?? file.fileUrl.split('/').last;
                final isHeartIcon = file.fileType == 'labReport';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _openDocument(file),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.appBorder,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4ED),
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Icon(
                              isHeartIcon
                                  ? Icons.favorite_border_rounded
                                  : Icons.description_outlined,
                              color: AppColors.primaryDark,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.appTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${member?.name ?? "Family Member"} • ${file.fileType == 'prescription'
                                      ? "Prescription"
                                      : file.fileType == 'labReport'
                                      ? "Lab report"
                                      : "Medical report"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${file.createdAt.day} ${_getMonth(file.createdAt.month)} ${file.createdAt.year}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'open') _openDocument(file);
                              if (value == 'delete') _deleteDocument(file);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'open', child: Text('Open')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Storage Info Banner
              InfoBanner(
                icon: driveConnected
                    ? Icons.add_to_drive_outlined
                    : Icons.phone_android_rounded,
                title: 'Documents are stored locally',
                subtitle: driveConnected
                    ? 'Google Drive is connected. Run Backup to protect all local files.'
                    : 'Cloudinary backup is attempted on upload when Drive is not connected.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  String _getMonth(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[month - 1];
  }

  Widget _buildFilterTab(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : context.appBorder,
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
