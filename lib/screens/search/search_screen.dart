import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/med_file_model.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/records_provider.dart';
import '../../providers/visit_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedCategory = 'All';
  String _query = '';

  static const _categories = <_SearchCategory>[
    _SearchCategory('All', Icons.grid_view_rounded),
    _SearchCategory('Members', Icons.groups_2_outlined),
    _SearchCategory('Doctors', Icons.medical_services_outlined),
    _SearchCategory('Visits', Icons.event_note_outlined),
    _SearchCategory('Documents', Icons.description_outlined),
    _SearchCategory('Appointments', Icons.calendar_month_outlined),
    _SearchCategory('Health', Icons.monitor_heart_outlined),
    _SearchCategory('Families', Icons.account_tree_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordsProvider>();
    final results = _buildResults(context);
    final showingResults =
        _query.trim().isNotEmpty || _selectedCategory != 'All';

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              focusNode: _focusNode,
              query: _query,
              onBack: context.pop,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  records.addRecentSearch(value.trim());
                }
              },
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
                _focusNode.requestFocus();
              },
            ),
            _CategoryBar(
              categories: _categories,
              selected: _selectedCategory,
              counts: _categoryCounts(context),
              onSelected: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            Expanded(
              child: showingResults
                  ? _SearchResults(
                      query: _query,
                      results: results,
                      onSelected: (result) =>
                          _openResult(context, records, result),
                    )
                  : _SearchLanding(
                      recentSearches: records.recentSearches,
                      counts: _categoryCounts(context),
                      onRecentSelected: (query) {
                        _searchController.text = query;
                        _searchController.selection = TextSelection.collapsed(
                          offset: query.length,
                        );
                        setState(() => _query = query);
                      },
                      onRecentRemoved: records.removeRecentSearch,
                      onClearRecent: records.clearRecentSearches,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                        _focusNode.requestFocus();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _categoryCounts(BuildContext context) {
    final members = context.read<MemberProvider>().members;
    final health = context.read<HealthProvider>();
    return {
      'Members': members.length,
      'Doctors': context.read<DoctorProvider>().doctors.length,
      'Visits': context.read<VisitProvider>().visits.length,
      'Documents': context.read<RecordsProvider>().files.length,
      'Appointments': context.read<RecordsProvider>().appointments.length,
      'Health':
          health.medications.length +
          health.vaccines.length +
          health.vitals.length,
      'Families': context.read<FamilyProvider>().families.length,
    };
  }

  List<_SearchResult> _buildResults(BuildContext context) {
    final query = _normalize(_query);
    if (query.isEmpty && _selectedCategory == 'All') return const [];
    final results = <_SearchResult>[];
    final members = context.watch<MemberProvider>().members;
    final memberNames = {for (final member in members) member.id: member.name};

    void add(_SearchResult result) {
      if (_selectedCategory != 'All' && result.category != _selectedCategory) {
        return;
      }
      if (_normalize(result.searchableText).contains(query)) {
        results.add(result);
      }
    }

    for (final member in members) {
      add(
        _SearchResult(
          category: 'Members',
          title: member.name,
          subtitle: [
            member.relation,
            member.age,
            member.bloodGroup,
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            member.name,
            member.relation,
            member.gender,
            member.bloodGroup,
            member.allergies,
            member.notes,
            member.emergencyContact,
          ].whereType<String>().join(' '),
          icon: Icons.person_outline_rounded,
          color: const Color(0xFF29935F),
          route: '/members/${member.id}',
        ),
      );
    }

    for (final doctor in context.watch<DoctorProvider>().doctors) {
      add(
        _SearchResult(
          category: 'Doctors',
          title: doctor.name,
          subtitle: [
            doctor.specialization,
            doctor.hospital,
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            doctor.name,
            doctor.specialization,
            doctor.hospital,
            doctor.address,
            doctor.qualification,
            doctor.phone,
            doctor.notes,
          ].whereType<String>().join(' '),
          icon: Icons.medical_services_outlined,
          color: const Color(0xFF168AAD),
          route: '/doctors/${doctor.id}',
        ),
      );
    }

    for (final visit in context.watch<VisitProvider>().visits) {
      add(
        _SearchResult(
          category: 'Visits',
          title: visit.diagnosis?.trim().isNotEmpty == true
              ? visit.diagnosis!
              : visit.doctorName ?? 'Medical visit',
          subtitle: [
            visit.memberName,
            visit.doctorName,
            DateFormat('dd MMM yyyy').format(visit.visitDate),
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            visit.memberName,
            visit.doctorName,
            visit.hospital,
            visit.symptoms,
            visit.diagnosis,
            visit.treatment,
            visit.notes,
          ].whereType<String>().join(' '),
          icon: Icons.event_note_outlined,
          color: const Color(0xFF7B61C9),
          route: '/visits/${visit.id}',
          date: visit.visitDate,
        ),
      );
    }

    final records = context.watch<RecordsProvider>();
    for (final file in records.files) {
      add(
        _SearchResult(
          category: 'Documents',
          title: file.description?.trim().isNotEmpty == true
              ? file.description!
              : file.fileName ?? 'Medical document',
          subtitle: [
            _documentType(file.fileType),
            memberNames[file.memberId],
            DateFormat('dd MMM yyyy').format(file.createdAt),
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            file.description,
            file.fileName,
            file.fileType,
            file.ocrText,
            memberNames[file.memberId],
          ].whereType<String>().join(' '),
          icon: _documentIcon(file),
          color: const Color(0xFFDF7B1D),
          document: file,
          date: file.createdAt,
        ),
      );
    }

    for (final appointment in records.appointments) {
      add(
        _SearchResult(
          category: 'Appointments',
          title: appointment.title,
          subtitle: [
            appointment.memberName,
            appointment.doctorName,
            DateFormat('dd MMM, h:mm a').format(appointment.dateTime),
          ].where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            appointment.title,
            appointment.memberName,
            appointment.doctorName,
            appointment.specialization,
            appointment.hospital,
            appointment.status,
          ].whereType<String>().join(' '),
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFFE34B6F),
          route: AppRoutes.appointments,
          date: appointment.dateTime,
        ),
      );
    }

    final health = context.watch<HealthProvider>();
    for (final medication in health.medications) {
      add(
        _SearchResult(
          category: 'Health',
          title: medication.name,
          subtitle: [
            'Medication',
            medication.memberId == null
                ? null
                : memberNames[medication.memberId],
            medication.dosage,
            medication.frequency,
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            medication.name,
            medication.dosage,
            medication.frequency,
            medication.timing,
            medication.duration,
            medication.notes,
            medication.memberId == null
                ? null
                : memberNames[medication.memberId],
          ].whereType<String>().join(' '),
          icon: Icons.medication_outlined,
          color: const Color(0xFF0C9B8E),
          route: medication.memberId == null
              ? null
              : '/members/${medication.memberId}',
        ),
      );
    }
    for (final vaccine in health.vaccines) {
      add(
        _SearchResult(
          category: 'Health',
          title: vaccine.name,
          subtitle: [
            'Vaccine',
            memberNames[vaccine.memberId],
            vaccine.dose,
            vaccine.status,
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            vaccine.name,
            vaccine.dose,
            vaccine.administeredBy,
            vaccine.notes,
            vaccine.status,
            memberNames[vaccine.memberId],
          ].whereType<String>().join(' '),
          icon: Icons.vaccines_outlined,
          color: const Color(0xFFBD5AA3),
          route: '/members/${vaccine.memberId}',
          date: vaccine.administeredDate,
        ),
      );
    }
    for (final vital in health.vitals) {
      add(
        _SearchResult(
          category: 'Health',
          title: '${vital.type}: ${vital.value} ${vital.unit}'.trim(),
          subtitle: [
            'Vital',
            memberNames[vital.memberId],
            vital.status,
            DateFormat('dd MMM yyyy').format(vital.recordedAt),
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            vital.type,
            vital.value,
            vital.unit,
            vital.status,
            vital.notes,
            memberNames[vital.memberId],
          ].whereType<String>().join(' '),
          icon: Icons.monitor_heart_outlined,
          color: const Color(0xFFE05A47),
          route: '/members/${vital.memberId}',
          date: vital.recordedAt,
        ),
      );
    }

    for (final family in context.watch<FamilyProvider>().families) {
      add(
        _SearchResult(
          category: 'Families',
          title: family.name,
          subtitle: [
            family.familyId,
            family.contact,
            family.address,
          ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
          searchableText: [
            family.name,
            family.familyId,
            family.contact,
            family.address,
          ].whereType<String>().join(' '),
          icon: Icons.account_tree_outlined,
          color: const Color(0xFF5177B8),
          route: '/families/${family.id}',
        ),
      );
    }

    results.sort((a, b) {
      final aTitle = _normalize(a.title);
      final bTitle = _normalize(b.title);
      final aScore = aTitle == query ? 0 : (aTitle.startsWith(query) ? 1 : 2);
      final bScore = bTitle == query ? 0 : (bTitle.startsWith(query) ? 1 : 2);
      if (aScore != bScore) return aScore.compareTo(bScore);
      if (a.date != null && b.date != null) return b.date!.compareTo(a.date!);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return results;
  }

  Future<void> _openResult(
    BuildContext context,
    RecordsProvider records,
    _SearchResult result,
  ) async {
    records.addRecentSearch(_query.trim());
    if (result.document != null) {
      final opened = await records.openDocument(result.document!);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No compatible app could open this file.'),
          ),
        );
      }
      return;
    }
    if (result.route != null && context.mounted) context.push(result.route!);
  }

  String _normalize(String value) => value.trim().toLowerCase();

  static String _documentType(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('_', ' ')
        .trim();
  }

  static IconData _documentIcon(MedFileModel file) {
    final type = '${file.fileType} ${file.mimeType ?? ''}'.toLowerCase();
    if (type.contains('image')) return Icons.image_outlined;
    if (type.contains('prescription')) return Icons.receipt_long_outlined;
    if (type.contains('lab')) return Icons.science_outlined;
    return Icons.description_outlined;
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onBack,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          Expanded(
            child: TextField(
              key: const Key('health-search-field'),
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search your complete health history',
                hintStyle: TextStyle(color: Colors.blueGrey.shade400),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                      ),
                filled: true,
                fillColor: Colors.white.withAlpha(242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<_SearchCategory> categories;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.label == selected;
          final count = category.label == 'All' ? null : counts[category.label];
          return FilterChip(
            selected: isSelected,
            onSelected: (_) => onSelected(category.label),
            avatar: Icon(
              category.icon,
              size: 17,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            label: Text(
              count == null ? category.label : '${category.label} $count',
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.appTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: context.appSurface,
            side: BorderSide(
              color: isSelected ? AppColors.primary : context.appBorder,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  const _SearchLanding({
    required this.recentSearches,
    required this.counts,
    required this.onRecentSelected,
    required this.onRecentRemoved,
    required this.onClearRecent,
    required this.onCategorySelected,
  });

  final List<String> recentSearches;
  final Map<String, int> counts;
  final ValueChanged<String> onRecentSelected;
  final ValueChanged<String> onRecentRemoved;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (recentSearches.isNotEmpty) ...[
          _SectionHeading(
            title: 'Recent searches',
            action: 'Clear all',
            onTap: onClearRecent,
          ),
          const SizedBox(height: 10),
          ...recentSearches.map(
            (query) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF5E7),
                child: Icon(Icons.history_rounded, color: AppColors.primary),
              ),
              title: Text(
                query,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => onRecentSelected(query),
              trailing: IconButton(
                onPressed: () => onRecentRemoved(query),
                icon: const Icon(Icons.close_rounded, size: 19),
                tooltip: 'Remove',
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const _SectionHeading(title: 'Search across your records'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _BrowseCard(
              'Members',
              counts['Members'] ?? 0,
              Icons.groups_2_outlined,
              const Color(0xFF29935F),
              onCategorySelected,
            ),
            _BrowseCard(
              'Doctors',
              counts['Doctors'] ?? 0,
              Icons.medical_services_outlined,
              const Color(0xFF168AAD),
              onCategorySelected,
            ),
            _BrowseCard(
              'Documents',
              counts['Documents'] ?? 0,
              Icons.description_outlined,
              const Color(0xFFDF7B1D),
              onCategorySelected,
            ),
            _BrowseCard(
              'Visits',
              counts['Visits'] ?? 0,
              Icons.event_note_outlined,
              const Color(0xFF7B61C9),
              onCategorySelected,
            ),
            _BrowseCard(
              'Appointments',
              counts['Appointments'] ?? 0,
              Icons.calendar_month_outlined,
              const Color(0xFFE34B6F),
              onCategorySelected,
            ),
            _BrowseCard(
              'Health',
              counts['Health'] ?? 0,
              Icons.monitor_heart_outlined,
              const Color(0xFF0C9B8E),
              onCategorySelected,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appSurfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.manage_search_rounded,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Search names, diagnosis, medicines, allergies, OCR report text, doctors and appointment notes.',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.results,
    required this.onSelected,
  });

  final String query;
  final List<_SearchResult> results;
  final ValueChanged<_SearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: context.appSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No matching records',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                'Try a name, doctor, diagnosis, medicine or report keyword.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <String, List<_SearchResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.category, () => []).add(result);
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          query.trim().isEmpty
              ? '${results.length} record${results.length == 1 ? '' : 's'}'
              : '${results.length} result${results.length == 1 ? '' : 's'} for “${query.trim()}”',
          style: TextStyle(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        for (final group in grouped.entries) ...[
          _SectionHeading(
            title: group.key,
            action: '${group.value.length} found',
          ),
          const SizedBox(height: 10),
          ...group.value.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResultCard(
                result: result,
                onTap: () => onSelected(result),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onTap});

  final _SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: result.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(result.icon, color: result.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (result.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                result.document == null
                    ? Icons.chevron_right_rounded
                    : Icons.open_in_new_rounded,
                color: context.appTextSecondary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard(this.label, this.count, this.icon, this.color, this.onTap);

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(24),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$count records',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          onTap == null
              ? Text(
                  action!,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                )
              : TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class _SearchCategory {
  const _SearchCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SearchResult {
  const _SearchResult({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.searchableText,
    required this.icon,
    required this.color,
    this.route,
    this.document,
    this.date,
  });

  final String category;
  final String title;
  final String subtitle;
  final String searchableText;
  final IconData icon;
  final Color color;
  final String? route;
  final MedFileModel? document;
  final DateTime? date;
}
