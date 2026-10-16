class Validators {
  static String? required(String? val, [String field = 'This field']) {
    if (val == null || val.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(val)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? val) {
    if (val == null || val.trim().isEmpty) return 'Password is required';
    if (val.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? val, String password) {
    if (val == null || val.trim().isEmpty) return 'Confirm your password';
    if (val != password) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? val) {
    if (val == null || val.trim().isEmpty) return null; // optional
    final regex = RegExp(r'^\+?[\d\s-]{10,}$');
    if (!regex.hasMatch(val)) return 'Enter a valid phone number';
    return null;
  }
}
