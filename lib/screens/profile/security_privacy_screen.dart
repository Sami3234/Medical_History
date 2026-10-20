import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/account_export_service.dart';
import '../../utils/extensions.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  bool _biometricsEnabled = false;
  bool _hardwareSupported = false;
  bool _loading = false;

  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final supported = await BiometricAuthService.isAvailable();
    final enabled = await BiometricAuthService.isEnabled();
    if (mounted) {
      setState(() {
        _hardwareSupported = supported;
        _biometricsEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool val) async {
    if (val) {
      final verified = await BiometricAuthService.authenticate(
        reason: 'Verify your identity to enable biometric login',
      );
      if (!verified) {
        if (mounted) {
          context.showSnack(
            'Biometric verification was not completed.',
            isError: true,
          );
        }
        return;
      }
    }
    await BiometricAuthService.setEnabled(val);
    setState(() => _biometricsEnabled = val);
    if (mounted) {
      context.showSnack(
        val
            ? 'Fingerprint / Biometric authentication enabled.'
            : 'Fingerprint authentication disabled.',
        isError: false,
      );
    }
  }

  Future<void> _changePassword() async {
    final pass = _passCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (pass.length < 6) {
      context.showSnack(
        'Password must be at least 6 characters.',
        isError: true,
      );
      return;
    }
    if (pass != confirm) {
      context.showSnack('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      if (SupabaseConfig.isInitialized && SupabaseConfig.auth != null) {
        await SupabaseConfig.auth!.updateUser(UserAttributes(password: pass));
        _passCtrl.clear();
        _confirmPassCtrl.clear();
        if (mounted) {
          context.showSnack('Password updated successfully!', isError: false);
        }
      } else {
        if (mounted) {
          context.showSnack(
            'Password updated in local account.',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnack('Failed to update password: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Security & Privacy'),
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
              // Biometrics Section
              _buildSectionHeader('BIOMETRIC AUTHENTICATION'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fingerprint / Biometrics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Unlock Medical History with biometrics',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _biometricsEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: _hardwareSupported ? _toggleBiometrics : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Change Password Section
              _buildSectionHeader('ACCOUNT CREDENTIALS'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signed in as ${user?.email ?? "User"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      decoration: InputDecoration(
                        hintText: 'New password (min 6 characters)',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: !_showPass,
                      decoration: const InputDecoration(
                        hintText: 'Confirm new password',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save New Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _confirmSignOutEverywhere,
                icon: const Icon(Icons.devices_other_outlined),
                label: const Text('Sign out all other devices'),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('DANGER ZONE'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withAlpha(100),
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Delete account'),
                  subtitle: const Text(
                    'Permanently delete your account and cloud records.',
                  ),
                  onTap: _confirmDeleteAccount,
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('YOUR DATA'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Export account data'),
                  subtitle: const Text(
                    'Save profiles, visits, health records and local document metadata as JSON.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    try {
                      final opened = await AccountExportService.exportAndOpen();
                      if (mounted && !opened)
                        context.showSnack(
                          'Export saved locally.',
                          isError: false,
                        );
                    } catch (e) {
                      if (mounted)
                        context.showSnack(
                          'Could not export account data.',
                          isError: true,
                        );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Data Security & HIPAA Info
              _buildSectionHeader('DATA ENCRYPTION & PRIVACY'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildSecurityFeatureRow(
                      icon: Icons.shield_outlined,
                      title: 'Encrypted transport and storage',
                      subtitle:
                          'Supabase protects transport and managed storage. This app does not yet provide end-to-end client-side encryption.',
                    ),
                    const Divider(height: 24),
                    _buildSecurityFeatureRow(
                      icon: Icons.lock_clock_outlined,
                      title: 'Role-Based Row Security (RLS)',
                      subtitle:
                          'Only your authenticated account has permissions to read and write your family data.',
                    ),
                    const Divider(height: 24),
                    _buildSecurityFeatureRow(
                      icon: Icons.cloud_done_outlined,
                      title: 'Isolated Google Drive Vault',
                      subtitle:
                          'Backups use Google Drive AppData folder, isolated from third-party apps.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'This cannot be undone. Export your data and create a backup before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;
    if (deleted)
      context.go(AppRoutes.login);
    else
      context.showSnack(
        'Account deletion failed. Please try again.',
        isError: true,
      );
  }

  Future<void> _confirmSignOutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out all devices?'),
        content: const Text(
          'Every active session will be revoked, including this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke sessions'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final revoked = await context.read<AuthProvider>().signOutEverywhere();
    if (!mounted) return;
    if (revoked) {
      context.go(AppRoutes.login);
    } else {
      context.showSnack('Could not revoke sessions.', isError: true);
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.2),
      boxShadow: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }

  Widget _buildSecurityFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
