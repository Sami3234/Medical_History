import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/family_provider.dart';
import 'providers/member_provider.dart';
import 'providers/doctor_provider.dart';
import 'providers/visit_provider.dart';
import 'providers/records_provider.dart';
import 'providers/backup_provider.dart';

import 'services/avatar_cache_service.dart';
import 'services/notification_service.dart';
import 'services/native_document_service.dart';

import 'providers/health_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  await AvatarMemoryCache.initPersisted();
  await NotificationService.initialize();
  try {
    await NativeDocumentService.importSharedFilesToDrafts();
  } catch (_) {}
  final themeController = AppThemeController();
  await themeController.load();
  runApp(
    ChangeNotifierProvider.value(value: themeController, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => VisitProvider()),
        ChangeNotifierProvider(create: (_) => RecordsProvider()),
        ChangeNotifierProvider(create: (_) => BackupProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
      ],
      child: Consumer<AppThemeController>(
        builder: (context, themeController, _) => MaterialApp.router(
          title: 'Medical History',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          routerConfig: AppRoutes.router,
        ),
      ),
    );
  }
}
