import 'dart:typed_data';

import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/core/router/product_routes.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/data/demo/demo_providers.dart';
import 'package:aqarati_app/features/devbuild/db_repository.dart';
import 'package:aqarati_app/features/engagement/engagement_repository.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/help/help.dart';
import 'package:aqarati_app/features/listings/listing_models.dart';
import 'package:aqarati_app/features/listings/listing_repository.dart';
import 'package:aqarati_app/features/listings/listing_widgets.dart';
import 'package:aqarati_app/features/maintenance/maintenance_models.dart';
import 'package:aqarati_app/features/maintenance/maintenance_repository.dart';
import 'package:aqarati_app/features/provider/provider_data.dart';
import 'package:aqarati_app/features/reviews/review_repository.dart';
import 'package:aqarati_app/features/system/version_gate.dart';
import 'package:aqarati_app/features/workspace/aq_app_shell.dart' show AccountTab;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end journeys through the routes added in the completion pass, on the real route table.

const agent = MeSession(account: AccountState.active, purpose: SignupPurpose.realEstateAgent, grant: GrantState.approved, firstName: 'Demo', lastName: 'Agent', email: 'agent@example.test', phoneLast4: '0000');
const buyer = MeSession(account: AccountState.active, firstName: 'Demo', lastName: 'Buyer', email: 'buyer@example.test');

class FakePicker implements ListingFilePicker {
  @override
  Future<ListingFile?> pickPhoto() async => const ListingFile(name: 'front.jpg', sizeBytes: 10, asset: 'assets/properties/p4/01_Contemporary_family_villa_comple.jpg');
  @override
  Future<ListingFile?> pickDocument() async => ListingFile(name: 'deed.pdf', sizeBytes: 8, bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4]));
}

Widget app(String start, {MeSession? me, List<Override> overrides = const [], List<String>? visited, Widget? startChild}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/start', builder: (c, s) => Scaffold(body: startChild ?? const SizedBox())),
      ...productRoutes(),
    ],
    errorBuilder: (c, s) {
      visited?.add(s.uri.toString());
      return Scaffold(body: Text('ROUTE ${s.uri}'));
    },
  );
  return ProviderScope(
    overrides: [
      meProvider.overrideWith((ref) async => me ?? (throw const ApiException(ApiErrorCode.network))),
      listingFilePickerProvider.overrideWithValue(FakePicker()),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('ar')],
    ),
  );
}

Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> pumpApp(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(430, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
  await settle(t);
}

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = find.text(text);
  final target = last ? f.last : f.first;
  await t.ensureVisible(target);
  await t.pump();
  await t.tap(target, warnIfMissed: false);
  await settle(t, 3);
}

Future<void> enter(WidgetTester t, String label, String value) async {
  final f = find.widgetWithText(TextField, label);
  await t.ensureVisible(f.first);
  await t.enterText(f.first, value);
  await t.pump();
}

void main() {
  group('contextual help', () {
    testWidgets('"?" opens a short explanation; Learn more opens the guide; Back returns to the same screen', (t) async {
      await pumpApp(t, app('/start', startChild: const Center(child: AQHelpButton('viewing'))));
      await t.tap(find.byType(AQHelpButton));
      await settle(t);
      expect(find.text('What happens after I request a viewing?'), findsOneWidget);
      expect(find.textContaining('Your request goes to the host'), findsOneWidget);
      await tapText(t, 'Learn more');
      expect(find.textContaining('After the visit time has passed'), findsOneWidget);
      expect(find.text('Related topics'.toUpperCase()), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Back').first);
      await settle(t);
      expect(find.byType(AQHelpButton), findsOneWidget, reason: 'back on the original screen');
    });

    testWidgets('an unknown guide shows a recovery state', (t) async {
      await pumpApp(t, app('/help/nope'));
      expect(find.text('This guide is not available'), findsOneWidget);
      expect(find.text('Open Help & guides'), findsOneWidget);
    });
  });

  group('listing journey (approved agent)', () {
    testWidgets('validation keeps the person on the step and explains what is missing', (t) async {
      final repo = DemoListingRepository(session: () async => agent, latency: Duration.zero);
      await pumpApp(t, app('/listings/new?channel=agent', me: agent, overrides: [listingRepositoryProvider.overrideWithValue(repo)]));
      await tapText(t, 'Continue');
      expect(find.text('Choose a market.'), findsOneWidget);
      expect(find.text('Step 1 of 6 · Property'), findsOneWidget);
    });

    testWidgets('create → review → submit gives an "in review" receipt and a pending listing, never "live"', (t) async {
      final repo = DemoListingRepository(session: () async => agent, latency: Duration.zero);
      await pumpApp(t, app('/listings/new?channel=agent', me: agent, overrides: [listingRepositoryProvider.overrideWithValue(repo)]));
      await tapText(t, 'Residential');
      await tapText(t, 'For sale');
      await tapText(t, 'Villa');
      await tapText(t, 'Continue');
      expect(find.text('Step 2 of 6 · Location'), findsOneWidget);
      await tapText(t, 'Choose');
      await tapText(t, 'Muscat', last: true);
      await tapText(t, 'Choose');
      await tapText(t, 'Bawshar', last: true);
      await tapText(t, 'Continue');
      await enter(t, 'Price (OMR)', '185000');
      await enter(t, 'Listing title', 'Family villa near the beach');
      await tapText(t, 'Choose');
      await tapText(t, '4', last: true);
      await tapText(t, 'Choose');
      await tapText(t, '3', last: true);
      await enter(t, 'Land area (m²)', '600');
      await enter(t, 'Build area (m²)', '420');
      await tapText(t, 'Continue');
      expect(find.text('Step 4 of 6 · Photos'), findsOneWidget);
      await tapText(t, 'Add photos');
      expect(find.text('1 of 20 photos'), findsWidgets);
      await tapText(t, 'Continue');
      await enter(t, 'Title deed number', '445566');
      await tapText(t, 'Choose file');
      expect(find.text('deed.pdf'), findsOneWidget);
      await tapText(t, 'Continue');
      expect(find.text('Step 6 of 6 · Review'), findsOneWidget);
      expect(find.text('Deed number ending 566'), findsWidgets);
      await tapText(t, 'The details are accurate and I am the owner, or I hold the owner\'s authorisation.');
      await tapText(t, 'Submit for review');
      await settle(t);
      expect(find.text('Submitted for review'), findsOneWidget);
      expect(find.text('In review'), findsWidgets);
      final mine = await repo.mine();
      expect(mine.single.state, ListingState.pending);
      await tapText(t, 'View listing status');
      expect(find.text('Family villa near the beach'), findsWidgets);
      expect(find.textContaining('not visible to anyone else yet'), findsOneWidget);
    });

    testWidgets('My listings for a signed-out visitor asks them to sign in', (t) async {
      await pumpApp(t, app('/listings'));
      expect(find.text('Sign in to manage listings'), findsOneWidget);
    });
  });

  group('Aqary e-Broker', () {
    testWidgets('a guest sees what it is and the pending fee, then is asked to sign in', (t) async {
      await pumpApp(t, app('/sell'));
      expect(find.text('Sell your property with Aqary e-Broker'), findsOneWidget);
      expect(find.textContaining('has not been approved yet, so no amount is shown'), findsOneWidget);
      expect(find.text('Sign in to sell'), findsOneWidget);
      expect(find.textContaining('OMR'), findsNothing, reason: 'no fee amount is invented');
    });

    testWidgets('a signed-in owner without a photo ID is sent to upload it first', (t) async {
      final visited = <String>[];
      final repo = DemoListingRepository(session: () async => buyer, latency: Duration.zero);
      await pumpApp(t, app('/sell', me: buyer, visited: visited, overrides: [listingRepositoryProvider.overrideWithValue(repo)]));
      await tapText(t, 'Start selling');
      expect(find.text('Your photo ID'), findsOneWidget);
      await tapText(t, 'Upload photo ID');
      expect(await repo.sellerId(), SellerIdState.pendingReview);
      await tapText(t, 'Continue to property details');
      expect(find.text('Sell your property'), findsOneWidget);
    });
  });

  group('AqaratiBroker programme', () {
    testWidgets('intro → directory → profile with badge, approved listings and honest reviews', (t) async {
      await pumpApp(t, app('/brokers'));
      expect(find.text('Trusted brokers from AQARATI'), findsOneWidget);
      expect(find.textContaining('still awaiting approval'), findsOneWidget);
      await tapText(t, 'Find an Aqarati Broker');
      expect(find.text('3 brokers'), findsOneWidget);
      await tapText(t, 'Dhofar');
      expect(find.text('1 broker'), findsOneWidget);
      await t.tap(find.bySemanticsLabel(RegExp('Demo Broker · Dhofar')).first);
      await settle(t);
      expect(find.text('Approved listings'), findsOneWidget);
      expect(find.textContaining('No published reviews yet'), findsOneWidget);
    });
  });

  group('engagements and reviews', () {
    testWidgets('requesting an engagement shows "waiting for the company"; cancelling asks first', (t) async {
      final s = DemoBackendState();
      await pumpApp(
        t,
        app('/engagements/new?pro=demo-c1', me: buyer, overrides: [
          devBuildRepositoryProvider.overrideWithValue(DemoDevBuildRepository(() => s, lag: Duration.zero)),
          engagementRepositoryProvider.overrideWithValue(DemoEngagementRepository(latency: Duration.zero)),
        ]),
      );
      expect(find.textContaining('Confirm you worked with'), findsOneWidget);
      expect(find.textContaining('14 days to confirm'), findsOneWidget);
      await tapText(t, 'Send engagement request');
      await settle(t);
      expect(find.text('Waiting for the company'), findsWidgets);
      await tapText(t, 'Cancel request');
      expect(find.text('Cancel this engagement request?'), findsOneWidget);
      await tapText(t, 'Cancel request', last: true);
      await settle(t);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('a company review without a confirmed engagement explains the rule instead of a form', (t) async {
      await pumpApp(t, app('/reviews/write?kind=professional&id=demo-c1&name=Sahari', me: buyer, overrides: [engagementRepositoryProvider.overrideWithValue(DemoEngagementRepository(latency: Duration.zero)), reviewRepositoryProvider.overrideWithValue(DemoReviewRepository(latency: Duration.zero))]));
      expect(find.text('You cannot review them yet'), findsOneWidget);
      expect(find.text('Confirm an engagement'), findsOneWidget);
      expect(find.text('Your rating'), findsNothing);
    });

    testWidgets('a completed maintenance booking allows a review that is submitted for moderation, never published', (t) async {
      final mrepo = DemoMaintenanceRepository(latency: Duration.zero);
      final b = await mrepo.request(providerId: 'b4', providerName: 'Demo provider', service: MaintenanceService.ac, date: DateTime.now().add(const Duration(days: 1)), window: MaintenanceWindow.morning);
      mrepo.debugSet(b.id, MaintenanceStatus.completed);
      final rrepo = DemoReviewRepository(latency: Duration.zero);
      await pumpApp(t, app('/reviews/write?kind=provider&id=b4&name=Demo%20provider', me: buyer, overrides: [maintenanceRepositoryProvider.overrideWithValue(mrepo), reviewRepositoryProvider.overrideWithValue(rrepo)]));
      expect(find.text('Your rating'), findsOneWidget);
      await tapText(t, 'Preview');
      expect(find.text('Choose from 1 to 5 stars.'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('4 of 5 stars'));
      await t.pump();
      await enter(t, 'Your review', 'Arrived on the agreed day and fixed the unit.');
      await tapText(t, 'Preview');
      expect(find.text('How your review will look'), findsOneWidget);
      await tapText(t, 'Submit for moderation');
      await settle(t);
      expect(find.text('Submitted for moderation'), findsOneWidget);
      expect(find.text('Published'), findsNothing);
      expect((await rrepo.mine()).single.rating, 4);
    });

    testWidgets('reporting a review needs a written reason and a confirmation', (t) async {
      final rrepo = DemoReviewRepository(latency: Duration.zero);
      await pumpApp(t, app('/reviews/report?id=rv-1&about=Sahari', me: buyer, overrides: [reviewRepositoryProvider.overrideWithValue(rrepo)]));
      await tapText(t, 'Send report');
      expect(find.text('Write at least 10 characters.'), findsOneWidget);
      await enter(t, 'Why are you reporting it?', 'It describes a different company.');
      await tapText(t, 'Send report');
      expect(find.text('Send this report?'), findsOneWidget);
      await tapText(t, 'Send report', last: true);
      await settle(t);
      expect(find.text('Report sent'), findsOneWidget);
      expect(rrepo.debugReported('rv-1'), isTrue);
    });
  });

  group('maintenance provider', () {
    testWidgets('unknown and expired invitations explain themselves; providers cannot sign up publicly', (t) async {
      await pumpApp(t, app('/invite/abc', overrides: [demoBackendStateProvider.overrideWithValue(DemoBackendState())]));
      expect(find.text('We could not find this invitation'), findsOneWidget);
      expect(find.textContaining('cannot sign up publicly'), findsOneWidget);
    });

    testWidgets('a valid invitation leads into account creation', (t) async {
      final s = DemoBackendState();
      await pumpApp(t, app('/invite/demo-invite', overrides: [demoBackendStateProvider.overrideWithValue(s), providerRepositoryProvider.overrideWithValue(DemoProviderRepository(() => s, latency: Duration.zero))]));
      expect(find.text('You are invited to join AQARATI'), findsOneWidget);
      await tapText(t, 'Accept invitation');
      expect(find.text('Step 1 of 4 · Account'), findsOneWidget);
      await tapText(t, 'Continue');
      expect(find.textContaining('at least 8 characters'), findsWidgets);
    });

    testWidgets('the provider workspace stays closed until the grant is approved', (t) async {
      await pumpApp(t, app('/provider', me: const MeSession(account: AccountState.active, providerGrant: GrantState.pendingVerification)));
      expect(find.text('Your provider workspace opens after approval'), findsOneWidget);
    });
  });

  group('account and system', () {
    testWidgets('the Account tab groups profile, activity, preferences and help; rows navigate', (t) async {
      SharedPreferences.setMockInitialValues({});
      final visited = <String>[];
      await pumpApp(t, app('/start', me: agent, visited: visited, startChild: const AccountTab()));
      for (final s in ['Personal profile', 'Organisation', 'My listings', 'Sell with Aqary e-Broker', 'My engagements', 'My reviews', 'Settings', 'Help & guides', 'Privacy & legal']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await tapText(t, 'Settings');
      expect(find.text('Same as device'), findsOneWidget);
    });

    testWidgets('signing out asks for confirmation first', (t) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(t, app('/start', me: agent, startChild: const AccountTab()));
      await tapText(t, 'Sign out');
      expect(find.text('Sign out?'), findsOneWidget);
      await tapText(t, 'Cancel', last: true);
      expect(find.text('Sign out?'), findsNothing);
    });

    testWidgets('a minimum version above this build blocks the app with an update screen', (t) async {
      await pumpApp(
        t,
        ProviderScope(
          overrides: [appConfigProvider.overrideWith((ref) async => const AppConfig(minSupportedVersion: '9.9.9'))],
          child: const MaterialApp(localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate], home: AQVersionGate(child: Text('APP'))),
        ),
      );
      expect(find.text('Please update AQARATI'), findsOneWidget);
      expect(find.text('APP'), findsNothing);
    });

    testWidgets('a failed config call never blocks the app', (t) async {
      await pumpApp(
        t,
        ProviderScope(
          overrides: [appConfigProvider.overrideWith((ref) async => throw StateError('offline'))],
          child: const MaterialApp(home: AQVersionGate(child: Text('APP'))),
        ),
      );
      expect(find.text('APP'), findsOneWidget);
    });
  });
}
