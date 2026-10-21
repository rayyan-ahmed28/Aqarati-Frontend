import 'package:aqarati_admin_web/data/admin_api.dart';
import 'package:aqarati_admin_web/main.dart';
import 'package:aqarati_admin_web/state/admin_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> signIn(WidgetTester t, String email) async {
  await t.enterText(find.widgetWithText(TextField, 'Admin email'), email);
  await t.enterText(find.widgetWithText(TextField, 'Password'), DemoAdminApi.demoPassword);
  await t.tap(find.text('Continue'));
  await settle(t);
  expect(find.text('Two-step verification'), findsOneWidget);
  await t.enterText(find.byType(TextField).first, DemoAdminApi.demoTotp);
  await t.tap(find.text('Verify and sign in'));
  await settle(t);
}

void size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget app() => ProviderScope(overrides: [adminApiProvider.overrideWithValue(DemoAdminApi(latency: Duration.zero))], child: const AdminApp());

void main() {
  testWidgets('signed-out visitors are sent to the staff login', (t) async {
    size(t, 1400, 900);
    await t.pumpWidget(app());
    await settle(t);
    expect(find.text('Staff sign in'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('login + TOTP opens the dashboard; a reviewer sees only reviewer sections', (t) async {
    size(t, 1400, 900);
    await t.pumpWidget(app());
    await settle(t);
    await signIn(t, 'reviewer@aqarati.test');
    expect(find.textContaining('Good to see you'), findsOneWidget);
    expect(find.text('Verification queue'), findsWidgets);
    expect(find.text('Audit log'), findsNothing, reason: 'reviewers cannot read the audit log');
    expect(find.text('Admin users'), findsNothing);
    expect(find.text('Provider invitations'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('a Super Admin sees every section and can open the queue and an item', (t) async {
    size(t, 1400, 1000);
    await t.pumpWidget(app());
    await settle(t);
    await signIn(t, 'super@aqarati.test');
    for (final s in ['Audit log', 'Admin users', 'Provider invitations', 'Ad banners', 'Roles & permissions']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.tap(find.text('Verification queue').first);
    await settle(t);
    expect(find.textContaining('Resubmissions first'), findsOneWidget);
    await t.tap(find.textContaining('Construction applicant C').first);
    await settle(t);
    expect(find.text('Checklist and decision'), findsOneWidget);
    expect(find.text('Claim item'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('every console page renders at a narrow width without overflow', (t) async {
    size(t, 760, 1000);
    await t.pumpWidget(app());
    await settle(t);
    await signIn(t, 'super@aqarati.test');
    for (final path in ['/dashboard', '/queue', '/queue/Q-1002', '/moderation', '/accounts', '/invitations', '/ads', '/audit', '/admins', '/roles', '/nowhere']) {
      final ctx = t.element(find.byType(Scaffold).first);
      GoRouterHelper(ctx).go(path);
      await settle(t);
      expect(t.takeException(), isNull, reason: path);
    }
  });
}
