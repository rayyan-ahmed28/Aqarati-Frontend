import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screens.dart';
import '../../features/broker/broker_screens.dart';
import '../../features/engagement/engagement_screens.dart';
import '../../features/help/help.dart';
import '../../features/provider/provider_screens.dart';
import '../../features/reviews/review_models.dart';
import '../../features/reviews/review_screens.dart';
import '../../features/listings/ebroker_screens.dart';
import '../../features/listings/listing_models.dart';
import '../../features/listings/listing_repository.dart';
import '../../features/listings/listing_screens.dart';
import '../../features/listings/listing_wizard.dart';
import '../aq/aq_kit.dart';
import '../aq/aq_scene.dart' show AQRoute, aqBack;

/// Routes added for the completion pass: help, listings and Aqary e-Broker. Every page uses the
/// shared AQRoute family so push / pop motion and RTL direction match the rest of the app.
List<RouteBase> productRoutes() => [
      // Contextual help: full guides open above the screen that asked, so Back returns to it.
      GoRoute(path: '/help', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const HelpCenterScreen())),
      GoRoute(path: '/help/:id', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: HelpArticleScreen(id: state.pathParameters['id']!))),

      // Listings (agent workspace and Aqary e-Broker sellers). `new` is matched before `:id`.
      GoRoute(path: '/listings', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const MyListingsScreen())),
      GoRoute(
        path: '/listings/new',
        pageBuilder: (context, state) => AQRoute.forward(
          key: state.pageKey,
          child: ListingWizardScreen(channel: state.uri.queryParameters['channel'] == 'agent' ? ListingChannel.agent : ListingChannel.eBroker, id: state.uri.queryParameters['draft']),
        ),
      ),
      GoRoute(path: '/listings/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ListingDetailScreen(id: state.pathParameters['id']!))),
      GoRoute(
        path: '/listings/:id/submitted',
        pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: ListingSubmittedScreen(id: state.pathParameters['id']!, resubmitted: state.uri.queryParameters['r'] == 'resubmitted')),
      ),
      GoRoute(path: '/listings/:id/fix', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: _ListingEdit(id: state.pathParameters['id']!, mode: ListingWizardMode.resubmit))),
      GoRoute(path: '/listings/:id/edit', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: _ListingEdit(id: state.pathParameters['id']!, mode: ListingWizardMode.edit))),
      GoRoute(path: '/sell', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SellIntroScreen())),
      // AqaratiBroker programme: intro -> directory -> profile -> approved listings -> property detail.
      GoRoute(path: '/brokers', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const BrokerProgrammeScreen())),
      GoRoute(path: '/brokers/all', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const BrokerDirectoryScreen())),
      GoRoute(path: '/brokers/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: BrokerProfileScreen(id: state.pathParameters['id']!))),
      // Professional engagements (client side) and reviews.
      GoRoute(path: '/engagements', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const MyEngagementsScreen())),
      GoRoute(path: '/engagements/new', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: EngagementRequestScreen(professionalId: state.uri.queryParameters['pro'] ?? ''))),
      GoRoute(path: '/engagements/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: EngagementDetailScreen(id: state.pathParameters['id']!))),
      GoRoute(path: '/reviews/mine', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const MyReviewsScreen())),
      GoRoute(path: '/reviews/write', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: _composer(state))),
      GoRoute(path: '/reviews/report', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: ReportReviewScreen(reviewId: state.uri.queryParameters['id'] ?? '', about: state.uri.queryParameters['about'] ?? ''))),
      GoRoute(path: '/reviews/:id/edit', pageBuilder: (context, state) => AQRoute.sheet(key: state.pageKey, child: _composer(state, editId: state.pathParameters['id']))),
      // Profile, organisation and settings.
      GoRoute(path: '/account/profile', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const PersonalProfileScreen())),
      GoRoute(path: '/account/profile/edit', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const EditProfileScreen())),
      GoRoute(path: '/account/organisation', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const OrganisationScreen())),
      GoRoute(path: '/account/settings', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SettingsScreen())),
      GoRoute(path: '/account/notification-settings', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const NotificationSettingsScreen())),
      GoRoute(path: '/account/privacy', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const PrivacyLegalScreen())),
      GoRoute(path: '/account/security', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SecurityScreen())),
      GoRoute(path: '/session-expired', pageBuilder: (context, state) => AQRoute.hero(key: state.pageKey, child: const SessionExpiredScreen())),
      // Maintenance provider: admin invitation -> onboarding -> verification -> workspace.
      GoRoute(path: '/invite/:token', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ProviderInvitationScreen(token: state.pathParameters['token']!))),
      GoRoute(path: '/provider', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const ProviderHomeScreen())),
      GoRoute(path: '/provider/status', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const ProviderStatusScreen())),
      GoRoute(path: '/provider/documents', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const ProviderDocumentsScreen())),
      GoRoute(path: '/provider/requests', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ProviderRequestsScreen(tab: state.uri.queryParameters['tab']))),
      GoRoute(path: '/provider/requests/:id', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: ProviderRequestDetailScreen(id: state.pathParameters['id']!))),
      GoRoute(path: '/sell/identity', pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const SellerIdentityScreen())),
    ];

Widget _composer(GoRouterState state, {String? editId}) {
  final q = state.uri.queryParameters;
  final kind = reviewKindOf(q['kind']);
  final id = q['id'] ?? '';
  if (kind == null || id.isEmpty) return const HelpArticleScreen(id: 'reviews');
  return ReviewComposerScreen(target: ReviewTarget(kind: kind, id: id, name: q['name'] ?? ''), initialRating: int.tryParse(q['rating'] ?? ''), editId: editId);
}

/// Opens the wizard for an existing listing with that listing's channel.
class _ListingEdit extends ConsumerWidget {
  final String id;
  final ListingWizardMode mode;
  const _ListingEdit({required this.id, required this.mode});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(listingProvider(id));
    final channel = l.valueOrNull?.channel ?? ListingChannel.eBroker;
    if (l.isLoading && !l.hasValue) return AQPlainPage(title: ' ', onBack: () => aqBack(context, '/listings'), children: const [AQSkeletonRows(count: 4, height: 64)]);
    return ListingWizardScreen(key: ValueKey('$id-${mode.name}'), channel: channel, mode: mode, id: id);
  }
}
