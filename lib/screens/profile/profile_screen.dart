import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/app_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final fullName = user?.fullName ?? 'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACCOUNT & PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'My profile',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: context.appBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      name: fullName,
                      avatarUrl: user?.avatarUrl,
                      size: 68,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.appTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.editProfile),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F4ED),
                              foregroundColor: AppColors.primaryDark,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            label: const Text(
                              'Edit profile',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section: Account settings
              Text(
                'Account settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Setting 1: Family members
              _buildSettingTile(
                context: context,
                icon: Icons.groups_outlined,
                title: 'Family members',
                subtitle: 'Manage family member profiles',
                onTap: () => context.push(AppRoutes.members),
              ),
              const SizedBox(height: 12),

              // Setting 2: Security & privacy
              _buildSettingTile(
                context: context,
                icon: Icons.verified_user_outlined,
                title: 'Security & privacy',
                subtitle: 'Biometrics, passwords and data',
                onTap: () => context.push(AppRoutes.security),
              ),
              const SizedBox(height: 12),

              // Setting 3: Backup & restore
              _buildSettingTile(
                context: context,
                icon: Icons.cloud_outlined,
                title: 'Backup & restore',
                subtitle: 'Google Drive sync & cloud vault',
                onTap: () => context.push(AppRoutes.backup),
              ),
              const SizedBox(height: 12),

              // Setting 4: Notifications
              _buildSettingTile(
                context: context,
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Appointment & medication alerts',
                onTap: () => context.push(AppRoutes.notifications),
              ),
              const SizedBox(height: 12),

              // Setting 5: App preferences
              _buildSettingTile(
                context: context,
                icon: Icons.settings_outlined,
                title: 'App preferences',
                subtitle: 'Language, themes & cache',
                onTap: () => context.push(AppRoutes.preferences),
              ),
              const SizedBox(height: 24),

              // Sign out button (Soft Green Wide Button)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6F4ED),
                    foregroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: context.appTextSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
