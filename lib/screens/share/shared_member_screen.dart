import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/member_share_service.dart';

class SharedMemberScreen extends StatefulWidget {
  final String token;

  const SharedMemberScreen({super.key, required this.token});

  @override
  State<SharedMemberScreen> createState() => _SharedMemberScreenState();
}

class _SharedMemberScreenState extends State<SharedMemberScreen> {
  late Future<Map<String, dynamic>?> _record;

  @override
  void initState() {
    super.initState();
    _record = MemberShareService.loadSharedRecord(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Shared medical profile'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _record,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null || data['member'] is! Map) {
            return _message('This share link is invalid, expired, or revoked.');
          }
          final member = Map<String, dynamic>.from(data['member'] as Map);
          final visits = (data['visits'] as List?) ?? const [];
          final documents = (data['documents'] as List?) ?? const [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _header(member),
              const SizedBox(height: 16),
              _section('Health profile', [
                _info('Relation', member['relation']),
                _info('Blood group', member['blood_group']),
                _info('Allergies', member['allergies']),
                _info('Emergency contact', member['emergency_contact']),
              ]),
              const SizedBox(height: 14),
              _section(
                'Visits (${visits.length})',
                visits.isEmpty
                    ? [const Text('No visits shared.')]
                    : visits.take(10).map((visit) {
                        final item = Map<String, dynamic>.from(visit as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item['diagnosis'] as String? ?? 'Medical visit',
                          ),
                          subtitle: Text(
                            '${item['doctor_name'] ?? 'Doctor not recorded'} • ${_formatDate(item['visit_date'])}',
                          ),
                        );
                      }).toList(),
              ),
              const SizedBox(height: 14),
              _section(
                'Documents (${documents.length})',
                documents.isEmpty
                    ? [const Text('No documents shared.')]
                    : documents.map((document) {
                        final item = Map<String, dynamic>.from(document as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            item['description'] as String? ??
                                'Medical document',
                          ),
                          subtitle: Text(
                            item['file_type'] as String? ?? 'Document',
                          ),
                        );
                      }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Read-only view • Link access is controlled by the owner.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Map<String, dynamic> member) {
    return Container(
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
          const SizedBox(height: 4),
          const Text(
            'Shared by Medical History',
            style: TextStyle(color: Color(0xDDFFFFFF)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
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
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  String _formatDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    return date == null
        ? 'Date not recorded'
        : DateFormat('dd MMM yyyy').format(date);
  }
}
