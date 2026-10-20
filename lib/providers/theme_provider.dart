import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const _themeKey = 'pref_theme';

  ThemeMode _mode = ThemeMode.light;
  String _selection = 'Medical Green (Default)';

  ThemeMode get mode => _mode;
  String get selection => _selection;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _selection = prefs.getString(_themeKey) ?? _selection;
    _mode = _modeFor(_selection);
  }

  Future<void> setTheme(String selection) async {
    _selection = selection;
    _mode = _modeFor(selection);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, selection);
  }

  ThemeMode _modeFor(String selection) {
    return selection == 'Dark Mode' ? ThemeMode.dark : ThemeMode.light;
  }
}
