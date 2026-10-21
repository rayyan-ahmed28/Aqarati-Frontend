import 'package:flutter/widgets.dart' show ValueKey;
import 'package:go_router/go_router.dart';
import '../../features/business/aq_business_profile.dart';
import '../../features/business/aq_professionals.dart';
import '../../features/property/property_detail_screen.dart';
import '../../features/account/delete_account_screen.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/compare/compare_screen.dart';
import '../../features/maintenance/maintenance_screens.dart';
import '../../features/notifications/notifications.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/aq_map.dart';
import '../../features/search/aq_property_types.dart';
import '../../features/search/aq_search.dart';
import '../../features/entry/screens/onboarding_entry_screen.dart';
import '../../features/entry/models/signup_purpose.dart';
import '../../features/flow/screens/auth_screens.dart';
import '../../features/flow/screens/email_verification_screen.dart';
import '../../features/flow/screens/legal_screens.dart';
import '../../features/flow/screens/otp_screens.dart';
import '../../features/flow/screens/signup_form_screen.dart';
import '../../features/flow/screens/approval_screens.dart';
import '../../features/flow/screens/verification_onboarding_screens.dart';
import '../../features/flow/screens/verification_status_screens.dart';
import '../../features/entry/screens/purpose_selection_screen.dart';
import '../../features/entry/widgets/entry_common.dart';
import '../../features/viewing/screens/viewing_detail_screen.dart';
import '../../features/viewing/screens/viewing_schedule_screens.dart';
import '../../features/viewing/screens/viewing_status_screens.dart';
import '../../features/workspace/aq_home.dart' show AQPropertiesScreen;
import '../../features/calculators/calculator_models.dart';
import '../../features/calculators/calculator_screen.dart';
import '../../features/calculators/calculators_list_screen.dart';
import '../aq/aq_scene.dart' show AQRoute;
import '../../features/workspace/aq_app_shell.dart';
import '../../features/devbuild/db_routes.dart';
import 'product_routes.dart';
import '../../features/reviews/review_screens.dart' show ViewingReviewBridge;

final appRouter = GoRouter(
  initialLocation: '/entry',
  routes: [
    GoRoute(path: '/entry', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const OnboardingEntryScreen())),
    GoRoute(path: '/onboarding/purpose', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const PurposeSelectionScreen())),
    GoRoute(path: '/legal/terms', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: const LegalScreen(kind: LegalKind.terms))),
    GoRoute(path: '/legal/privacy', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: const LegalScreen(kind: LegalKind.privacy))),
    GoRoute(path: '/login', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const LoginScreen())),
    GoRoute(path: '/forgot-password', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ForgotPasswordScreen())),
    GoRoute(path: '/reset-password', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: ResetPasswordScreen(key: ValueKey(state.uri.queryParameters['oobCode']), oobCode: state.uri.queryParameters['oobCode']))),
    for (final o in signupPurposeOptions)
      GoRoute(path: o.route, pageBuilder: (context, state) => brandPage(key: state.pageKey, child: SignupFormScreen(purpose: o.id))),
    GoRoute(path: '/otp', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const OtpScreen())),
    GoRoute(path: '/verify-email', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const EmailVerificationScreen())),
    GoRoute(path: '/account/active', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const AccountActiveScreen())),
    GoRoute(path: '/onboarding/documents', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const DocumentOnboardingScreen())),
    GoRoute(path: '/onboarding/verification-intro', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const VerificationIntroScreen())),
    GoRoute(path: '/onboarding/review', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ApplicationReviewScreen())),
    GoRoute(path: '/onboarding/submitted', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ApplicationSubmittedScreen())),
    GoRoute(path: '/verification', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const VerificationStatusScreen())),
    GoRoute(path: '/verification/details', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ApplicationDetailsScreen())),
    GoRoute(path: '/verification/resubmit', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ResubmissionScreen())),
    GoRoute(path: '/verification/resubmit/review', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ResubmitReviewScreen())),
    GoRoute(path: '/verification/resubmitted', pageBuilder: (context, state) => brandPage(key: state.pageKey, child: const ResubmittedScreen())),
    GoRoute(path: '/verification/approved', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: const ApprovedScreen())),
    GoRoute(path: '/verification/summary', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: const VerifiedSummaryScreen())),
    GoRoute(path: '/workspace/activation', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: const WorkspaceActivationScreen())),
    ShellRoute(
      builder: (context, state, child) => AQAppShell(child: child),
      routes: [
        GoRoute(path: '/app/home', pageBuilder: (context, state) => AQRoute.tab(key: state.pageKey, child: const HomeTab())),
        GoRoute(path: '/app/explore', pageBuilder: (context, state) => AQRoute.tab(key: state.pageKey, child: const ExploreTab())),
        GoRoute(path: '/app/activity', pageBuilder: (context, state) => AQRoute.tab(key: state.pageKey, child: const ActivityScreen())),
        GoRoute(path: '/app/account', pageBuilder: (context, state) => AQRoute.tab(key: state.pageKey, child: const AccountTab())),
        ...dbShellRoutes(),
      ],
    ),
    // Property viewing journey (screens 39-51). Back reverses the logical journey.
    GoRoute(path: '/property/:id/viewing', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ViewingAvailabilityScreen(propertyId: state.pathParameters['id']!))),
    GoRoute(path: '/property/:id/viewing/slot', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ViewingSlotScreen(propertyId: state.pathParameters['id']!))),
    GoRoute(path: '/property/:id/viewing/review', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ViewingReviewScreen(propertyId: state.pathParameters['id']!))),
    GoRoute(path: '/property/:id/viewing/conflict', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingConflictScreen(propertyId: state.pathParameters['id']!))),
    GoRoute(path: '/viewings', redirect: (context, state) => '/app/activity'),
    GoRoute(path: '/viewings/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ViewingDetailScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/requested', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingRequestedScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/confirmed', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingConfirmedScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/declined', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingDeclinedScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/reschedule', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: ViewingRescheduleScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/cancel', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: ViewingCancelScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/cancelled', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingCancelledScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/completed', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ViewingCompletedScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/viewings/:id/review', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: ViewingReviewBridge(viewingId: state.pathParameters['id']!, rating: int.tryParse(state.uri.queryParameters['rating'] ?? '')))),
    GoRoute(path: '/properties', pageBuilder: (context, state) {
      final q = state.uri.queryParameters;
      final plain = q['cat'] == null && q['tx'] == null && q['types'] == null;
      return AQRoute.forward(key: state.pageKey, child: plain ? const AQPropertyTypesScreen() : AQPropertiesScreen(category: state.uri.queryParameters['cat'], tx: state.uri.queryParameters['tx'], types: state.uri.queryParameters['types']));
    }),
    GoRoute(path: '/properties/all', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: AQPropertiesScreen(category: state.uri.queryParameters['cat'], tx: state.uri.queryParameters['tx'], types: state.uri.queryParameters['types']))),
    ...dbStandaloneRoutes(),
    ...productRoutes(),
    GoRoute(path: '/map', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: AQMapScreen(tx: state.uri.queryParameters['tx']))),
    GoRoute(path: '/calculators', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const CalculatorsListScreen())),
    GoRoute(
      path: '/calculators/:id',
      pageBuilder: (context, state) {
        final type = CalculatorType.values.where((t) => t.name == state.pathParameters['id']).firstOrNull;
        return AQRoute.forward(key: state.pageKey, child: type == null ? const CalculatorsListScreen() : CalculatorScreen(type: type));
      },
    ),
    GoRoute(path: '/business/:id/book', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: MaintenanceBookScreen(providerId: state.pathParameters['id']!))),
    GoRoute(path: '/bookings/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: MaintenanceDetailScreen(id: state.pathParameters['id']!))),
    GoRoute(path: '/notifications', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const NotificationsScreen())),
    GoRoute(path: '/account/delete', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const DeleteAccountScreen())),
    GoRoute(
      path: '/compare',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: CompareScreen(propertyIds: (state.uri.queryParameters['ids'] ?? '').split(',').where((x) => x.isNotEmpty).toList())),
    ),
    GoRoute(path: '/saved', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SavedScreen())),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: SearchResultsScreen(initialQuery: state.uri.queryParameters['q'])),
    ),
    GoRoute(path: '/search/start', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SearchScreen())),
    GoRoute(
      path: '/property/:id',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: PropertyDetailScreen(propertyId: state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/professionals',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: AQProfessionalsScreen(key: ValueKey(state.uri.toString()), query: state.uri.queryParameters['q'], category: state.uri.queryParameters['cat'])),
    ),
    GoRoute(
      path: '/business/:id',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: AQBusinessProfileScreen(businessId: state.pathParameters['id']!)),
    ),
  ],
);
