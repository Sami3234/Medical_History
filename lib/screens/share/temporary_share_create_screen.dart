import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/member_model.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/visit_provider.dart';
import '../../services/temporary_share/temporary_share_models.dart';
import '../../services/temporary_share/temporary_share_service.dart';
import '../../utils/extensions.dart';

class TemporaryShareCreateScreen extends StatefulWidget {
  final String memberId;

  const TemporaryShareCreateScreen({super.key, required this.memberId});

  @override
  State<TemporaryShareCreateScreen> createState() =>
      _TemporaryShareCreateScreenState();
}

class _TemporaryShareCreateScreenState
    extends State<TemporaryShareCreateScreen> {
  final _service = TemporaryShareService();

  bool _shareProfile = true;
  bool _shareVisits = true;
  bool _shareDocuments = true;
  bool _creating = false;
  double _progress = 0;
  TemporaryShareCredentials? _credentials;

  Future<void> _create(MemberModel member) async {
    if (!_shareProfile && !_shareVisits && !_shareDocuments) return;
    setState(() {
      _creating = true;
      _progress = 0;
    });
    try {
      final visits = context.read<VisitProvider>().visits;
      final files = context
          .read<RecordsProvider>()
          .files
          .where((item) => item.memberId == member.id)
          .toList();
      final credentials = await _service.createShare(
        member: member,
        visits: visits,
        documents: files,
        scope: {
          'profile': _shareProfile,
          'visits': _shareVisits,
          'documents': _shareDocuments,
        },
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _credentials = credentials);
    } catch (error) {
      if (mounted) {
        context.showSnack(error.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) context.showSnack('$label copied');
  }

  Future<void> _revoke() async {
    await _service.revokeAllForMember(widget.memberId);
    if (!mounted) return;
    setState(() => _credentials = null);
    context.showSnack('Temporary access stopped');
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>().members;
    final member = members
        .where((item) => item.id == widget.memberId)
        .firstOrNull;
    if (member == null) {
      return const Scaffold(
        body: Center(child: Text('Member profile is unavailable.')),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(title: const Text('Temporary medical access')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_credentials == null)
            _buildSetup(member)
          else
            _buildCredentials(member, _credentials!),
        ],
      ),
    );
  }

  Widget _buildSetup(MemberModel member) {
    final visits = context
        .watch<VisitProvider>()
        .visits
        .where((item) => item.memberId == member.id)
        .length;
    final files = context
        .watch<RecordsProvider>()
        .files
        .where((item) => item.memberId == member.id)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.enhanced_encryption_outlined,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                member.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Create read-only access for 15 minutes.',
                style: TextStyle(color: Color(0xE6FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Choose what can be viewed',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _choice(
          value: _shareProfile,
          icon: Icons.badge_outlined,
          title: 'Health profile',
          subtitle: 'Basic details, allergies and emergency contact',
          onChanged: (value) => setState(() => _shareProfile = value),
        ),
        _choice(
          value: _shareVisits,
          icon: Icons.event_note_outlined,
          title: 'Doctor visits',
          subtitle: '$visits visit records',
          onChanged: (value) => setState(() => _shareVisits = value),
        ),
        _choice(
          value: _shareDocuments,
          icon: Icons.folder_copy_outlined,
          title: 'Medical files',
          subtitle: '$files files, up to 100 MB total',
          onChanged: (value) => setState(() => _shareDocuments = value),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A temporary ID and one-time passcode will be created. Access is read-only and closes automatically after 15 minutes.',
                ),
              ),
            ],
          ),
        ),
        if (_creating) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          const SizedBox(height: 8),
          Text(
            _progress == 0
                ? 'Preparing protected record...'
                : 'Preparing ${(_progress * 100).round()}%',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed:
                _creating ||
                    (!_shareProfile && !_shareVisits && !_shareDocuments)
                ? null
                : () => _create(member),
            icon: const Icon(Icons.lock_clock_outlined),
            label: Text(_creating ? 'Preparing...' : 'Create temporary access'),
          ),
        ),
      ],
    );
  }

  Widget _choice({
    required bool value,
    required IconData icon,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: value,
        onChanged: _creating
            ? null
            : (selected) => onChanged(selected ?? false),
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildCredentials(
    MemberModel member,
    TemporaryShareCredentials credentials,
  ) {
    final expiry = DateFormat(
      'hh:mm a',
    ).format(credentials.expiresAt.toLocal());
    return Column(
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: AppColors.primary,
          size: 58,
        ),
        const SizedBox(height: 12),
        Text(
          'Temporary access is ready',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Share both values with the person viewing ${member.name}\'s record.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appTextSecondary),
        ),
        const SizedBox(height: 24),
        _credentialCard(
          label: 'TEMPORARY ID',
          value: credentials.temporaryId,
          onCopy: () => _copy(credentials.temporaryId, 'Temporary ID'),
        ),
        const SizedBox(height: 12),
        _credentialCard(
          label: 'ONE-TIME PASSCODE',
          value: credentials.otp,
          onCopy: () => _copy(credentials.otp, 'Passcode'),
        ),
        const SizedBox(height: 16),
        Text(
          'Read-only access ends at $expiry',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _revoke,
            icon: const Icon(Icons.link_off_rounded, color: Colors.red),
            label: const Text(
              'Stop access now',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _credentialCard({
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded)),
        ],
      ),
    );
  }
}
