import 'package:flutter/material.dart';

/// A premium, lightweight header background featuring the signature medical
/// green gradient adorned with refined organic wave curves, soft glowing
/// ambient highlights, and layered abstract patterns.
class PremiumHeaderBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<Color>? gradientColors;
  final List<BoxShadow>? boxShadow;

  const PremiumHeaderBackground({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(bottom: Radius.circular(30)),
    this.padding,
    this.gradientColors,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColors = gradientColors ??
        const [
          Color(0xFF267310),
          Color(0xFF388E18),
          Color(0xFF4FA023),
        ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            const [
              BoxShadow(
                color: Color(0x1F1B5E20),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          painter: _HeaderWavePainter(colors: effectiveColors),
          child: Container(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  final List<Color> colors;

  const _HeaderWavePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final rect = Offset.zero & size;

    // 1. Base Gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
    final basePaint = Paint()..shader = baseGradient.createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2. Soft Glowing Ambient Highlight (Top Right)
    final glowPaint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.75, -0.6),
        radius: 0.9,
        colors: [
          const Color(0xFFC5F2A0).withValues(alpha: 0.22),
          const Color(0xFFC5F2A0).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint1);

    // 3. Subtle Luminous Glow (Bottom Left)
    final glowPaint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, 0.7),
        radius: 0.8,
        colors: [
          const Color(0xFF88D84C).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint2);

    // 4. Wave 1 - Flowing Organic Top-Right Wave (Fluid S-Curve)
    final path1 = Path();
    path1.moveTo(w * 0.22, 0);
    path1.cubicTo(
      w * 0.48, h * 0.18,
      w * 0.62, h * 0.04,
      w, h * 0.46,
    );
    path1.lineTo(w, 0);
    path1.close();

    final wavePaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.02),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path1, wavePaint1);

    // Fine wave 1 crest highlight line (subtle glowing stroke)
    final strokePath1 = Path();
    strokePath1.moveTo(w * 0.22, 0);
    strokePath1.cubicTo(
      w * 0.48, h * 0.18,
      w * 0.62, h * 0.04,
      w, h * 0.46,
    );
    final strokePaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.24),
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(strokePath1, strokePaint1);

    // 5. Wave 2 - Soft Secondary Layered Contour (Mid-Region Flow)
    final path2 = Path();
    path2.moveTo(w * 0.45, 0);
    path2.cubicTo(
      w * 0.68, h * 0.28,
      w * 0.78, h * 0.18,
      w, h * 0.82,
    );
    path2.lineTo(w, 0);
    path2.close();

    final wavePaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFB9EB80).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path2, wavePaint2);

    // 6. Wave 3 - Gentle Organic Ripple along Bottom Left
    final path3 = Path();
    path3.moveTo(0, h * 0.72);
    path3.cubicTo(
      w * 0.22, h * 0.58,
      w * 0.42, h * 0.88,
      w * 0.75, h,
    );
    path3.lineTo(0, h);
    path3.close();

    final wavePaint3 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path3, wavePaint3);

    // Fine crest stroke on Wave 3
    final strokePath3 = Path();
    strokePath3.moveTo(0, h * 0.72);
    strokePath3.cubicTo(
      w * 0.22, h * 0.58,
      w * 0.42, h * 0.88,
      w * 0.75, h,
    );
    final strokePaint3 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(strokePath3, strokePaint3);
  }

  @override
  bool shouldRepaint(covariant _HeaderWavePainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
