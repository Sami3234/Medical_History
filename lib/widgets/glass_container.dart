import 'dart:ui';
import 'package:flutter/material.dart';

/// A modern, reusable Glassmorphic / Frosted Glass container
/// utilizing high-performance Gaussian blur (BackdropFilter).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity = 0.16,
    this.color,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultColor = color ??
        (isDark
            ? Colors.black.withOpacity(opacity * 1.5)
            : Colors.white.withOpacity(opacity));

    final effectiveBorder = border ??
        Border.all(
          color: (isDark ? Colors.white : Colors.white).withOpacity(
            isDark ? 0.12 : 0.35,
          ),
          width: 1.2,
        );

    final widgetChild = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? defaultColor : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: effectiveBorder,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: widgetChild,
        ),
      ),
    );
  }
}

/// An ambient Gaussian-blurred glowing orb for modern Aurora background effects.
class AmbientBlurOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;
  final double opacity;

  const AmbientBlurOrb({
    super.key,
    required this.size,
    required this.color,
    this.blur = 45.0,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}
