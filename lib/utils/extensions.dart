import 'package:flutter/material.dart';

extension StringX on String {
  String get capitalize => '${this[0].toUpperCase()}${substring(1)}';

  String get titleCase => split(' ').map((w) => w.capitalize).join(' ');
}

extension DateX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  bool get isPast => isBefore(DateTime.now());
}

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colors => theme.colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  void showSnack(String msg, {bool isError = false}) {
    String displayMsg = msg;
    final lower = msg.toLowerCase();

    // Prevent any backend exposure in user-facing toasts & snacks
    if (lower.contains('cloudinary') ||
        lower.contains('supabase') ||
        lower.contains('postgrest') ||
        lower.contains('postgres')) {
      if (isError) {
        displayMsg = 'An unexpected error occurred. Please try again.';
      } else {
        displayMsg = displayMsg
            .replaceAll(RegExp(r'to cloudinary', caseSensitive: false), '')
            .replaceAll(RegExp(r'via cloudinary', caseSensitive: false), '')
            .replaceAll(RegExp(r'on cloudinary', caseSensitive: false), '')
            .replaceAll(RegExp(r'cloudinary', caseSensitive: false), '')
            .replaceAll(RegExp(r'supabase', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+!'), '!')
            .trim();
      }
    }

    if (isError) {
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('no address associated') ||
          lower.contains('authretryablefetchexception') ||
          lower.contains('clientexception') ||
          lower.contains('connection refused') ||
          lower.contains('network is unreachable') ||
          lower.contains('timed out')) {
        displayMsg =
            'Unable to connect. Please check your internet connection.';
      } else if (lower.contains('invalid login') ||
          lower.contains('invalid credentials') ||
          lower.contains('invalid_grant')) {
        displayMsg = 'Incorrect email or password. Please try again.';
      } else if (lower.contains('multipartfile') ||
          lower.contains('dart:io') ||
          lower.contains('unsupported operation') ||
          lower.contains('http://') ||
          lower.contains('https://') ||
          lower.contains('exception:') ||
          lower.contains('errno =')) {
        displayMsg = 'Unable to complete request. Please try again.';
      }
    }

    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          displayMsg,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
