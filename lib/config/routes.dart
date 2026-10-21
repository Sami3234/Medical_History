import 'package:go_router/go_router.dart';
import 'supabase_config.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/owner_setup_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/family/family_list_screen.dart';
import '../screens/family/family_form_screen.dart';
import '../screens/family/family_detail_screen.dart';
import '../screens/member/member_list_screen.dart';
import '../screens/member/member_form_screen.dart';
import '../screens/member/member_detail_screen.dart';
import '../screens/doctor/doctor_list_screen.dart';
import '../screens/doctor/doctor_form_screen.dart';
import '../screens/doctor/doctor_detail_screen.dart';
import '../screens/visit/visit_list_screen.dart';
import '../screens/visit/visit_form_screen.dart';
import '../screens/visit/visit_detail_screen.dart';
import '../screens/documents/docs_screen.dart';
import '../screens/documents/upload_doc_screen.dart';
import '../screens/appointments/appointments_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/backup/backup_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/security_privacy_screen.dart';
import '../screens/profile/notifications_settings_screen.dart';
import '../screens/profile/app_preferences_screen.dart';
import '../screens/share/shared_member_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const verifyEmail = '/verify-email';
  static const ownerSetup = '/owner-setup';
  static const dashboard = '/dashboard';
  static const families = '/families';
  static const familyAdd = '/families/add';
  static const familyDetail = '/families/:id';
  static const members = '/members';
  static const memberAdd = '/members/add';
  static const memberEdit = '/members/:id/edit';
  static const memberDetail = '/members/:id';
  static const doctors = '/doctors';
  static const doctorAdd = '/doctors/add';
  static const doctorEdit = '/doctors/:id/edit';
  static const doctorDetail = '/doctors/:id';
  static const visits = '/visits';
  static const visitAdd = '/visits/add';
  static const visitDetail = '/visits/:id';
  static const documents = '/documents';
  static const uploadDoc = '/documents/upload';
  static const appointments = '/appointments';
  static const search = '/search';
  static const backup = '/backup';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const security = '/settings/security';
  static const notifications = '/settings/notifications';
  static const preferences = '/settings/preferences';
  static const sharedMember = '/shared-member';

  static final router = GoRouter(
    initialLocation: splash,
    redirect: (_, state) {
      if (!SupabaseConfig.isInitialized) return null;
      final loggedIn = SupabaseConfig.auth?.currentUser != null;
      final location = state.matchedLocation;
      final publicRoute =
          location == splash ||
          location == onboarding ||
          location == login ||
          location == register ||
          location == forgot ||
          location == verifyEmail ||
          location == sharedMember;

      if (!loggedIn && !publicRoute) return login;
      if (loggedIn && (location == register || location == onboarding)) {
        return ownerSetup;
      }
      return null;
    },
    routes: [
      GoRoute(path: splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: forgot, builder: (_, _) => const ForgotScreen()),
      GoRoute(
        path: verifyEmail,
        builder: (_, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(path: ownerSetup, builder: (_, _) => const OwnerSetupScreen()),
      GoRoute(
        path: sharedMember,
        builder: (_, state) =>
            SharedMemberScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(path: dashboard, builder: (_, _) => const DashboardScreen()),
      GoRoute(path: families, builder: (_, _) => const FamilyListScreen()),
      GoRoute(path: familyAdd, builder: (_, _) => const FamilyFormScreen()),
      GoRoute(
        path: familyDetail,
        builder: (_, state) =>
            FamilyDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: members, builder: (_, _) => const MemberListScreen()),
      GoRoute(path: memberAdd, builder: (_, _) => const MemberFormScreen()),
      GoRoute(
        path: memberEdit,
        builder: (_, state) =>
            MemberFormScreen(memberId: state.pathParameters['id']),
      ),
      GoRoute(
        path: memberDetail,
        builder: (_, state) =>
            MemberDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: doctors, builder: (_, _) => const DoctorListScreen()),
      GoRoute(path: doctorAdd, builder: (_, _) => const DoctorFormScreen()),
      GoRoute(
        path: doctorEdit,
        builder: (_, state) =>
            DoctorFormScreen(doctorId: state.pathParameters['id']),
      ),
      GoRoute(
        path: doctorDetail,
        builder: (_, state) =>
            DoctorDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: visits, builder: (_, _) => const VisitListScreen()),
      GoRoute(
        path: visitAdd,
        builder: (_, state) =>
            VisitFormScreen(memberId: state.uri.queryParameters['memberId']),
      ),
      GoRoute(
        path: visitDetail,
        builder: (_, state) =>
            VisitDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: documents, builder: (_, _) => const DocsScreen()),
      GoRoute(
        path: uploadDoc,
        builder: (_, state) =>
            UploadDocScreen(memberId: state.uri.queryParameters['memberId']),
      ),
      GoRoute(
        path: appointments,
        builder: (_, _) => const AppointmentsScreen(),
      ),
      GoRoute(path: search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: backup, builder: (_, _) => const BackupScreen()),
      GoRoute(path: profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: security, builder: (_, _) => const SecurityPrivacyScreen()),
      GoRoute(
        path: notifications,
        builder: (_, _) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: preferences,
        builder: (_, _) => const AppPreferencesScreen(),
      ),
    ],
  );
}
