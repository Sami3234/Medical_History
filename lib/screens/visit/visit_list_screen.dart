import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/bottom_nav.dart';

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  int? _selectedYear;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid =
          context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
      if (uid != null || !SupabaseConfig.isInitialized) {
        context.read<VisitProvider>().loadRecent(uid ?? 'local');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();
    final years =
        provider.visits.map((visit) => visit.visitDate.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    final visits = provider.visits
        .where(
          (visit) =>
              (_selectedYear == null ||
                  visit.visitDate.year == _selectedYear) &&
              (_query.trim().isEmpty ||
                  [
                        visit.doctorName,
                        visit.memberName,
                        visit.diagnosis,
                        visit.treatment,
                        visit.symptoms,
                      ]
                      .whereType<String>()
                      .join(' ')
                      .toLowerCase()
                      .contains(_query.trim().toLowerCase())),
        )
        .toList();
    final grouped = <String, List<dynamic>>{};
    for (final visit in visits) {
      final key = DateFormat('MMMM yyyy').format(visit.visitDate);
      grouped.putIfAbsent(key, () => []).add(visit);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Medical history'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/visits/add'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: provider.loading && provider.visits.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  final uid =
                      context.read<AuthProvider>().uid ??
                      SupabaseConfig.currentUserId;
                  if (uid != null || !SupabaseConfig.isInitialized) {
                    await provider.loadRecent(uid ?? 'local');
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.history_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Family medical history',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${provider.visits.length} recorded visit${provider.visits.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(225),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search doctor, member, diagnosis...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All visits', null),
                          ...years.map(
                            (year) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _filterChip('$year', year),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (provider.error != null)
                      _messageCard(provider.error!, Icons.error_outline_rounded)
                    else if (visits.isEmpty)
                      _messageCard(
                        'No visits found. Add your first doctor visit.',
                        Icons.medical_information_outlined,
                      )
                    else
                      ...grouped.entries.expand(
                        (entry) => [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 4),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (visit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _visitCard(
                                date: DateFormat(
                                  'dd MMM • EEEE',
                                ).format(visit.visitDate),
                                doctor:
                                    visit.doctorName?.trim().isNotEmpty == true
                                    ? visit.doctorName!
                                    : 'Doctor visit',
                                subtitle: [
                                  if (visit.memberName?.isNotEmpty == true)
                                    visit.memberName!,
                                  if (visit.diagnosis?.isNotEmpty == true)
                                    visit.diagnosis!,
                                ].join(' • '),
                                onTap: () =>
                                    context.push('/visits/${visit.id}'),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _filterChip(String label, int? year) {
    final selected = _selectedYear == year;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedYear = year),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
    );
  }

  Widget _messageCard(String message, IconData icon) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.textLight),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _visitCard({
    required String date,
    required String doctor,
    required String subtitle,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEFF8EC),
            child: Icon(
              Icons.medical_information_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  doctor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 15),
        ],
      ),
    ),
  );
}
