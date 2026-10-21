import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/data/demo/demo_providers.dart';
import 'package:aqarati_app/features/account/account_screens.dart';
import 'package:aqarati_app/features/broker/broker_screens.dart';
import 'package:aqarati_app/features/devbuild/db_repository.dart';
import 'package:aqarati_app/features/engagement/engagement_screens.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/help/help.dart';
import 'package:aqarati_app/features/listings/ebroker_screens.dart';
import 'package:aqarati_app/features/listings/listing_models.dart';
import 'package:aqarati_app/features/listings/listing_repository.dart';
import 'package:aqarati_app/features/listings/listing_screens.dart';
import 'package:aqarati_app/features/listings/listing_wizard.dart';
import 'package:aqarati_app/features/provider/provider_screens.dart';
import 'package:aqarati_app/features/reviews/review_models.dart';
import 'package:aqarati_app/features/reviews/review_screens.dart';
import 'package:aqarati_app/features/system/version_gate.dart';
import 'package:aqarati_app/features/workspace/aq_app_shell.dart' show AccountTab;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout matrix for every screen added in the completion pass: narrow width, dark, Arabic RTL and
/// 200% text. Release builds do not paint overflow stripes, so overflow is caught here.

const agent = MeSession(account: AccountState.active, purpose: SignupPurpose.realEstateAgent, grant: GrantState.approved, firstName: 'Demo', lastName: 'Agent', email: 'agent@example.test', phoneLast4: '0000', businessName: 'Demo Realty', providerGrant: GrantState.approved);

final _screens = <String, Widget Function()>{
  'Account tab': () => const AccountTab(),
  'My listings': () => const MyListingsScreen(),
  'Listing wizard (agent)': () => const ListingWizardScreen(channel: ListingChannel.agent),
  'Listing wizard (e-Broker)': () => const ListingWizardScreen(channel: ListingChannel.eBroker),
  'Listing detail (missing)': () => const ListingDetailScreen(id: 'none'),
  'Sell intro': () => const SellIntroScreen(),
  'Seller photo ID': () => const SellerIdentityScreen(),
  'Broker programme': () => const BrokerProgrammeScreen(),
  'Broker directory': () => const BrokerDirectoryScreen(),
  'Broker profile': () => const BrokerProfileScreen(id: 'ab1'),
  'Help centre': () => const HelpCenterScreen(),
  'Help article': () => const HelpArticleScreen(id: 'buyRentInvest'),
  'My engagements': () => const MyEngagementsScreen(),
  'Engagement request': () => const EngagementRequestScreen(professionalId: 'demo-c1'),
  'My reviews': () => const MyReviewsScreen(),
  'Review composer (gate)': () => const ReviewComposerScreen(target: ReviewTarget(kind: ReviewTargetKind.professional, id: 'demo-c1', name: 'A long company name that wraps')),
  'Report review': () => const ReportReviewScreen(reviewId: 'r', about: 'Company'),
  'Personal profile': () => const PersonalProfileScreen(),
  'Edit profile': () => const EditProfileScreen(),
  'Organisation': () => const OrganisationScreen(),
  'Settings': () => const SettingsScreen(),
  'Notification settings': () => const NotificationSettingsScreen(),
  'Privacy & legal': () => const PrivacyLegalScreen(),
  'Security': () => const SecurityScreen(),
  'Session expired': () => const SessionExpiredScreen(),
  'Provider invitation': () => const ProviderInvitationScreen(token: 'demo-invite'),
  'Provider status': () => const ProviderStatusScreen(),
  'Provider home': () => const ProviderHomeScreen(),
  'Provider requests': () => const ProviderRequestsScreen(),
  'Forced update': () => const ForcedUpdateScreen(minVersion: '9.9.9'),
};

class _Cfg {
  final String name;
  final double width, height, scale;
  final bool dark, rtl;
  const _Cfg(this.name, this.width, this.height, {this.scale = 1, this.dark = false, this.rtl = false});
}

const _configs = [
  _Cfg('320 light', 320, 700),
  _Cfg('360 Arabic RTL', 360, 740, rtl: true),
  _Cfg('393 at 200% text', 393, 852, scale: 2.0),
  _Cfg('430 dark Arabic RTL', 430, 900, dark: true, rtl: true),
];

void main() {
  for (final cfg in _configs) {
    group('new screens ${cfg.name}', () {
      for (final e in _screens.entries) {
        testWidgets(e.key, (t) async {
          SharedPreferences.setMockInitialValues({});
          t.view.physicalSize = Size(cfg.width, cfg.height);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final s = DemoBackendState()..providerGrant = GrantState.approved;
          await t.pumpWidget(ProviderScope(
            overrides: [
              meProvider.overrideWith((ref) async => agent),
              demoBackendStateProvider.overrideWithValue(s),
              devBuildRepositoryProvider.overrideWithValue(DemoDevBuildRepository(() => s, lag: Duration.zero)),
              listingRepositoryProvider.overrideWithValue(DemoListingRepository(session: () async => agent, latency: Duration.zero)),
            ],
            child: MaterialApp(
              theme: ThemeData(brightness: cfg.dark ? Brightness.dark : Brightness.light),
              locale: Locale(cfg.rtl ? 'ar' : 'en'),
              localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
              supportedLocales: const [Locale('en'), Locale('ar')],
              home: MediaQuery(data: MediaQueryData(size: Size(cfg.width, cfg.height), textScaler: TextScaler.linear(cfg.scale)), child: Scaffold(body: e.value())),
            ),
          ));
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 300));
          }
          expect(t.takeException(), isNull);
        });
      }
    });
  }
}
