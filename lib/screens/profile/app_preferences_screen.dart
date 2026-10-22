import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../utils/extensions.dart';
import '../../providers/theme_provider.dart';

class AppPreferencesScreen extends StatefulWidget {
  const AppPreferencesScreen({super.key});

  @override
  State<AppPreferencesScreen> createState() => _AppPreferencesScreenState();
}

class _AppPreferencesScreenState extends State<AppPreferencesScreen> {
  String _selectedTheme = 'Medical Green (Default)';
  String _selectedLanguage = 'English';
  String _selectedDateFormat = 'DD / MM / YYYY';
  bool _clearingCache = false;

  final List<String> _themes = [
    'Medical Green (Default)',
    'Clean White',
    'Dark Mode',
  ];

  final List<String> _languages = ['English', 'Urdu'];

  final List<String> _dateFormats = [
    'DD / MM / YYYY',
    'MM / DD / YYYY',
    'YYYY-MM-DD',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedTheme = prefs.getString('pref_theme') ?? _themes.first;
        final savedLanguage = prefs.getString('pref_lang');
        _selectedLanguage = savedLanguage?.startsWith('Urdu') == true
            ? 'Urdu'
            : (savedLanguage ?? _languages.first);
        _selectedDateFormat =
            prefs.getString('pref_date') ?? _dateFormats.first;
      });
    }
  }

  Future<void> _savePref(String key, String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    await Future.delayed(const Duration(milliseconds: 600));
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (mounted) {
      setState(() => _clearingCache = false);
      context.showSnack(
        'Temporary image & file cache cleared.',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('App Preferences'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance Section
              _buildSectionHeader('APPEARANCE & THEME'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.appSurfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.palette_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Theme Palette',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTheme,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _themes.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          final controller = context.read<AppThemeController>();
                          setState(() => _selectedTheme = val);
                          await Future<void>.delayed(
                            const Duration(milliseconds: 250),
                          );
                          if (!mounted) return;
                          await controller.setTheme(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Language Section
              _buildSectionHeader('LANGUAGE & REGIONAL'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildDropdownRow(
                      icon: Icons.language_rounded,
                      title: 'App Language',
                      value: _selectedLanguage,
                      items: _languages,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLanguage = val);
                          _savePref('pref_lang', val);
                          context.showSnack(
                            'Language set to $val.',
                            isError: false,
                          );
                        }
                      },
                    ),
                    const Divider(height: 24),
                    _buildDropdownRow(
                      icon: Icons.calendar_today_rounded,
                      title: 'Date Format',
                      value: _selectedDateFormat,
                      items: _dateFormats,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDateFormat = val);
                          _savePref('pref_date', val);
                        }
                      },
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.appSurfaceRaised,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.straighten_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medical Units',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTextPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'mg/dL (Glucose), mmHg (BP), kg (Weight)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Storage & Cache Section
              _buildSectionHeader('STORAGE & LOCAL CACHE'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 300;
                    final icon = Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.appSurfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.cleaning_services_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clear Offline Cache',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Frees up temporary images & document cache',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    );
                    final clearButton = OutlinedButton(
                      onPressed: _clearingCache ? null : _clearCache,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _clearingCache
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              icon,
                              const SizedBox(width: 12),
                              Expanded(child: details),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: clearButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                        const SizedBox(width: 10),
                        clearButton,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // App Version Card
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Medical History App',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.4 • Cloud powered with private access',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.primary,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.appBorder, width: 1.2),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.appSurfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((i) {
            return DropdownMenuItem(
              value: i,
              child: Text(i, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
