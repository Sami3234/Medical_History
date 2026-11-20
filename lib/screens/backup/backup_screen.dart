import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/backup_provider.dart';
import '../../providers/records_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/info_banner.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  void _showRestoreConfirmation(
    BuildContext context,
    BackupProvider backupProv,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text(
              'Restore Backup?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will download and sync records from your Google Drive backup into your account. Existing records will be updated.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await backupProv.triggerRestore();
              if (success && context.mounted) {
                await context.read<RecordsProvider>().loadAll();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.error,
                    content: Text(
                      success
                          ? 'Backup restored successfully from Google Drive!'
                          : (backupProv.error ?? 'Restore failed'),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );
  }

  void _showFrequencyDialog(BuildContext context, BackupProvider backupProv) {
    final frequencies = ['Daily', 'Weekly', 'Monthly', 'Off'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto-Backup Frequency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select how often Medical History should sync backups to Google Drive.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...frequencies.map((freq) {
              final isSelected = backupProv.autoBackupFrequency == freq;
              return ListTile(
                title: Text(
                  freq,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () {
                  backupProv.setAutoBackupFrequency(freq);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupProv = context.watch<BackupProvider>();
    final meta = backupProv.backupMetadata;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SECURE CLOUD STORAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Google Drive Backup',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 18),

              // Hero Gradient Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          Icons.cloud_sync_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Hidden AppData',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your data, always protected.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'WhatsApp-style private backups in your Google Drive. Never lose family records, prescriptions, or history.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(220),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Error banner if any
              if (backupProv.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          backupProv.error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        onPressed: backupProv.clearError,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Google Drive Account Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.2),
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_to_drive_rounded,
                        color: AppColors.primaryDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            backupProv.isConnected
                                ? (backupProv.currentUser?.email ?? 'Connected')
                                : 'Not connected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: backupProv.isConnected
                                  ? AppColors.primary
                                  : AppColors.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: backupProv.isLoadingInfo
                          ? null
                          : () {
                              if (backupProv.isConnected) {
                                backupProv.disconnectDrive();
                              } else {
                                backupProv.connectDrive();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: backupProv.isConnected
                            ? Colors.grey.shade100
                            : const Color(0xFFE6F4ED),
                        foregroundColor: backupProv.isConnected
                            ? Colors.grey.shade700
                            : AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: backupProv.isLoadingInfo
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              backupProv.isConnected ? 'Disconnect' : 'Connect',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Backup Metadata Stats Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Backup Status',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.appTextPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Google Drive AppData Storage',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: meta != null
                                ? AppColors.success.withAlpha(20)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            meta != null ? 'Synced' : 'No Backup',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: meta != null
                                  ? AppColors.success
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context: context,
                            icon: Icons.calendar_today_rounded,
                            label: 'Last Backup',
                            value: meta != null
                                ? DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(meta.modifiedTime)
                                : 'Never',
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            context: context,
                            icon: Icons.data_usage_rounded,
                            label: 'Backup Size',
                            value: meta != null ? meta.formattedSize : '0 KB',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Actions Section
              Text(
                'Backup & Restore',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Button 1: Create Backup
              _buildActionCard(
                context: context,
                icon: Icons.cloud_upload_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Back Up Now',
                subtitle: backupProv.isBackingUp
                    ? 'Exporting & uploading to Google Drive...'
                    : 'Create a fresh private backup copy',
                isLoading: backupProv.isBackingUp,
                onTap: () async {
                  final success = await backupProv.triggerBackup();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: success
                            ? AppColors.success
                            : AppColors.error,
                        content: Text(
                          success
                              ? 'Backup successfully created & saved to Google Drive!'
                              : (backupProv.error ??
                                    'Backup failed. Please check connection.'),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              // Button 2: Restore from Backup
              _buildActionCard(
                context: context,
                icon: Icons.cloud_download_rounded,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Restore from Google Drive',
                subtitle: backupProv.isRestoring
                    ? 'Downloading & recovering records...'
                    : 'Sync records onto this device',
                isLoading: backupProv.isRestoring,
                onTap: () => _showRestoreConfirmation(context, backupProv),
              ),
              const SizedBox(height: 12),

              // Option 3: Auto-backup Frequency Setting
              InkWell(
                onTap: () => _showFrequencyDialog(context, backupProv),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.update_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Backup Schedule',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.appTextPrimary,
                              ),
                            ),
                            Text(
                              'Frequency: ${backupProv.autoBackupFrequency}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Info Banner: Privacy & Encryption
              const InfoBanner(
                icon: Icons.shield_rounded,
                title: 'Private Google Drive backup',
                subtitle:
                    'Backups use your personal Google Drive hidden app container. Client-side encryption will be added before production release.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textLight,
              ),
          ],
        ),
      ),
    );
  }
}
