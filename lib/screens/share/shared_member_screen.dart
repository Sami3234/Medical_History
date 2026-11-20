import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../services/temporary_share/temporary_share_models.dart';
import '../../services/temporary_share/temporary_share_service.dart';
import '../../utils/extensions.dart';

class SharedMemberScreen extends StatefulWidget {
  final String temporaryId;
  final String otp;

  const SharedMemberScreen({super.key, this.temporaryId = '', this.otp = ''});

  @override
  State<SharedMemberScreen> createState() => _SharedMemberScreenState();
}

class _SharedMemberScreenState extends State<SharedMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _temporaryId = TextEditingController();
  final _otp = TextEditingController();
  final _service = TemporaryShareService();

  TemporarySharedRecord? _record;
  String? _error;
  bool _loading = false;
  bool _showPasscode = false;
  String? _openingDocumentToken;
  Timer? _expiryTimer;
  final _temporaryFiles = <File>{};

  @override
  void initState() {
    super.initState();
    _temporaryId.text = widget.temporaryId;
    _otp.text = widget.otp;
    if (widget.temporaryId.isNotEmpty && widget.otp.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRecord());
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    unawaited(_deleteTemporaryFiles());
    _temporaryId.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _openRecord() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await _service.redeem(
        temporaryId: _normalizeId(_temporaryId.text),
        otp: _otp.text,
      );
      if (!mounted) return;
      setState(() => _record = record);
      _scheduleExpiry(record.expiresAt);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDocument(TemporarySharedDocument document) async {
    final record = _record;
    if (record == null) return;
    setState(() => _openingDocumentToken = document.token);
    try {
      final decrypted = await _service.downloadDocument(
        record: record,
        document: document,
      );
      final directory = await getTemporaryDirectory();
      final safeName = document.fileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}shared_${document.token}_$safeName',
      );
      await file.writeAsBytes(decrypted.bytes, flush: true);
      _temporaryFiles.add(file);
      final result = await OpenFilex.open(file.path, type: document.mimeType);
      if (result.type != ResultType.done && mounted) {
        context.showSnack('No compatible viewer is available.', isError: true);
      }
    } catch (error) {
      if (mounted) context.showSnack(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _openingDocumentToken = null);
    }
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _expiryTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      _expireRecord();
      return;
    }
    _expiryTimer = Timer(remaining, _expireRecord);
  }

  void _expireRecord() {
    if (!mounted) return;
    setState(() {
      _record = null;
      _error = 'Temporary access has expired.';
      _openingDocumentToken = null;
      _otp.clear();
    });
    unawaited(_deleteTemporaryFiles());
  }

  Future<void> _deleteTemporaryFiles() async {
    final files = _temporaryFiles.toList();
    _temporaryFiles.clear();
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('View shared medical record'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
      ),
      body: _record == null ? _buildAccessForm() : _buildRecord(_record!),
    );
  }

  Widget _buildAccessForm() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Container(
            width: 76,
            height: 76,
            margin: const EdgeInsets.symmetric(horizontal: 115),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Temporary access',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Enter the temporary ID and passcode provided by the record owner.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appTextSecondary),
          ),
          const SizedBox(height: 28),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Temporary ID',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _temporaryId,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(14),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'ABCD-EFGH-2345',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final normalized = _normalizeId(value ?? '');
                    return RegExp(
                          r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$',
                        ).hasMatch(normalized)
                        ? null
                        : 'Enter the complete temporary ID.';
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  '6-digit passcode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  obscureText: !_showPasscode,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: '000000',
                    prefixIcon: const Icon(Icons.password_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPasscode
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPasscode = !_showPasscode),
                    ),
                  ),
                  validator: (value) =>
                      RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter the 6-digit passcode.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _openRecord,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(
                      _loading ? 'Verifying...' : 'Open read-only record',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecord(TemporarySharedRecord record) {
    final member = record.member;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                member['name'] as String? ?? 'Family member',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Read-only until ${DateFormat('hh:mm a').format(record.expiresAt.toLocal())}',
                style: const TextStyle(color: Color(0xE6FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section('Health profile', [
          _info('Relation', member['relation']),
          _info('Date of birth', _formatDate(member['dob'])),
          _info('Gender', member['gender']),
          _info('Blood group', member['blood_group']),
          _info('Allergies', member['allergies']),
          _info('Emergency contact', member['emergency_contact']),
          _info('Notes', member['notes']),
        ]),
        const SizedBox(height: 14),
        _section(
          'Visits (${record.visits.length})',
          record.visits.isEmpty
              ? [const Text('No visits were shared.')]
              : record.visits.map((visit) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      visit['diagnosis'] as String? ?? 'Medical visit',
                    ),
                    subtitle: Text(
                      '${visit['doctor_name'] ?? 'Doctor not recorded'} • ${_formatDate(visit['visit_date'])}',
                    ),
                    isThreeLine:
                        (visit['treatment']?.toString().trim().isNotEmpty ??
                        false),
                    trailing: visit['treatment'] == null
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showVisit(visit),
                  );
                }).toList(),
        ),
        const SizedBox(height: 14),
        _section(
          'Documents (${record.documents.length})',
          record.documents.isEmpty
              ? [const Text('No documents were shared.')]
              : record.documents.map((document) {
                  final opening = _openingDocumentToken == document.token;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document.title),
                    subtitle: Text(
                      '${document.fileType} • ${_formatBytes(document.size)}',
                    ),
                    trailing: opening
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new_rounded),
                    onTap: opening ? null : () => _openDocument(document),
                  );
                }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Read-only temporary view. Changes to the original record are not allowed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVisit(Map<String, dynamic> visit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          shrinkWrap: true,
          children: [
            Text(
              visit['diagnosis'] as String? ?? 'Medical visit',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _info('Date', _formatDate(visit['visit_date'])),
            _info('Doctor', visit['doctor_name']),
            _info('Hospital', visit['hospital']),
            _info('Symptoms', visit['symptoms']),
            _info('Treatment', visit['treatment']),
            _info('Notes', visit['notes']),
            _info('Follow-up', _formatDate(visit['follow_up_date'])),
          ],
        ),
      ),
    );
  }

  String _normalizeId(String value) {
    final raw = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.length != 12) return value.trim().toUpperCase();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8)}';
  }

  String _formatDate(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return '';
    final date = DateTime.tryParse(value);
    return date == null
        ? 'Date not recorded'
        : DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
