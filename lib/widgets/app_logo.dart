import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/constants.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool isTransparent;
  final double? borderRadius;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 48,
    this.isTransparent = false,
    this.borderRadius,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22);

    if (isTransparent) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          AppAssets.logoTransparent,
          width: size,
          height: size,
          fit: fit,
          placeholderBuilder: (_) => Image.asset(
            AppAssets.logo,
            width: size,
            height: size,
            fit: fit,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        AppAssets.logo,
        width: size,
        height: size,
        fit: fit,
      ),
    );
  }
}
