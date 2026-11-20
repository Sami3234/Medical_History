import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/avatar_cache_service.dart';

class AppAvatar extends StatelessWidget {
  final String? memberId;
  final String? avatarUrl;
  final String name;
  final double size;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.name,
    this.memberId,
    this.avatarUrl,
    this.size = 48.0,
    this.fontSize,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double computedFontSize = fontSize ?? (size * 0.38).clamp(10.0, 26.0);
    final bg = backgroundColor ?? const Color(0xFFD7EFE3);
    final fg = textColor ?? AppColors.primaryDark;

    Widget avatarContent;

    // 1. Check in-memory avatar cache first (fastest, zero network, zero CORS)
    final cachedBytes =
        (memberId != null ? AvatarMemoryCache.get(memberId) : null) ??
        AvatarMemoryCache.get(avatarUrl) ??
        AvatarMemoryCache.get(name) ??
        AvatarMemoryCache.get(name.toLowerCase());

    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      avatarContent = Image.memory(
        cachedBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(computedFontSize, fg),
      );
    } else if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          // Cache decoded bytes for instantaneous future builds
          if (memberId != null) AvatarMemoryCache.set(memberId!, bytes);
          AvatarMemoryCache.set(name, bytes);
          AvatarMemoryCache.set(url, bytes);

          avatarContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(computedFontSize, fg),
          );
        } catch (_) {
          avatarContent = _buildFallback(computedFontSize, fg);
        }
      } else {
        avatarContent = Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            // Check fallback cache before initials
            final fallbackBytes =
                (memberId != null ? AvatarMemoryCache.get(memberId) : null) ??
                AvatarMemoryCache.get(name) ??
                AvatarMemoryCache.get(name.toLowerCase());
            if (fallbackBytes != null) {
              return Image.memory(
                fallbackBytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
              );
            }
            return _buildFallback(computedFontSize, fg);
          },
        );
      }
    } else {
      avatarContent = _buildFallback(computedFontSize, fg);
    }

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipOval(child: avatarContent),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: circle);
    }
    return circle;
  }

  Widget _buildFallback(double fontSize, Color color) {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
