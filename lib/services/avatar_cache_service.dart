import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized robust cache for avatars to guarantee instant display
/// across Web, Mobile, and Desktop without CORS or network latency issues.
/// Stores in-memory and persists across browser refreshes via SharedPreferences.
class AvatarMemoryCache {
  static final Map<String, Uint8List> _cache = {};
  static bool _persistedLoaded = false;

  /// Store image bytes under one or more keys (URL, member ID, member name)
  static void set(String key, Uint8List bytes) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty || bytes.isEmpty) return;

    _cache[cleanKey] = bytes;
    _cache[cleanKey.toLowerCase()] = bytes;

    // Asynchronously persist to local storage (only for non-dataURI keys to save space)
    if (!cleanKey.startsWith('data:image')) {
      _persistLocally(cleanKey, bytes);
    }
  }

  static Future<void> _persistLocally(String key, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = base64Encode(bytes);
      await prefs.setString('mh_avatar_$key', base64String);
      await prefs.setString('mh_avatar_${key.toLowerCase()}', base64String);
    } catch (e) {
      debugPrint('Avatar cache persist note: $e');
    }
  }

  /// Retrieve cached image bytes synchronously from memory, or check case-insensitively
  static Uint8List? get(String? key) {
    if (key == null) return null;
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;

    if (_cache.containsKey(cleanKey)) {
      return _cache[cleanKey];
    }

    final lower = cleanKey.toLowerCase();
    if (_cache.containsKey(lower)) {
      return _cache[lower];
    }

    // Lazy load from persistent storage if available
    _lazyLoadFromStorage(cleanKey);

    return null;
  }

  static Future<void> _lazyLoadFromStorage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64 =
          prefs.getString('mh_avatar_$key') ??
          prefs.getString('mh_avatar_${key.toLowerCase()}');
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        _cache[key] = bytes;
        _cache[key.toLowerCase()] = bytes;
      }
    } catch (_) {}
  }

  /// Load all persisted avatars at app startup
  static Future<void> initPersisted() async {
    if (_persistedLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('mh_avatar_'));
      for (final k in keys) {
        final b64 = prefs.getString(k);
        if (b64 != null && b64.isNotEmpty) {
          final cleanKey = k.replaceFirst('mh_avatar_', '');
          final bytes = base64Decode(b64);
          _cache[cleanKey] = bytes;
          _cache[cleanKey.toLowerCase()] = bytes;
        }
      }
      _persistedLoaded = true;
    } catch (e) {
      debugPrint('Avatar cache init note: $e');
    }
  }

  /// Check if an image is cached
  static bool has(String? key) {
    if (key == null) return false;
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return false;
    return _cache.containsKey(cleanKey) ||
        _cache.containsKey(cleanKey.toLowerCase());
  }

  /// Clear cache if needed
  static void clear() {
    _cache.clear();
  }
}
