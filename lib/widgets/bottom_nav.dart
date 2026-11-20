import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import 'app_logo.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  bool _isQuickActionsOpen = false;

  void _onItemTapped(int index) {
    if (index == widget.currentIndex) return;

    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.doctors);
        break;
      case 2:
        _toggleQuickActions();
        break;
      case 3:
        context.go(AppRoutes.documents);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }

  Future<void> _toggleQuickActions() async {
    if (_isQuickActionsOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    setState(() => _isQuickActionsOpen = true);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions',
      barrierColor: const Color(0x38052E1B), // Soft emerald dim effect
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogCtx, anim1, anim2) {
        final bottomOffset = MediaQuery.paddingOf(dialogCtx).bottom + 76;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: bottomOffset,
              left: 16,
              right: 16,
            ),
            child: Material(
              color: Colors.transparent,
              child: _QuickActionsPopup(
                onClose: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _isQuickActionsOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.appSurface.withOpacity(isDark ? 0.78 : 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(isDark ? 0.08 : 0.45),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x66000000)
                    : const Color(0x0F0D331E),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildNavItem(
                      0,
                      Icons.home_outlined,
                      Icons.home_rounded,
                      'Home',
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      1,
                      Icons.medical_services_outlined,
                      Icons.medical_services_rounded,
                      'Doctors',
                    ),
                  ),
                  Expanded(child: _buildCenterAddButton()),
                  Expanded(
                    child: _buildNavItem(
                      3,
                      Icons.description_outlined,
                      Icons.description_rounded,
                      'Records',
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      4,
                      Icons.person_outline_rounded,
                      Icons.person_rounded,
                      'Profile',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
  ) {
    final isSelected = widget.currentIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.appTextSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    return GestureDetector(
      onTap: _toggleQuickActions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isQuickActionsOpen
              ? AppColors.accent
              : AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.heroGradient,
          ),
          child: AnimatedRotation(
            turns: _isQuickActionsOpen ? 0.125 : 0.0, // Rotates 45 degrees (+ transforms to x)
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// VECTOR SVG ASSETS FOR QUICK ACTIONS POPUP (Consistent App Palette)
// ============================================================================

/// Top-left organic wave with app's exact green gradient, mint glow contour, and sparkle rays
const String _headerWaveSvg = '''
<svg viewBox="0 0 140 100" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="waveGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#388E18" />
      <stop offset="45%" stop-color="#4FA023" />
      <stop offset="100%" stop-color="#74C43B" />
    </linearGradient>
  </defs>
  <!-- 3 Radiant Green Sparkle Rays on Left Edge -->
  <line x1="14" y1="18" x2="3" y2="12" stroke="#74C43B" stroke-width="2.6" stroke-linecap="round" />
  <line x1="12" y1="34" x2="1" y2="34" stroke="#74C43B" stroke-width="2.6" stroke-linecap="round" />
  <line x1="14" y1="50" x2="3" y2="56" stroke="#74C43B" stroke-width="2.6" stroke-linecap="round" />
  <!-- Lower Mint Glow Border -->
  <path d="M 120 0 C 130 30, 102 70, 60 84 C 34 92, 12 96, 0 96" stroke="#B9EB80" stroke-width="3.5" fill="none" opacity="0.95" />
  <!-- Main Vibrant Green Wave -->
  <path d="M 0 0 L 118 0 C 126 28, 98 67, 58 81 C 32 89, 10 93, 0 93 Z" fill="url(#waveGrad)" />
</svg>
''';

/// 1. Family Member: Adult and child silhouette in #2C6B14
const String _familySvg = '''
<svg viewBox="0 0 24 24" fill="#2C6B14" xmlns="http://www.w3.org/2000/svg">
  <circle cx="16" cy="6.5" r="2.8" />
  <path d="M12.2 19v-2c0-1.8 1.5-3.3 3.3-3.3h1c1.8 0 3.3 1.5 3.3 3.3v2" stroke="#2C6B14" stroke-width="1.8" stroke-linecap="round" />
  <circle cx="8" cy="9" r="2.2" />
  <path d="M5.2 19v-1.5c0-1.4 1.1-2.5 2.5-2.5h0.6c1.4 0 2.5 1.1 2.5 2.5v1.5" stroke="#2C6B14" stroke-width="1.6" stroke-linecap="round" />
</svg>
''';

/// 2. Doctor: Stethoscope with dual earpieces, U-tube, and round chest piece in #2C6B14
const String _doctorSvg = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#2C6B14" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M4.5 4v5a5.5 5.5 0 0 0 11 0V4" />
  <circle cx="4.5" cy="3.5" r="1.2" fill="#2C6B14" />
  <circle cx="15.5" cy="3.5" r="1.2" fill="#2C6B14" />
  <path d="M10 14.5V17a3 3 0 0 0 3 3h2" />
  <circle cx="17.5" cy="20" r="2.2" fill="#2C6B14" stroke="#2C6B14" stroke-width="1.5" />
</svg>
''';

/// 3. Visit: Calendar with clock badge in bottom-right corner in #2C6B14
const String _visitSvg = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#2C6B14" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="4" width="18" height="17" rx="3" stroke-width="1.8" />
  <line x1="16" y1="2" x2="16" y2="6" stroke-width="2" />
  <line x1="8" y1="2" x2="8" y2="6" stroke-width="2" />
  <line x1="3" y1="9.5" x2="21" y2="9.5" stroke-width="1.6" />
  <circle cx="16.5" cy="16.5" r="4.5" fill="#EBF7E4" stroke="#2C6B14" stroke-width="1.8" />
  <polyline points="16.5 14.2 16.5 16.5 18 16.5" stroke="#2C6B14" stroke-width="1.6" />
</svg>
''';

/// 4. Prescription: 45-degree tilted capsule pill with dividing line in #2C6B14
const String _prescriptionSvg = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#2C6B14" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <rect x="3.8" y="8.8" width="16.4" height="6.4" rx="3.2" transform="rotate(-45 12 12)" stroke-width="2" />
  <line x1="8.8" y1="8.8" x2="15.2" y2="15.2" stroke-width="2" />
</svg>
''';

/// 5. Appointment: Calendar with circular plus (+) badge in bottom-right corner in #2C6B14
const String _appointmentSvg = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#2C6B14" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="4" width="18" height="17" rx="3" stroke-width="1.8" />
  <line x1="16" y1="2" x2="16" y2="6" stroke-width="2" />
  <line x1="8" y1="2" x2="8" y2="6" stroke-width="2" />
  <line x1="3" y1="9.5" x2="21" y2="9.5" stroke-width="1.6" />
  <circle cx="16.5" cy="16.5" r="4.5" fill="#EBF7E4" stroke="#2C6B14" stroke-width="1.8" />
  <line x1="16.5" y1="14.2" x2="16.5" y2="18.8" stroke="#2C6B14" stroke-width="1.8" />
  <line x1="14.2" y1="16.5" x2="18.8" y2="16.5" stroke="#2C6B14" stroke-width="1.8" />
</svg>
''';

/// 6. Shared Record: Medical protection shield with cross in #2C6B14
const String _sharedRecordSvg = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#2C6B14" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" fill="#EBF7E4" stroke="#2C6B14" stroke-width="1.8" />
  <line x1="12" y1="8.5" x2="12" y2="14.5" stroke="#2C6B14" stroke-width="2" />
  <line x1="9" y1="11.5" x2="15" y2="11.5" stroke="#2C6B14" stroke-width="2" />
</svg>
''';

/// Premium Quick Actions Popup dialog
class _QuickActionsPopup extends StatelessWidget {
  final VoidCallback onClose;

  const _QuickActionsPopup({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layered Container with Gradient Border & Multi-Layer Floating Green Shadow
        Container(
          constraints: const BoxConstraints(maxWidth: 390),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight, // Bright lime green
                AppColors.primary,      // Main brand green
                AppColors.accent,       // Soft glow mint
                AppColors.primaryDark,  // Deep forest green
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
            boxShadow: [
              // Ambient soft green floating halo
              BoxShadow(
                color: AppColors.primary.withOpacity(0.24),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              // Stronger green depth shadow directly underneath
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.18),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              // Subtle tight shadow for definition
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.8), // Exact integrated gradient border
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.2),
              child: Stack(
                children: [
                  // 1. Vector SVG Top-Left Organic Wave Decoration with App's Green Gradient
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SvgPicture.string(
                      _headerWaveSvg,
                      width: 124,
                      height: 88,
                      fit: BoxFit.fill,
                    ),
                  ),

                  // 2. Official App Logo inside the green wave
                  Positioned(
                    top: 8,
                    left: 14,
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                        child: AppLogo(
                          size: 48,
                          isTransparent: true,
                        ),
                      ),
                    ),
                  ),

                  // 3. Header Row & Action Grid Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row (Starts after the organic wave decoration with zero overlap)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 110),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Quick Actions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Choose an action below',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMid,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Circular Close Button with soft mint background & dark green icon
                            GestureDetector(
                              onTap: onClose,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent,
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // 3-column and 2-row Action Grid with exact reference icons
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                svgString: _familySvg,
                                title: 'Family Member',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.memberAdd);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionCard(
                                svgString: _doctorSvg,
                                title: 'Doctor',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.doctorAdd);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionCard(
                                svgString: _visitSvg,
                                title: 'Visit',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.visitAdd);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                svgString: _prescriptionSvg,
                                title: 'Prescription',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.uploadDoc);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionCard(
                                svgString: _appointmentSvg,
                                title: 'Appointment',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.appointments);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionCard(
                                svgString: _sharedRecordSvg,
                                title: 'Shared Record',
                                onTap: () {
                                  onClose();
                                  context.push(AppRoutes.sharedMember);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Downward speech bubble pointer pointing directly down to the '+' button
        CustomPaint(
          size: const Size(22, 10),
          painter: const _SpeechBubbleArrowPainter(
            color: Colors.white,
            strokeColor: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}

/// Action Card with tactile scale-down animation on tap and crisp vector icon
class _ActionCard extends StatefulWidget {
  final IconData? icon;
  final String svgString;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    this.icon,
    this.svgString = '',
    required this.title,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPressed
                  ? AppColors.primary
                  : AppColors.accent.withOpacity(0.6),
              width: _isPressed ? 1.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? AppColors.primary.withOpacity(0.20)
                    : AppColors.primary.withOpacity(0.07),
                blurRadius: _isPressed ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface, // App's warm mint background
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.7),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(11),
                child: widget.svgString.isNotEmpty
                    ? SvgPicture.string(
                        widget.svgString,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        widget.icon ?? Icons.help_outline_rounded,
                        size: 24,
                        color: AppColors.primaryDark,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark, // App's brand dark text
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seamless arrow painter for speech bubble pointer
class _SpeechBubbleArrowPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  const _SpeechBubbleArrowPainter({
    required this.color,
    this.strokeColor = const Color(0xFFC7F0D2),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(borderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
