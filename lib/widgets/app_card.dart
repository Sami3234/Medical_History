import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Border? border;
  final Gradient? gradient;
  final bool isGlass;
  final double blur;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 20,
    this.border,
    this.gradient,
    this.isGlass = false,
    this.blur = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardBorder = border ??
        Border.all(
          color: isGlass
              ? Colors.white.withOpacity(isDark ? 0.12 : 0.4)
              : context.appBorder,
          width: 1.2,
        );

    final cardColor = color ??
        (gradient == null
            ? (isGlass
                ? (isDark
                    ? context.appSurface.withOpacity(0.72)
                    : Colors.white.withOpacity(0.82))
                : context.appSurface)
            : null);

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x33000000)
                : AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (isGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}
