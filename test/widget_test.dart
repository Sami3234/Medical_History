// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_history/main.dart';
import 'package:medical_history/config/theme.dart';
import 'package:medical_history/models/member_model.dart';
import 'package:medical_history/providers/auth_provider.dart';
import 'package:medical_history/providers/backup_provider.dart';
import 'package:medical_history/providers/doctor_provider.dart';
import 'package:medical_history/providers/family_provider.dart';
import 'package:medical_history/providers/health_provider.dart';
import 'package:medical_history/providers/member_provider.dart';
import 'package:medical_history/providers/records_provider.dart';
import 'package:medical_history/providers/theme_provider.dart';
import 'package:medical_history/providers/notification_inbox_provider.dart';
import 'package:medical_history/providers/visit_provider.dart';
import 'package:medical_history/screens/home/dashboard_screen.dart';
import 'package:medical_history/screens/documents/upload_doc_screen.dart';
import 'package:medical_history/screens/profile/app_preferences_screen.dart';
import 'package:medical_history/screens/search/search_screen.dart';
import 'package:medical_history/widgets/tree_view.dart';

void main() {
  test('light and dark themes interpolate safely', () {
    expect(
      () => ThemeData.lerp(AppTheme.light, AppTheme.dark, 0.5),
      returnsNormally,
    );
  });

  testWidgets('dark preferences fit a narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pref_theme': 'Dark Mode'});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeController(),
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const AppPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STORAGE & LOCAL CACHE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preferences can switch to dark mode without widget errors', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = AppThemeController();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeController,
        child: Consumer<AppThemeController>(
          builder: (context, controller, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.mode,
            home: const AppPreferencesScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medical Green (Default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark Mode').last);
    await tester.pumpAndSettle();

    expect(themeController.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the Medical History splash screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeController(),
        child: const MyApp(),
      ),
    );
    expect(find.text('Medical History'), findsOneWidget);
    expect(find.text("Your Family's Health Companion"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('family tree lays out safely on a mobile dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 10, 22);
    final members = [
      MemberModel(
        id: 'grandfather',
        familyId: 'family',
        name: 'Grandfather',
        relation: 'Grandfather',
        createdAt: now,
      ),
      MemberModel(
        id: 'father',
        familyId: 'family',
        name: 'Father',
        relation: 'Father',
        createdAt: now,
      ),
      MemberModel(
        id: 'self',
        familyId: 'family',
        name: 'Sami Khan',
        relation: 'Self',
        createdAt: now,
      ),
      MemberModel(
        id: 'spouse',
        familyId: 'family',
        name: 'Spouse',
        relation: 'Spouse',
        createdAt: now,
      ),
      MemberModel(
        id: 'child',
        familyId: 'family',
        name: 'Child',
        relation: 'Son',
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: InteractiveTreeView(
                  members: members,
                  currentUserName: 'Sami Khan',
                  familyName: 'Sami Khan',
                  showToolbar: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sami Khan'), findsWidgets);
  });

  testWidgets('dashboard body renders on a mobile viewport', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FamilyProvider()),
          ChangeNotifierProvider(create: (_) => MemberProvider()),
          ChangeNotifierProvider(create: (_) => DoctorProvider()),
          ChangeNotifierProvider(create: (_) => HealthProvider()),
          ChangeNotifierProvider(create: (_) => RecordsProvider()),
          ChangeNotifierProvider(create: (_) => NotificationInboxProvider()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Medical History'), findsOneWidget);
    expect(find.text('Medical history hub'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('dashboard renders with dark theme surfaces', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pref_theme': 'Dark Mode'});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FamilyProvider()),
          ChangeNotifierProvider(create: (_) => MemberProvider()),
          ChangeNotifierProvider(create: (_) => DoctorProvider()),
          ChangeNotifierProvider(create: (_) => HealthProvider()),
          ChangeNotifierProvider(create: (_) => RecordsProvider()),
          ChangeNotifierProvider(create: (_) => NotificationInboxProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppTheme.dark.scaffoldBackgroundColor);
    expect(find.text('Medical history hub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health search fits a narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FamilyProvider()),
          ChangeNotifierProvider(create: (_) => MemberProvider()),
          ChangeNotifierProvider(create: (_) => DoctorProvider()),
          ChangeNotifierProvider(create: (_) => VisitProvider()),
          ChangeNotifierProvider(create: (_) => HealthProvider()),
          ChangeNotifierProvider(create: (_) => RecordsProvider()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('health-search-field')), findsOneWidget);
    expect(find.text('Search across your records'), findsOneWidget);
    expect(find.text('Members 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('document upload fits a narrow dark viewport', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MemberProvider()),
          ChangeNotifierProvider(create: (_) => VisitProvider()),
          ChangeNotifierProvider(create: (_) => RecordsProvider()),
          ChangeNotifierProvider(create: (_) => BackupProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const UploadDocScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Save a health record'), findsOneWidget);
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Discharge summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
