import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class SupabaseConfig {
  static bool get isConfigured =>
      AppStrings.supabaseUrl.startsWith('http') &&
      !AppStrings.supabaseUrl.contains('YOUR_SUPABASE_URL') &&
      AppStrings.supabaseAnonKey.isNotEmpty &&
      !AppStrings.supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    if (!isConfigured) {
      debugPrint('Supabase credentials are not configured.');
      return;
    }
    try {
      await Supabase.initialize(
        url: AppStrings.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppStrings.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
          persistSession: true,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }
  }

  // Quick accessors
  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;
  static SupabaseClient? get db => client;
  static GoTrueClient? get auth => _initialized ? client?.auth : null;
  static String? get currentUserId => auth?.currentUser?.id;
  static SupabaseStorageClient? get storage =>
      _initialized ? client?.storage : null;
}
