import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/member_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/records_provider.dart';
import '../../widgets/bottom_nav.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final doctorProv = context.watch<DoctorProvider>();
    final recordsProv = context.watch<RecordsProvider>();

    final members = memberProv.members.where((m) {
      if (_selectedFilter != 'All' && _selectedFilter != 'Patients') {
        return false;
      }
      if (_query.isEmpty) return true;
      return m.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final doctors = doctorProv.doctors.where((d) {
      if (_selectedFilter != 'All' && _selectedFilter != 'Doctors') {
        return false;
      }
      if (_query.isEmpty) return true;
      return d.name.toLowerCase().contains(_query.toLowerCase()) ||
          (d.specialization?.toLowerCase().contains(_query.toLowerCase()) ??
              false);
    }).toList();

    final files = recordsProv.files.where((f) {
      if (_selectedFilter != 'All' && _selectedFilter != 'Files') return false;
      final name = f.description ?? f.fileUrl.split('/').last;
      if (_query.isEmpty) return true;
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Search health records'),
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
              // Search Input
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: recordsProv.addRecentSearch,
                  decoration: InputDecoration(
                    hintText: 'Search family, patient, doctor, report...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textLight,
                      size: 22,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterTab('All'),
                    const SizedBox(width: 8),
                    _buildFilterTab('Patients'),
                    const SizedBox(width: 8),
                    _buildFilterTab('Doctors'),
                    const SizedBox(width: 8),
                    _buildFilterTab('Files'),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Section: Recent searches
              if (_query.isEmpty && recordsProv.recentSearches.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent searches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () => recordsProv.clearRecentSearches(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recordsProv.recentSearches.map(
                  (s) => InkWell(
                    onTap: () {
                      _searchCtrl.text = s;
                      setState(() => _query = s);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.textLight,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section: Suggested results
              const Text(
                'Suggested results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),

              ...members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSearchResultTile(
                    initials: _initials(member.name),
                    title: member.name,
                    subtitle: 'Patient • ${member.relation} • ${member.age}',
                    onTap: () {
                      recordsProv.addRecentSearch(member.name);
                      context.push('/members/${member.id}');
                    },
                  ),
                ),
              ),
              ...doctors.map(
                (doctor) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSearchResultTile(
                    initials: _initials(doctor.name),
                    title: doctor.name,
                    subtitle:
                        'Doctor • ${doctor.specialization ?? 'Specialization not recorded'}',
                    onTap: () {
                      recordsProv.addRecentSearch(doctor.name);
                      context.push('/doctors/${doctor.id}');
                    },
                  ),
                ),
              ),
              ...files.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSearchFileTile(
                    title:
                        file.description ?? file.fileName ?? 'Medical document',
                    subtitle: file.fileName ?? file.fileType,
                    date: DateFormat('dd MMMM yyyy').format(file.createdAt),
                    onTap: () async {
                      recordsProv.addRecentSearch(
                        file.description ?? file.fileName ?? 'Medical document',
                      );
                      final opened = await recordsProv.openDocument(file);
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No compatible app could open this file.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              if (members.isEmpty && doctors.isEmpty && files.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text('No matching health records found'),
                  ),
                ),
              /*
              if (members.isNotEmpty)
                _buildSearchResultTile(
                  initials: 'AL',
                  title: members.first.name,
                  subtitle: 'Patient • PAT-003 • 6 doctor visits',
                  onTap: () => context.push('/members/${members.first.id}'),
                ),
              const SizedBox(height: 12),

              // Doctor Result: Dr. Sana Malik
              if (doctors.isNotEmpty)
                _buildSearchResultTile(
                  initials: 'SM',
                  title: doctors.first.name,
                  subtitle:
                      'Doctor • ${doctors.first.specialization ?? "Pediatrician"}',
                  onTap: () => context.push('/doctors/${doctors.first.id}'),
                ),
              const SizedBox(height: 12),

              // File Result: Prescription_12Oct.pdf
              if (files.isNotEmpty)
                _buildSearchFileTile(
                  title: files.first.description ?? 'Prescription_12Oct.pdf',
                  subtitle: 'Ali Ahmed • Medical prescription',
                  date: '12 October 2026',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening file...')),
                    );
                  },
                ),
              */
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Widget _buildFilterTab(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile({
    required String initials,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.2),
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
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFDEF2D7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF235E1E),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFileTile({
    required String title,
    required String subtitle,
    required String date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.2),
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
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF8EC),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF38931F),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
