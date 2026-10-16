class AppStrings {
  static const appName = 'Medical History';
  static const appTagline = 'Your Family\'s Health Companion';

  // Supabase — Connected to user project
  static const supabaseUrl = 'https://fqcnpqrdxwttcxrcdnyg.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_dDQY6go24zOVKRhHBXoh8Q_lbTpzZSh';

  // Storage Buckets
  static const prescriptionBucket = 'prescriptions';
  static const reportBucket = 'reports';
  static const avatarBucket = 'avatars';
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
