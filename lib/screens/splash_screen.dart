import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../config/supabase_config.dart';
import '../providers/doctor_provider.dart';
import '../providers/family_provider.dart';
import '../providers/member_provider.dart';
import '../services/biometric_service.dart';
import '../services/offline_data_service.dart';
import '../services/owner_profile_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_container.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show starting screen long enough for the user to enjoy its visuals
    final minimumSplash = Future<void>.delayed(AppNetwork.minSplashDuration);

    final isLoggedIn =
        SupabaseConfig.isInitialized &&
        (SupabaseConfig.auth?.currentUser != null);

    if (!isLoggedIn) {
      await minimumSplash;
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      context.go(hasSeenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
      return;
    }

    final biometricEnabled = await BiometricAuthService.isEnabled().timeout(
      const Duration(seconds: 2),
      onTimeout: () => false,
    );
    if (!mounted) return;
    if (biometricEnabled) {
      await minimumSplash;
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    // Preload home data in background while splash is shown.
    // Guaranteed to never hold the user more than maxSplashTimeout (3.2 seconds max).
    bool needsOwnerSetup = false;
    try {
      final prepareFuture = _prepareHome();
      final results = await Future.wait([
        minimumSplash,
        prepareFuture,
      ]).timeout(AppNetwork.maxSplashTimeout);
      needsOwnerSetup = results[1] as bool? ?? false;
    } catch (_) {
      // If network is slow or times out, proceed directly with cached data
      needsOwnerSetup = false;
    }

    if (!mounted) return;
    OwnerProfileService.homePrefetchFinished = true;
    context.go(needsOwnerSetup ? AppRoutes.ownerSetup : AppRoutes.dashboard);
  }

  /// Loads the home data behind the splash with cache-first and quick timeout.
  /// Returns true when the owner profile still needs to be completed.
  Future<bool> _prepareHome() async {
    try {
      return await _loadHomeData().timeout(AppNetwork.quickTimeout);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadHomeData() async {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null) return false;

    // 1. Instant check from local cache
    final ownerService = OwnerProfileService();
    final cachedOwner = OfflineDataService.getOwner(uid);
    if (cachedOwner != null && ownerService.isComplete(cachedOwner)) {
      OwnerProfileService.verifiedOwnerUserId = uid;
    }

    // 2. Pre-populate and revalidate providers
    if (mounted) {
      await Future.wait([
        ownerService.getOwnerMember(uid),
        context.read<FamilyProvider>().loadFamilies(uid),
        context.read<DoctorProvider>().loadDoctors(uid),
        context.read<MemberProvider>().loadAll(uid),
      ]);
    }

    final owner = OfflineDataService.getOwner(uid);
    if (owner != null && !ownerService.isComplete(owner)) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Stack(
          children: [
            // Ambient Gaussian Blur Orbs (Aurora Effect - Figma Palette)
            const Positioned(
              top: -60,
              right: -40,
              child: AmbientBlurOrb(
                size: 260,
                color: Color(0xFFC5F2A0), // Lime glow
                blur: 45,
                opacity: 0.50,
              ),
            ),
            const Positioned(
              bottom: 40,
              left: -50,
              child: AmbientBlurOrb(
                size: 240,
                color: Color(0xFF88D84C), // Leaf glow
                blur: 50,
                opacity: 0.35,
              ),
            ),
            const Positioned(
              top: 240,
              left: 20,
              child: AmbientBlurOrb(
                size: 160,
                color: Color(0xFFB9EB80),
                blur: 40,
                opacity: 0.30,
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassContainer(
                        blur: 24,
                        opacity: 0.12,
                        borderRadius: BorderRadius.circular(32),
                        padding: const EdgeInsets.all(20),
                        child: const AppLogo(
                          size: 110,
                          isTransparent: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Medical History',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Family\'s Health Companion',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
