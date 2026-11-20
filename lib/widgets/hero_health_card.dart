import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'app_avatar.dart';
import 'glass_container.dart';

class HeroHealthCardAvatar {
  final String name;
  final String? avatarUrl;

  const HeroHealthCardAvatar({required this.name, this.avatarUrl});
}

class HeroHealthCard extends StatelessWidget {
  final String? tag;
  final String title;
  final String? subtitle;
  final Widget? content;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? leading;
  final List<String>? avatarInitials;
  final List<HeroHealthCardAvatar>? memberAvatars;

  const HeroHealthCard({
    super.key,
    this.tag,
    required this.title,
    this.subtitle,
    this.content,
    this.actionText,
    this.onAction,
    this.leading,
    this.avatarInitials,
    this.memberAvatars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Gaussian Blur background curves (Figma Hero Lime Orb)
            const Positioned(
              right: -30,
              top: -30,
              child: AmbientBlurOrb(
                size: 160,
                color: Color(0xFFB9EB80),
                blur: 25,
                opacity: 0.65,
              ),
            ),
            const Positioned(
              right: 20,
              bottom: -40,
              child: AmbientBlurOrb(
                size: 130,
                color: Color(0xFF74C43B),
                blur: 30,
                opacity: 0.35,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null) ...[
                    Text(
                      tag!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(230),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 16),
                    content!,
                  ],
                  if ((memberAvatars != null && memberAvatars!.isNotEmpty) ||
                      (avatarInitials != null &&
                          avatarInitials!.isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children:
                                memberAvatars != null &&
                                    memberAvatars!.isNotEmpty
                                ? memberAvatars!.map((item) {
                                    return AppAvatar(
                                      name: item.name,
                                      avatarUrl: item.avatarUrl,
                                      size: 38,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    );
                                  }).toList()
                                : avatarInitials!.map((initials) {
                                    return Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                        if (actionText != null && onAction != null) ...[
                          ElevatedButton(
                            onPressed: onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  actionText!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else if (actionText != null && onAction != null) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionText!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
