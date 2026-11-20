class AppAssets {
  static const logo = 'assets/images/logo.png';
  static const logoSvg = 'assets/images/logo.svg';
  static const logoTransparent = 'assets/images/logo_transparent.svg';
  static const icon192 = 'assets/icons/android-chrome-192x192.png';
  static const icon512 = 'assets/icons/android-chrome-512x512.png';
}

class AppStrings {
  static const appName = 'Medical History';
  static const appTagline = 'Your Family\'s Health Companion';

  // Supabase — Connected to user project
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fqcnpqrdxwttcxrcdnyg.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_dDQY6go24zOVKRhHBXoh8Q_lbTpzZSh',
  );

  // Storage Buckets
  static const prescriptionBucket = 'prescriptions';
  static const reportBucket = 'reports';
  static const avatarBucket = 'avatars';

  // Cloudinary Image Storage
  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'y9g0h85i',
  );
  static const cloudinaryApiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '812541362389264',
  );
  static const cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'medical_history',
  );

  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1037238815678-pc1p6sbs2rtr91pj59j1jk3g8jq39gq0.apps.googleusercontent.com',
  );
  static const temporaryShareApiUrl = String.fromEnvironment(
    'TEMP_SHARE_API_URL',
    defaultValue:
        'https://medical-history-temporary-share.kk34samikhan.workers.dev',
  );
}

class AppNetwork {
  /// Slow connections stop waiting here instead of spinning for minutes.
  static const dataTimeout = Duration(seconds: 4);

  /// Quick timeout for responsive UI prefetching & non-blocking revalidation.
  static const quickTimeout = Duration(seconds: 3);

  /// Maximum time the splash screen is allowed to hold before opening dashboard.
  static const maxSplashTimeout = Duration(milliseconds: 3200);

  /// Minimum time the splash screen displays its opening animation.
  static const minSplashDuration = Duration(milliseconds: 2200);
}

class AppKeys {
  static const isFirstLaunch = 'is_first_launch';
  static const lastBackup = 'last_backup_date';
}

enum Relation {
  father,
  mother,
  husband,
  wife,
  son,
  daughter,
  brother,
  sister,
  grandfather,
  grandmother,
  other;

  String get label => name[0].toUpperCase() + name.substring(1);
}

enum Gender {
  male,
  female,
  other;

  String get label => name[0].toUpperCase() + name.substring(1);
}

enum BloodGroup {
  aPos('A+'),
  aNeg('A-'),
  bPos('B+'),
  bNeg('B-'),
  abPos('AB+'),
  abNeg('AB-'),
  oPos('O+'),
  oNeg('O-');

  final String label;
  const BloodGroup(this.label);
}

enum FileType {
  prescription,
  labReport,
  xray,
  scan,
  other;

  String get label {
    switch (this) {
      case prescription:
        return 'Prescription';
      case labReport:
        return 'Lab Report';
      case xray:
        return 'X-Ray';
      case scan:
        return 'Scan';
      case other:
        return 'Other';
    }
  }
}
