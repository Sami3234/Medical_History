import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/supabase_config.dart';
import '../../config/theme.dart';
import '../../models/doctor_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/bottom_nav.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    final uid =
        context.read<AuthProvider>().uid ?? SupabaseConfig.currentUserId;
    if (uid != null) await context.read<DoctorProvider>().loadDoctors(uid);
  }

  @override
  Widget build(BuildContext context) {
    final doctorProvider = context.watch<DoctorProvider>();
    final allDoctors = doctorProvider.doctors;
    final filters = _filterOptions(allDoctors);
    final filteredDoctors = allDoctors.where(_matchesFilter).toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final featuredDoctor = _featuredDoctor(filteredDoctors);
    final favoriteCount = allDoctors
        .where((doctor) => doctor.isFavorite)
        .length;
    final clinicCount = allDoctors
        .map((doctor) => doctor.hospital?.trim())
        .where((hospital) => hospital?.isNotEmpty == true)
        .toSet()
        .length;

    if (!filters.contains(_selectedFilter)) _selectedFilter = 'All';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadDoctors,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(allDoctors.length),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStats(
                        total: allDoctors.length,
                        favorites: favoriteCount,
                        clinics: clinicCount,
                      ),
                      const SizedBox(height: 20),
                      _buildFilters(filters),
                      const SizedBox(height: 22),
                      if (doctorProvider.loading && allDoctors.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 70),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (filteredDoctors.isEmpty)
                        _buildEmptyState(allDoctors.isEmpty)
                      else ...[
                        if (featuredDoctor != null && _query.isEmpty) ...[
                          Text(
                            'Your care team',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quick access to your priority doctor',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFeaturedDoctor(featuredDoctor),
                          const SizedBox(height: 24),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'All doctors',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: context.appTextPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.appSurfaceRaised,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${filteredDoctors.length}',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...filteredDoctors.map(_buildDoctorCard),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const BottomNav(currentIndex: 1),
      ),
    );
  }

  Widget _buildHeader(int doctorCount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        18 + MediaQuery.paddingOf(context).top,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF176F43), Color(0xFF2FAE45), Color(0xFF67C93C)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -58,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(24),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withAlpha(80)),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doctors',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$doctorCount saved care professional${doctorCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(210),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.doctorAdd),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search doctor, specialty or clinic',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(235),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.white.withAlpha(150)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats({
    required int total,
    required int favorites,
    required int clinics,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.groups_2_outlined,
            value: '$total',
            label: 'Doctors',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.star_rounded,
            value: '$favorites',
            label: 'Favorites',
            color: const Color(0xFFE99A18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.local_hospital_outlined,
            value: '$clinics',
            label: 'Clinics',
            color: const Color(0xFF1685A8),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> filters) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = filters[index];
          final selected = _selectedFilter == label;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _selectedFilter = label),
            label: Text(label),
            avatar: label == 'Favorites'
                ? Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: selected ? Colors.white : AppColors.warning,
                  )
                : null,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.appTextSecondary,
            ),
            selectedColor: AppColors.primaryDark,
            backgroundColor: context.appSurface,
            side: BorderSide(
              color: selected ? AppColors.primaryDark : context.appBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildFeaturedDoctor(DoctorModel doctor) {
    return InkWell(
      onTap: () => context.push('/doctors/${doctor.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(42),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _doctorAvatar(doctor, size: 68, featured: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doctor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (doctor.isFavorite)
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD35A),
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialization ?? 'General physician',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(225),
                      fontSize: 12.5,
                    ),
                  ),
                  if (doctor.hospital?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            doctor.hospital!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(DoctorModel doctor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push('/doctors/${doctor.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 7,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _doctorAvatar(doctor, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        doctor.specialization ?? 'General physician',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (doctor.hospital?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: context.appTextSecondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                doctor.hospital!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: doctor.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: () =>
                      context.read<DoctorProvider>().toggleFavorite(doctor),
                  icon: Icon(
                    doctor.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: doctor.isFavorite
                        ? AppColors.warning
                        : context.appTextSecondary,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Doctor options',
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete(doctor);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 10),
                          Text('Delete doctor'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doctorAvatar(
    DoctorModel doctor, {
    required double size,
    bool featured = false,
  }) {
    return AppAvatar(
      memberId: doctor.id,
      name: doctor.name,
      avatarUrl: doctor.avatarUrl,
      size: size,
      fontSize: size * 0.3,
      backgroundColor: featured
          ? Colors.white.withAlpha(225)
          : const Color(0xFFE6F5E0),
      border: Border.all(
        color: featured ? Colors.white : const Color(0xFFCBE7C2),
        width: 1.5,
      ),
    );
  }

  Widget _buildEmptyState(bool hasNoDoctors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: context.appSurfaceRaised,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasNoDoctors ? 'No doctors added yet' : 'No matching doctors',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoDoctors
                ? 'Add a doctor to organize visits and family care records.'
                : 'Try another name, specialty, clinic, or filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appTextSecondary, height: 1.5),
          ),
          if (hasNoDoctors) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.doctorAdd),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first doctor'),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _filterOptions(List<DoctorModel> doctors) {
    final specialties =
        doctors
            .map((doctor) => doctor.specialization?.trim())
            .whereType<String>()
            .where((specialty) => specialty.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', 'Favorites', ...specialties.take(5)];
  }

  bool _matchesFilter(DoctorModel doctor) {
    final query = _query.toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        doctor.name.toLowerCase().contains(query) ||
        (doctor.specialization?.toLowerCase().contains(query) ?? false) ||
        (doctor.hospital?.toLowerCase().contains(query) ?? false);
    if (!matchesQuery) return false;
    if (_selectedFilter == 'All') return true;
    if (_selectedFilter == 'Favorites') return doctor.isFavorite;
    return doctor.specialization?.trim() == _selectedFilter;
  }

  DoctorModel? _featuredDoctor(List<DoctorModel> doctors) {
    if (doctors.isEmpty) return null;
    for (final doctor in doctors) {
      if (doctor.isFavorite) return doctor;
    }
    return doctors.first;
  }

  Future<void> _confirmDelete(DoctorModel doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete doctor?'),
        content: Text(
          'Remove ${doctor.name} from your doctor directory? Existing visit records will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<DoctorProvider>().deleteDoctor(
      doctor.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'Doctor removed.' : 'Could not delete doctor.'),
      ),
    );
  }
}
