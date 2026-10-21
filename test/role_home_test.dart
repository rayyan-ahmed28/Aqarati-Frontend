import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart';
import 'package:aqarati_app/features/devbuild/db_repository.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:aqarati_app/features/role_home/role_home_screen.dart';
import 'package:aqarati_app/features/role_home/role_home_strings.dart';
import 'package:aqarati_app/features/workspace/aq_home.dart' show AQHomeScreen;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aqarati_app/core/localization/flow_strings.dart';

MeSession me(SignupPurpose? p, GrantState? g, {ReviewStage? stage, AccountState account = AccountState.active}) => MeSession(account: account, purpose: p, grant: g, stage: stage);

DemoBackendState state(SignupPurpose p, {InteriorExteriorServiceType? service, String name = 'Test Business'}) => DemoBackendState()
  ..purpose = p
  ..grant = GrantState.approved
  ..account = AccountState.active
  ..businessName = name
  ..serviceType = service;

Widget app(MeSession? session, {DemoDevBuildRepository? repo, DemoBackendState? s, bool dark = false, bool rtl = false, bool reduceMotion = false, double scale = 1, List<String>? visited}) {
  final router = GoRouter(
    initialLocation: '/app/home',
    routes: [GoRoute(path: '/app/home', builder: (c, st) => const Scaffold(body: RoleHomeScreen()))],
    errorBuilder: (c, st) {
      visited?.add(st.uri.toString());
      return Scaffold(body: Text('ROUTE ${st.uri}'));
    },
  );
  final st = s ?? (session?.purpose == null ? null : state(session!.purpose!));
  return ProviderScope(
    overrides: [
      devBuildRepositoryProvider.overrideWithValue(repo ?? DemoDevBuildRepository(() => st, lag: Duration.zero)),
      meProvider.overrideWith((ref) async {
        if (session == null) throw const ApiException(ApiErrorCode.network);
        return session;
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      locale: Locale(rtl ? 'ar' : 'en'),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('ar')],
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduceMotion), child: child!),
    ),
  );
}

Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> pumpHome(WidgetTester t, Widget w, {double width = 393, double height = 1600}) async {
  await t.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(w);
  await settle(t);
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await settle(t, 3);
}

const _companies = <SignupPurpose, HomeRole>{
  SignupPurpose.propertyDevelopmentCompany: HomeRole.developer,
  SignupPurpose.constructionCompany: HomeRole.construction,
  SignupPurpose.buildingArchitecture: HomeRole.architecture,
  SignupPurpose.interiorExteriorDesign: HomeRole.interiorExterior,
};

void main() {
  group('role resolution (pure)', () {
    test('guests, loading and unverified accounts get the buyer home', () {
      expect(resolveHome(null).role, HomeRole.buyer);
      expect(resolveHome(me(SignupPurpose.constructionCompany, GrantState.approved, account: AccountState.otpPending)).role, HomeRole.buyer);
      expect(resolveHome(me(null, null)).role, HomeRole.buyer);
    });

    test('a buyer stays a buyer and has no switcher or banner', () {
      final r = resolveHome(me(SignupPurpose.userToShop, null));
      expect(r.role, HomeRole.buyer);
      expect(r.canSwitch, isFalse);
      expect(r.hasPendingApplication, isFalse);
    });

    test('each approved company type resolves to its own home', () {
      for (final e in _companies.entries) {
        final r = resolveHome(me(e.key, GrantState.approved));
        expect(r.role, e.value, reason: e.key.name);
        expect(r.canSwitch, isFalse, reason: 'only agents switch');
      }
    });

    test('every company home is distinct', () {
      final roles = {for (final p in _companies.keys) resolveHome(me(p, GrantState.approved)).role};
      expect(roles.length, 4);
    });

    test('an approved agent opens in the agent workspace and can switch to buyer and back', () {
      final approved = me(SignupPurpose.realEstateAgent, GrantState.approved);
      expect(resolveHome(approved).role, HomeRole.agent);
      expect(resolveHome(approved).canSwitch, isTrue);
      expect(resolveHome(approved, chosen: HomeWorkspace.buyer).role, HomeRole.buyer);
      expect(resolveHome(approved, chosen: HomeWorkspace.buyer).canSwitch, isTrue);
      expect(resolveHome(approved, chosen: HomeWorkspace.agent).role, HomeRole.agent);
    });

    test('no unapproved grant reaches a role home, and the real status is carried', () {
      final states = <(GrantState, ReviewStage?)>[
        (GrantState.draft, null),
        (GrantState.pendingVerification, ReviewStage.underReview),
        (GrantState.pendingVerification, ReviewStage.awaitingSecondApproval),
        (GrantState.resubmissionRequired, null),
        (GrantState.rejected, null),
        (GrantState.suspended, null),
      ];
      for (final p in [...SignupPurpose.values.where((p) => roleConfigs[p]!.needsDocuments)]) {
        for (final s in states) {
          final r = resolveHome(me(p, s.$1, stage: s.$2), chosen: HomeWorkspace.agent);
          expect(r.role, HomeRole.buyer, reason: '${p.name} ${s.$1.name}');
          expect(r.canSwitch, isFalse, reason: 'switcher needs an approved agent grant');
          expect(r.pendingGrant, s.$1);
          expect(r.pendingStage, s.$2);
        }
      }
    });

    test('a null grant for a business purpose is just a buyer with no banner', () {
      final r = resolveHome(me(SignupPurpose.constructionCompany, null));
      expect(r.role, HomeRole.buyer);
      expect(r.hasPendingApplication, isFalse);
    });
  });

  group('copy', () {
    test('every role-home string has English and Arabic', () {
      for (final e in roleHomeStrings.entries) {
        expect(e.value.$1.trim(), isNotEmpty, reason: e.key);
        expect(e.value.$2.trim(), isNotEmpty, reason: e.key);
      }
    });

    test('no mock figures: copy contains no digits other than the numbered index', () {
      for (final e in roleHomeStrings.entries) {
        expect(RegExp(r'\d').hasMatch(e.value.$1), isFalse, reason: e.key);
      }
    });
  });

  group('six distinct homes', () {
    testWidgets('construction: company profile home, no project tools, no invented tenders', (t) async {
      await pumpHome(t, app(me(SignupPurpose.constructionCompany, GrantState.approved)));
      expect(find.text('Build trust before the first call.'), findsOneWidget);
      expect(find.text('The essentials'), findsOneWidget);
      expect(find.text('Add project'), findsNothing);
      expect(find.text('Project pipeline'), findsNothing);
      expect(find.textContaining('tender', findRichText: true), findsNothing);
      expect(find.textContaining('bid', findRichText: true), findsNothing);
      expect(find.text('Test Business'), findsWidgets);
    });

    testWidgets('construction: every essentials cell and row opens a real destination', (t) async {
      final cases = <String, String>{
        'IDENTITY': '/app/account/workspace/profile',
        'PRESENCE': '/app/account/workspace/profile',
        'DIRECTORY': '/app/explore/build/results?cat=construction',
        'REPUTATION': '/app/account/workspace/reviews',
        'Commercial registration': '/verification/details',
      };
      for (final e in cases.entries) {
        final visited = <String>[];
        await pumpHome(t, app(me(SignupPurpose.constructionCompany, GrantState.approved), visited: visited));
        await tapText(t, e.key.contains(' ') ? e.key : e.key);
        expect(visited, contains(e.value), reason: e.key);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('architecture: studio profile home, no project manager', (t) async {
      await pumpHome(t, app(me(SignupPurpose.buildingArchitecture, GrantState.approved)));
      expect(find.text('Architecture with intention.'), findsOneWidget);
      expect(find.text('Practice profile'), findsOneWidget);
      expect(find.textContaining('Portfolio publishing is proposed'), findsOneWidget);
      expect(find.text('Add project'), findsNothing);
      expect(find.text('Project pipeline'), findsNothing);
    });

    testWidgets('interior & exterior: shows the real service type from the model', (t) async {
      for (final svc in InteriorExteriorServiceType.values) {
        final s = state(SignupPurpose.interiorExteriorDesign, service: svc);
        await pumpHome(t, app(me(SignupPurpose.interiorExteriorDesign, GrantState.approved), s: s));
        expect(find.text('Spaces with a point of view.'), findsOneWidget);
        final label = {InteriorExteriorServiceType.interior: 'Interior', InteriorExteriorServiceType.exterior: 'Exterior', InteriorExteriorServiceType.both: 'Both'}[svc]!;
        final selected = find.bySemanticsLabel(label);
        expect(selected, findsWidgets);
        // The service-type row in the essentials shows the same model value.
        expect(find.text(label), findsWidgets);
        expect(find.text('Add project'), findsNothing);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('interior & exterior: choosing another service type opens the profile editor, nothing is switched locally', (t) async {
      final visited = <String>[];
      final s = state(SignupPurpose.interiorExteriorDesign, service: InteriorExteriorServiceType.interior);
      await pumpHome(t, app(me(SignupPurpose.interiorExteriorDesign, GrantState.approved), s: s, visited: visited));
      await t.tap(find.text('Exterior').first, warnIfMissed: false);
      await settle(t, 3);
      expect(visited, contains('/app/account/workspace/profile'));
    });

    testWidgets('developer: empty state offers Add project and never shows counts', (t) async {
      final visited = <String>[];
      await pumpHome(t, app(me(SignupPurpose.propertyDevelopmentCompany, GrantState.approved), visited: visited));
      expect(find.text('Shape places for the long term.'), findsOneWidget);
      expect(find.textContaining('No projects yet'), findsOneWidget);
      expect(find.textContaining('All projects ·'), findsNothing);
      await tapText(t, 'Add project');
      expect(visited, contains('/workspace/projects/new'));
    });

    testWidgets('developer: pipeline shows only the owner\'s records and filters by real status', (t) async {
      final s = state(SignupPurpose.propertyDevelopmentCompany);
      final repo = DemoDevBuildRepository(() => s, lag: Duration.zero);
      await repo.saveProject(ProjectDraft(name: 'Marina Heights'), submit: false, idempotencyKey: 'k1');
      await pumpHome(t, app(me(SignupPurpose.propertyDevelopmentCompany, GrantState.approved), repo: repo, s: s));
      expect(find.textContaining('Marina Heights'), findsOneWidget);
      expect(find.text('All projects · 1'), findsOneWidget);
      expect(find.text('Draft · 1'), findsOneWidget);
      expect(find.text('Under review · 0'), findsOneWidget);
      await tapText(t, 'Under review · 0');
      expect(find.textContaining('Marina Heights'), findsNothing);
      expect(find.text('No projects in this state.'), findsOneWidget);
      await tapText(t, 'Draft · 1');
      expect(find.textContaining('Marina Heights'), findsOneWidget);
    });

    testWidgets('the five professional homes use different headlines and hierarchies', (t) async {
      final titles = <String>{};
      for (final e in {
        SignupPurpose.constructionCompany: 'Build trust before the first call.',
        SignupPurpose.propertyDevelopmentCompany: 'Shape places for the long term.',
        SignupPurpose.buildingArchitecture: 'Architecture with intention.',
        SignupPurpose.interiorExteriorDesign: 'Spaces with a point of view.',
        SignupPurpose.realEstateAgent: 'Work, in focus.',
      }.entries) {
        await pumpHome(t, app(me(e.key, GrantState.approved)));
        expect(find.text(e.value), findsOneWidget, reason: e.key.name);
        titles.add(e.value);
        await t.pumpWidget(const SizedBox());
      }
      expect(titles.length, 5);
    });
  });

  group('agent workspace', () {
    testWidgets('approved agent sees the agent workspace with a working Buyer / Agent switch', (t) async {
      await pumpHome(t, app(me(SignupPurpose.realEstateAgent, GrantState.approved)));
      expect(find.text('Work, in focus.'), findsOneWidget);
      expect(find.text('Agent workspace'), findsWidgets);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.byType(AQHomeScreen), findsNothing);

      await tapText(t, 'Buyer');
      expect(find.byType(AQHomeScreen), findsOneWidget, reason: 'switching to Buyer opens the customer home');
      expect(find.text('Work, in focus.'), findsNothing);
      expect(find.text('Agent workspace'), findsOneWidget, reason: 'the switcher stays so the agent can return');

      await tapText(t, 'Agent workspace');
      expect(find.text('Work, in focus.'), findsOneWidget);
      expect(find.byType(AQHomeScreen), findsNothing);
    });

    testWidgets('agent tools: My listings opens the listing workspace, contact explains what is missing, viewings opens Activity', (t) async {
      final visited = <String>[];
      await pumpHome(t, app(me(SignupPurpose.realEstateAgent, GrantState.approved), visited: visited));
      expect(find.textContaining('no in-app chat'), findsWidgets);
      await tapText(t, 'My listings');
      expect(visited, contains('/listings'), reason: 'the listing workspace is connected (demo repository)');
      await t.pumpWidget(const SizedBox());
      await pumpHome(t, app(me(SignupPurpose.realEstateAgent, GrantState.approved), visited: visited));
      await tapText(t, 'Viewings');
      expect(visited, contains('/app/activity'));
    });

    testWidgets('an agent who is not approved never sees agent tools or the switcher', (t) async {
      for (final g in [GrantState.draft, GrantState.pendingVerification, GrantState.resubmissionRequired, GrantState.rejected, GrantState.suspended]) {
        await pumpHome(t, app(me(SignupPurpose.realEstateAgent, g)));
        expect(find.byType(AQHomeScreen), findsOneWidget, reason: g.name);
        expect(find.text('Work, in focus.'), findsNothing);
        expect(find.text('Agent workspace'), findsNothing);
        expect(find.text('My listings'), findsNothing);
        expect(find.text('Your application is not approved yet'), findsOneWidget, reason: g.name);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('guards and status', () {
    testWidgets('guests and plain buyers get the buyer home without business tools', (t) async {
      await pumpHome(t, app(null));
      expect(find.byType(AQHomeScreen), findsOneWidget);
      expect(find.text('Your application is not approved yet'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await pumpHome(t, app(me(SignupPurpose.userToShop, null)));
      expect(find.byType(AQHomeScreen), findsOneWidget);
      expect(find.text('Agent workspace'), findsNothing);
      expect(find.text('Add project'), findsNothing);
    });

    for (final p in _companies.keys) {
      for (final g in [GrantState.pendingVerification, GrantState.resubmissionRequired, GrantState.rejected, GrantState.suspended]) {
        testWidgets('${p.name} with a ${g.name} grant gets the buyer home and a status banner, never the role home', (t) async {
          final visited = <String>[];
          await pumpHome(t, app(me(p, g), s: state(p)..grant = g, visited: visited));
          expect(find.byType(AQHomeScreen), findsOneWidget);
          expect(find.text('Your application is not approved yet'), findsOneWidget);
          for (final x in ['Add project', 'Project pipeline', 'The essentials', 'Practice profile', 'Your design language']) {
            expect(find.text(x), findsNothing, reason: x);
          }
          await tapText(t, 'View application status');
          expect(visited, contains('/verification'));
        });
      }
    }

    testWidgets('awaiting second approval is shown as its own state, not generic pending', (t) async {
      await pumpHome(t, app(me(SignupPurpose.propertyDevelopmentCompany, GrantState.pendingVerification, stage: ReviewStage.awaitingSecondApproval), s: state(SignupPurpose.propertyDevelopmentCompany)..grant = GrantState.pendingVerification));
      expect(find.byType(AQHomeScreen), findsOneWidget);
      expect(find.textContaining('second', findRichText: true), findsWidgets);
    });
  });

  group('rendering', () {
    final roles = <(String, SignupPurpose)>[
      ('agent', SignupPurpose.realEstateAgent),
      ('construction', SignupPurpose.constructionCompany),
      ('developer', SignupPurpose.propertyDevelopmentCompany),
      ('architecture', SignupPurpose.buildingArchitecture),
      ('interior', SignupPurpose.interiorExteriorDesign),
    ];
    for (final r in roles) {
      for (final w in [320.0, 360.0, 412.0, 430.0]) {
        for (final dark in [false, true]) {
          testWidgets('${r.$1} home at ${w.toInt()}px ${dark ? 'dark' : 'light'} has no overflow', (t) async {
            await pumpHome(t, app(me(r.$2, GrantState.approved), dark: dark), width: w, height: 900);
            expect(t.takeException(), isNull);
          });
        }
      }
      testWidgets('${r.$1} home renders in Arabic RTL and at 200% text without overflow', (t) async {
        await pumpHome(t, app(me(r.$2, GrantState.approved), rtl: true), width: 360, height: 900);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await pumpHome(t, app(me(r.$2, GrantState.approved), scale: 2.0), width: 360, height: 900);
        expect(t.takeException(), isNull);
      });
      testWidgets('${r.$1} home content is visible immediately with reduced motion', (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1600));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(app(me(r.$2, GrantState.approved), reduceMotion: true));
        await t.pump();
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull);
        await settle(t);
      });
    }

    for (final w in [320.0, 360.0, 393.0]) {
      for (final rtl in [false, true]) {
        testWidgets('buyer home at ${w.toInt()}px ${rtl ? 'Arabic RTL' : 'English'} has no overflow', (t) async {
          await pumpHome(t, app(me(SignupPurpose.userToShop, null), rtl: rtl), width: w, height: 900);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('buyer home at 200% text in Arabic has no overflow', (t) async {
      await pumpHome(t, app(me(SignupPurpose.userToShop, null), rtl: true, scale: 2.0), width: 360, height: 900);
      expect(t.takeException(), isNull);
    });

    testWidgets('home switches smoothly without blocking taps (animations never gate the action)', (t) async {
      await pumpHome(t, app(me(SignupPurpose.realEstateAgent, GrantState.approved)));
      await t.tap(find.text('Buyer').first);
      await t.pump(const Duration(milliseconds: 50));
      expect(t.takeException(), isNull);
      await settle(t);
      expect(find.byType(AQHomeScreen), findsOneWidget);
    });
  });

  test('string lookup works through FlowStrings', () {
    const f = FlowStrings.forTest(false);
    expect(f.t('rh.agent.title'), 'Work, in focus.');
    expect(const FlowStrings.forTest(true).t('rh.agent.title'), isNotEmpty);
  });
}
